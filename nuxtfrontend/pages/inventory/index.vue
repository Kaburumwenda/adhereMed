<template>
  <v-container fluid class="pa-3 pa-md-5 inv-page">

    <!-- ═══════════════ HERO ═══════════════ -->
    <!-- Tinted with the tenant palette from /ims/organization/branding —
         see `heroTheme` for the CSS-variable bridge. -->
    <div class="inv-hero mb-4" :style="heroTheme">
      <span class="inv-hero-glow" />
      <span class="inv-hero-glow inv-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="inv-hero-icon">
            <v-icon size="30">mdi-package-variant</v-icon>
          </div>
          <div>
            <div class="inv-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              INVENTORY CONTROL
            </div>
            <h1 class="inv-title">{{ $t('inventory.title') }}</h1>
            <div class="inv-sub">
              Stock items, categories, units &amp; adjustments
              <span v-if="activeBranchName"> · {{ activeBranchName }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="inv-hero-iconbtn"
            title="Refresh"
            :loading="currentResource.loading.value"
            @click="reload"
          />
          <!-- Collapses the KPI cards + stock-insight panels so the stock table
               gets the viewport. Preference is remembered across reloads. -->
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none inv-hero-btn-glass"
            :prepend-icon="showOverview ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
            :aria-pressed="showOverview ? 'true' : 'false'"
            :title="showOverview ? 'Hide the summary panels above the list' : 'Show the summary panels again'"
            @click="toggleOverview"
          >{{ showOverview ? 'Hide overview' : 'Show overview' }}</v-btn>
          <v-btn
            v-if="canEdit && tab === 'stocks'"
            variant="flat"
            elevation="0"
            prepend-icon="mdi-microsoft-excel"
            rounded="lg"
            class="text-none inv-hero-btn-strong"
            to="/inventory/excel"
          >Import / Export</v-btn>
          <v-menu v-if="tab === 'stocks' && (canEdit || canDelete)" location="bottom end">
            <template #activator="{ props: mp }">
              <v-btn
                v-bind="mp"
                variant="flat"
                elevation="0"
                rounded="lg"
                class="text-none inv-hero-btn-glass"
                prepend-icon="mdi-tune-variant"
                append-icon="mdi-chevron-down"
              >Bulk tools</v-btn>
            </template>
            <v-list density="compact" min-width="240">
              <v-list-item
                v-if="canEdit"
                prepend-icon="mdi-table-edit"
                title="Edit mode"
                subtitle="Update many items at once"
                to="/inventory/bulk?mode=edit"
              />
              <v-list-item
                v-if="canDelete"
                prepend-icon="mdi-trash-can"
                title="Delete mode"
                subtitle="Remove many items at once"
                to="/inventory/bulk?mode=delete"
              />
            </v-list>
          </v-menu>
          <v-btn
            v-if="canEdit"
            variant="flat"
            elevation="0"
            prepend-icon="mdi-plus"
            rounded="lg"
            class="text-none inv-hero-btn-outline"
            :to="createPaths[tab]"
          >{{ createLabels[tab] }}</v-btn>
        </div>
      </div>
    </div>

    <!-- ═══════════════ OVERVIEW (KPI STRIP + STOCK INSIGHTS) ═══════════════
         One wrapper so the 6 stat cards and the three insight panels show /
         hide together via the hero's "Hide overview" toggle. v-show (not
         v-if) keeps the DonutRing and its layout intact across toggles. -->
    <div v-show="showOverview" class="inv-overview">
      <!-- KPI STRIP -->
      <v-row dense class="mb-1">
        <v-col v-for="k in kpiCards" :key="k.title" cols="12" sm="6" md="4" lg="2">
          <div class="inv-kpi h-100" :class="`inv-kpi-${k.tone}`">
            <div class="d-flex align-start justify-space-between mb-2">
              <div class="inv-kpi-icon">
                <v-icon size="18">{{ k.icon }}</v-icon>
              </div>
              <v-chip
                v-if="k.badge"
                size="x-small"
                :color="k.tone"
                variant="tonal"
                class="font-weight-bold"
              >{{ k.badge }}</v-chip>
            </div>
            <div class="inv-kpi-label">{{ k.title }}</div>
            <div class="inv-kpi-value">{{ k.value }}</div>
            <div class="inv-kpi-foot">{{ k.hint }}</div>
            <div v-if="k.bars && k.bars.length" class="inv-kpi-bars mt-3">
              <span
                v-for="(b, bi) in k.bars"
                :key="bi"
                :style="{ width: b.pct + '%', background: b.color }"
              />
            </div>
          </div>
        </v-col>
      </v-row>

      <!-- STOCK INSIGHTS (stocks tab only) -->
      <v-row v-if="tab === 'stocks' && kpis.skus" dense class="mt-2">
        <!-- Health -->
        <v-col cols="12" lg="4">
          <v-card rounded="lg" border class="pa-4 h-100 inv-panel">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <div class="inv-panel-icon inv-panel-icon-green">
                  <v-icon size="18">mdi-shield-check-outline</v-icon>
                </div>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Stock health</div>
                  <div class="text-caption text-medium-emphasis">Availability by item</div>
                </div>
              </div>
              <v-chip size="small" :color="healthChipColor" variant="tonal" class="font-weight-bold">
                {{ healthPct }}% healthy
              </v-chip>
            </div>

            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="healthSegments" :size="176" :thickness="16">
                <div class="text-center">
                  <div class="text-h5 font-weight-bold">{{ kpis.skus }}</div>
                  <div class="text-caption text-medium-emphasis">SKUs</div>
                </div>
              </DonutRing>
            </div>

            <div v-for="h in healthLegend" :key="h.label" class="inv-legend">
              <span class="inv-legend-dot" :style="{ background: h.color }" />
              <span class="text-body-2 flex-grow-1">{{ h.label }}</span>
              <span class="text-body-2 font-weight-bold">{{ h.count }}</span>
              <span class="text-caption text-medium-emphasis inv-legend-pct">{{ h.pct }}%</span>
            </div>

            <v-btn
              v-if="kpis.alert"
              block
              variant="tonal"
              color="warning"
              rounded="lg"
              class="text-none mt-3"
              prepend-icon="mdi-filter-variant"
              @click="setStatusFilter('low')"
            >Review {{ kpis.alert }} item{{ kpis.alert === 1 ? '' : 's' }} needing attention</v-btn>
          </v-card>
        </v-col>

        <!-- Valuation -->
        <v-col cols="12" lg="4">
          <v-card rounded="lg" border class="pa-4 h-100 inv-panel">
            <div class="d-flex align-center mb-3">
              <div class="inv-panel-icon inv-panel-icon-teal">
                <v-icon size="18">mdi-cash-multiple</v-icon>
              </div>
              <div>
                <div class="text-subtitle-2 font-weight-bold">Inventory valuation</div>
                <div class="text-caption text-medium-emphasis">On-hand value at cost &amp; retail</div>
              </div>
            </div>

            <div class="inv-valuation-hero mb-3">
              <div class="text-caption text-medium-emphasis">Retail value</div>
              <div class="inv-valuation-amount">{{ formatMoney(kpis.retail) }}</div>
              <div class="text-caption text-medium-emphasis">across {{ kpis.units.toLocaleString() }} units on hand</div>
            </div>

            <div class="inv-metric-row">
              <span class="text-body-2 text-medium-emphasis">Value at cost</span>
              <span class="text-body-2 font-weight-medium">{{ formatMoney(kpis.cost) }}</span>
            </div>
            <div class="inv-metric-row">
              <span class="text-body-2 text-medium-emphasis">Potential margin</span>
              <span class="text-body-2 font-weight-medium text-success">{{ formatMoney(kpis.margin) }}</span>
            </div>
            <div class="inv-metric-row">
              <span class="text-body-2 text-medium-emphasis">Average unit value</span>
              <span class="text-body-2 font-weight-medium">{{ formatMoney(kpis.units ? kpis.retail / kpis.units : 0) }}</span>
            </div>

            <v-divider class="my-3" />

            <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
              <span>Margin potential</span>
              <span class="font-weight-bold">{{ marginPct.toFixed(1) }}%</span>
            </div>
            <v-progress-linear
              :model-value="Math.min(100, marginPct)"
              :color="marginPct >= 25 ? 'success' : marginPct >= 15 ? 'warning' : 'error'"
              height="8"
              rounded
            />
            <div class="text-caption text-medium-emphasis mt-2">
              Cost base {{ formatMoney(kpis.cost) }} · mark-up {{ formatMoney(kpis.margin) }}
            </div>
          </v-card>
        </v-col>

        <!-- Category mix -->
        <v-col cols="12" lg="4">
          <v-card rounded="lg" border class="pa-4 h-100 inv-panel">
            <div class="d-flex align-center justify-space-between mb-3">
              <div class="d-flex align-center">
                <div class="inv-panel-icon inv-panel-icon-indigo">
                  <v-icon size="18">mdi-shape-outline</v-icon>
                </div>
                <div>
                  <div class="text-subtitle-2 font-weight-bold">Category mix</div>
                  <div class="text-caption text-medium-emphasis">Retail value concentration</div>
                </div>
              </div>
              <v-btn
                variant="text"
                size="small"
                class="text-none"
                color="primary"
                append-icon="mdi-arrow-right"
                @click="tab = 'categories'"
              >All</v-btn>
            </div>

            <EmptyState
              v-if="!topCategories.length"
              icon="mdi-shape-outline"
              title="No categories yet"
              message="Assign categories to your stock items to see the mix."
            />
            <template v-else>
              <div v-for="c in topCategories" :key="c.id" class="mb-3">
                <div class="d-flex align-center justify-space-between mb-1">
                  <div class="d-flex align-center" style="gap:8px">
                    <span class="inv-legend-dot" :style="{ background: c.color }" />
                    <span class="text-body-2 text-truncate" style="max-width: 150px">{{ c.name }}</span>
                  </div>
                  <div class="text-right">
                    <div class="text-body-2 font-weight-medium">{{ formatMoney(c.retail) }}</div>
                    <div class="text-caption text-medium-emphasis">{{ c.count }} SKU{{ c.count === 1 ? '' : 's' }}</div>
                  </div>
                </div>
                <v-progress-linear :model-value="c.pct" :color="c.color" height="6" rounded />
              </div>
            </template>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- ═══════════════ TABS ═══════════════ -->
    <div class="inv-tabs mt-4 mb-3">
      <v-tabs v-model="tab" color="primary" density="compact" align-tabs="start" hide-slider>
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value" class="text-none">
          <v-icon start size="17">{{ t.icon }}</v-icon>
          {{ t.label }}
          <v-chip v-if="t.count != null" size="x-small" class="ml-2" variant="tonal">{{ t.count }}</v-chip>
        </v-tab>
      </v-tabs>
    </div>

    <!-- ═══════════════ TOOLBAR ═══════════════ -->
    <v-card rounded="lg" border class="mb-3 inv-toolbar">
      <!-- Row 1: search + quick status + view -->
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          :placeholder="searchPlaceholder"
          prepend-inner-icon="mdi-magnify"
          density="comfortable"
          variant="solo-filled"
          flat
          rounded="lg"
          bg-color="surface"
          hide-details
          clearable
          class="inv-search"
        />

        <v-chip-group
          v-if="tab === 'stocks'"
          :model-value="statusFilter"
          selected-class="text-primary"
          mandatory
          class="inv-status-chips"
          @update:model-value="setStatusFilter"
        >
          <v-chip
            v-for="s in statusOptions"
            :key="s.value"
            :value="s.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
          >
            <v-icon v-if="s.icon" start size="15">{{ s.icon }}</v-icon>
            {{ s.label }}
            <span v-if="s.count != null" class="ml-1 font-weight-bold">{{ s.count }}</span>
          </v-chip>
        </v-chip-group>

        <v-spacer class="d-none d-md-flex" />

        <v-btn
          variant="text"
          size="small"
          class="text-none"
          color="primary"
          prepend-icon="mdi-download-outline"
          :disabled="!filteredItems.length"
          @click="exportCsv"
        >Export</v-btn>

        <v-btn-toggle
          v-if="tab === 'stocks'"
          v-model="viewMode"
          mandatory
          density="comfortable"
          rounded="lg"
          variant="outlined"
          color="primary"
        >
          <v-btn value="table" icon="mdi-table" size="small" title="Table view" />
          <v-btn value="grid" icon="mdi-view-grid-outline" size="small" title="Card view" />
        </v-btn-toggle>
      </div>

      <v-divider />

      <!-- Row 2: facet filters -->
      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <template v-if="tab === 'stocks'">
          <v-select
            v-model="categoryFilter"
            :items="categoryOptions"
            item-title="label"
            item-value="value"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            prepend-inner-icon="mdi-shape"
            class="inv-select"
          />
          <v-select
            v-model="classificationFilter"
            :items="classificationOptions"
            item-title="label"
            item-value="value"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            prepend-inner-icon="mdi-label-multiple-outline"
            class="inv-select inv-select-wide"
          >
            <template #item="{ props: ip, item }">
              <v-list-item v-bind="ip" :title="item.raw?.label" :subtitle="item.raw?.description">
                <template #prepend>
                  <v-icon size="18" color="primary">mdi-label-multiple-outline</v-icon>
                </template>
              </v-list-item>
            </template>
          </v-select>
          <v-select
            v-if="branchOptions.length > 1"
            v-model="branchFilter"
            :items="branchOptions"
            item-title="label"
            item-value="value"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            prepend-inner-icon="mdi-store-outline"
            class="inv-select"
            :disabled="branchStore.branchLocked"
          />
        </template>

        <v-btn
          variant="text"
          size="small"
          class="text-none"
          color="primary"
          :prepend-icon="showAdvanced ? 'mdi-chevron-up' : 'mdi-tune-variant'"
          @click="showAdvanced = !showAdvanced"
        >
          More filters
          <v-chip v-if="advancedFilterCount" size="x-small" color="primary" variant="tonal" class="ml-2">
            {{ advancedFilterCount }}
          </v-chip>
        </v-btn>

        <v-spacer />

        <span class="text-caption text-medium-emphasis">
          <strong>{{ filteredItems.length.toLocaleString() }}</strong>
          of {{ currentItems.length.toLocaleString() }} record{{ currentItems.length === 1 ? '' : 's' }}
        </span>
      </div>

      <!-- Row 3: advanced (collapsible) -->
      <v-expand-transition>
        <div v-show="showAdvanced">
          <v-divider />
          <div class="pa-3 inv-advanced">
            <div v-if="tab === 'stocks'" class="d-flex flex-wrap align-center ga-3 mb-3">
              <v-text-field
                v-model="batchFilter"
                placeholder="Filter by batch number…"
                prepend-inner-icon="mdi-package-variant-closed"
                density="compact"
                variant="outlined"
                rounded="lg"
                hide-details
                clearable
                class="inv-select inv-select-wide"
              />
            </div>
            <div class="d-flex flex-wrap align-center ga-2">
              <v-icon size="18" class="text-medium-emphasis">mdi-calendar-filter</v-icon>
              <span class="text-caption text-medium-emphasis mr-1">Added</span>
              <v-chip
                v-for="df in datePresets"
                :key="df.value"
                :color="dateFilter === df.value ? 'primary' : undefined"
                :variant="dateFilter === df.value ? 'flat' : 'tonal'"
                size="small"
                rounded="lg"
                class="text-none"
                @click="df.value === 'custom' ? (customDateDialog = true) : setDateFilter(df.value)"
              >{{ df.label }}</v-chip>
              <span
                v-if="dateFilter === 'custom' && customDateFrom && customDateTo"
                class="text-caption text-medium-emphasis ml-1"
              >{{ customDateFrom }} — {{ customDateTo }}</span>
            </div>
          </div>
        </div>
      </v-expand-transition>

      <!-- Active filter summary -->
      <template v-if="activeFilters.length">
        <v-divider />
        <div class="d-flex flex-wrap align-center ga-2 pa-3 inv-active-filters">
          <span class="text-caption text-medium-emphasis mr-1">Active:</span>
          <v-chip
            v-for="f in activeFilters"
            :key="f.key"
            size="small"
            rounded="lg"
            color="primary"
            variant="tonal"
            closable
            @click:close="f.clear()"
          >{{ f.label }}</v-chip>
          <v-btn
            variant="text"
            size="small"
            color="error"
            class="text-none"
            prepend-icon="mdi-close-circle-outline"
            @click="clearAllFilters"
          >Clear all</v-btn>
        </div>
      </template>
    </v-card>

    <!-- ═══════════════ BULK ACTION BAR ═══════════════ -->
    <v-expand-transition>
      <div v-if="selectedIds.length" class="inv-bulkbar mb-3">
        <v-icon size="20">mdi-checkbox-multiple-marked-outline</v-icon>
        <span class="text-body-2 font-weight-medium">
          {{ selectedIds.length }} item{{ selectedIds.length === 1 ? '' : 's' }} selected
        </span>
        <v-spacer />
        <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-download-outline" @click="exportSelected">Export</v-btn>
        <v-btn v-if="canEdit" variant="tonal" size="small" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-table-edit" to="/inventory/bulk?mode=edit">Edit mode</v-btn>
        <v-btn variant="text" size="small" class="text-none" @click="selectedIds = []">Clear</v-btn>
      </div>
    </v-expand-transition>

    <!-- ═══════════════ CONTENT ═══════════════ -->
    <v-card rounded="lg" border class="overflow-hidden inv-content">
      <v-progress-linear v-if="currentResource.loading.value" color="primary" indeterminate />

      <EmptyState
        v-if="!currentResource.loading.value && !filteredItems.length"
        icon="mdi-package-variant-closed"
        :title="hasActiveFilters ? 'No matching records' : 'Nothing here yet'"
        :message="hasActiveFilters ? 'Try adjusting or clearing your filters.' : 'Get started by adding your first item.'"
      >
        <div v-if="hasActiveFilters" class="d-flex justify-center mt-2">
          <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-filter-remove-outline" @click="clearAllFilters">
            Clear filters
          </v-btn>
        </div>
        <div v-else-if="canEdit" class="d-flex justify-center mt-2">
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" :to="createPaths[tab]">
            {{ createLabels[tab] }}
          </v-btn>
        </div>
      </EmptyState>

      <!-- ══ CARD / GRID VIEW (stocks) ══ -->
      <div v-else-if="tab === 'stocks' && viewMode === 'grid'" class="pa-3">
        <v-row dense>
          <v-col v-for="row in pagedItems" :key="row.id" cols="12" sm="6" lg="4" xl="3">
            <div class="inv-card h-100" @click="$router.push(`/inventory/stocks/${row.id}`)">
              <div class="d-flex align-start justify-space-between mb-2">
                <div class="d-flex align-center" style="gap:10px; min-width:0">
                  <div class="inv-card-avatar" :class="`inv-av-${stockStatus(row).key}`">
                    {{ initials(row.medication_name || row.name) }}
                  </div>
                  <div style="min-width:0">
                    <div class="text-body-2 font-weight-bold text-truncate">{{ row.medication_name || row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis text-truncate">
                      {{ row.generic_name || row.barcode || `SKU #${row.id}` }}
                    </div>
                  </div>
                </div>
                <span class="status-pill" :class="`status-${stockStatus(row).key}`">
                  <v-icon size="13">{{ stockStatus(row).icon }}</v-icon>
                  {{ stockStatus(row).label }}
                </span>
              </div>

              <div class="d-flex flex-wrap ga-1 mb-3">
                <v-chip v-if="row.category_name" size="x-small" variant="tonal" color="primary">{{ row.category_name }}</v-chip>
                <v-chip
                  v-if="row.classification_name"
                  size="x-small"
                  variant="tonal"
                  :color="classificationColor(row.classification_name)"
                >{{ row.classification_name }}</v-chip>
                <v-chip v-if="row.branch_name" size="x-small" variant="tonal" color="grey">{{ row.branch_name }}</v-chip>
              </div>

              <div class="inv-card-metric">
                <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
                  <span>On hand</span>
                  <span>reorder at {{ Number(row.reorder_level ?? 0).toLocaleString() }}</span>
                </div>
                <div class="d-flex align-end justify-space-between mb-1">
                  <span class="text-h6 font-weight-bold">
                    {{ Number(row.total_quantity ?? 0).toLocaleString() }}
                    <span class="text-caption text-medium-emphasis font-weight-regular">{{ row.unit_abbreviation || '' }}</span>
                  </span>
                  <span v-if="row.items_per_unit > 0" class="text-caption text-info">{{ row.items_per_unit }} items/unit</span>
                </div>
                <v-progress-linear
                  :model-value="stockLevelPct(row)"
                  :color="stockStatus(row).key === 'ok' ? 'success' : stockStatus(row).key === 'low' ? 'warning' : 'error'"
                  height="6"
                  rounded
                />
              </div>

              <v-divider class="my-3" />

              <div class="d-flex justify-space-between">
                <div>
                  <div class="text-caption text-medium-emphasis">Unit cost</div>
                  <div class="text-body-2 font-weight-medium">{{ formatMoney(row.cost_price) }}</div>
                </div>
                <div class="text-center">
                  <div class="text-caption text-medium-emphasis">Price</div>
                  <div class="text-body-2 font-weight-medium">{{ formatMoney(row.selling_price) }}</div>
                </div>
                <div class="text-right">
                  <div class="text-caption text-medium-emphasis">Retail value</div>
                  <div class="text-body-2 font-weight-bold text-primary">
                    {{ formatMoney(Number(row.total_quantity || 0) * Number(row.selling_price || 0)) }}
                  </div>
                </div>
              </div>

              <div v-if="activeBatches(row).length" class="d-flex flex-wrap ga-1 mt-3">
                <v-chip v-for="b in activeBatches(row).slice(0, 3)" :key="b.id" size="x-small" variant="tonal" color="primary">
                  {{ b.batch_number || 'No #' }}
                  <span class="text-medium-emphasis ml-1">×{{ b.quantity_remaining }}</span>
                </v-chip>
                <v-chip v-if="activeBatches(row).length > 3" size="x-small" variant="tonal" color="grey">
                  +{{ activeBatches(row).length - 3 }}
                </v-chip>
              </div>
            </div>
          </v-col>
        </v-row>
      </div>

      <!-- ══ TABLE VIEW ══ -->
      <div
        v-else
        class="table-wrap"
        :class="{
          'table-sticky': tab === 'stocks',
          'table-tall': tab === 'stocks' && !showOverview
        }"
      >
        <!-- STOCKS -->
        <table v-if="tab === 'stocks'" class="inv-table">
          <thead>
            <tr>
              <th class="col-check">
                <v-checkbox-btn
                  :model-value="allSelected"
                  :indeterminate="someSelected"
                  density="compact"
                  color="primary"
                  hide-details
                  @update:model-value="toggleAll"
                />
              </th>
              <th class="row-num">#</th>
              <th class="sortable-th" @click="toggleStockSort('medication_name')">
                Item
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'medication_name' }">
                  {{ stockSortKey === 'medication_name' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}
                </v-icon>
              </th>
              <th>Category</th>
              <th>Classification</th>
              <th>Batches</th>
              <th class="text-right sortable-th" @click="toggleStockSort('total_quantity')">
                On hand
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'total_quantity' }">
                  {{ stockSortKey === 'total_quantity' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}
                </v-icon>
              </th>
              <th class="text-right">Reorder</th>
              <th class="text-right sortable-th" @click="toggleStockSort('cost_price')">
                Cost / price
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'cost_price' }">
                  {{ stockSortKey === 'cost_price' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}
                </v-icon>
              </th>
              <th class="text-right sortable-th" @click="toggleStockSort('retail_value')">
                Retail value
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'retail_value' }">
                  {{ stockSortKey === 'retail_value' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}
                </v-icon>
              </th>
              <th>{{ $t('common.status') }}</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, i) in pagedItems"
              :key="row.id"
              class="inv-row-click"
              :class="{ 'inv-row-selected': selectedIds.includes(row.id) }"
              @click="$router.push(`/inventory/stocks/${row.id}`)"
            >
              <td class="col-check" @click.stop>
                <v-checkbox-btn
                  :model-value="selectedIds.includes(row.id)"
                  density="compact"
                  color="primary"
                  hide-details
                  @update:model-value="toggleRow(row.id)"
                />
              </td>
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="inv-avatar" :class="`inv-av-${stockStatus(row).key}`">
                    {{ initials(row.medication_name || row.name) }}
                  </div>
                  <div style="min-width:0">
                    <div class="font-weight-medium text-truncate" style="max-width: 220px">
                      {{ row.medication_name || row.name || '—' }}
                    </div>
                    <div class="text-caption text-medium-emphasis text-truncate" style="max-width: 220px">
                      <span v-if="row.generic_name">{{ row.generic_name }}</span>
                      <span v-else-if="row.barcode">{{ row.barcode }}</span>
                      <span v-else>SKU #{{ row.id }}</span>
                      <span v-if="row.location_in_store"> · {{ row.location_in_store }}</span>
                    </div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip v-if="row.category_name" size="small" variant="tonal" color="primary">{{ row.category_name }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td>
                <v-chip
                  v-if="row.classification_name"
                  size="small"
                  variant="tonal"
                  :color="classificationColor(row.classification_name)"
                >{{ row.classification_name }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td>
                <div v-if="activeBatches(row).length" class="d-flex flex-wrap" style="gap:4px; max-width: 200px">
                  <v-chip v-for="b in activeBatches(row).slice(0, 2)" :key="b.id" size="x-small" variant="tonal" color="primary">
                    {{ b.batch_number || 'No #' }}
                    <span class="text-medium-emphasis ml-1">×{{ b.quantity_remaining }}</span>
                  </v-chip>
                  <v-chip
                    v-if="activeBatches(row).length > 2"
                    size="x-small"
                    variant="tonal"
                    color="grey"
                    :title="activeBatches(row).map(b => b.batch_number || 'No #').join(', ')"
                  >+{{ activeBatches(row).length - 2 }}</v-chip>
                </div>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td class="text-right">
                <div class="d-inline-flex flex-column align-end" style="min-width: 96px">
                  <span class="font-weight-bold">
                    {{ Number(row.total_quantity ?? 0).toLocaleString() }}
                    <span class="text-caption text-medium-emphasis font-weight-regular">{{ row.unit_abbreviation || '' }}</span>
                  </span>
                  <v-progress-linear
                    :model-value="stockLevelPct(row)"
                    :color="stockStatus(row).key === 'ok' ? 'success' : stockStatus(row).key === 'low' ? 'warning' : 'error'"
                    height="4"
                    rounded
                    class="mt-1"
                    style="width: 70px"
                  />
                  <span v-if="row.items_per_unit > 0" class="text-caption text-info">{{ row.items_per_unit }} items/unit</span>
                </div>
              </td>
              <td class="text-right text-medium-emphasis">{{ Number(row.reorder_level ?? 0).toLocaleString() }}</td>
              <td class="text-right">
                <div class="inv-price-cell">
                  <span class="font-weight-medium">{{ formatMoney(row.cost_price) }}</span>
                  <span class="text-caption text-medium-emphasis">
                    <v-icon size="11">mdi-arrow-right</v-icon> {{ formatMoney(row.selling_price) }}
                  </span>
                </div>
              </td>
              <td class="text-right font-weight-bold">
                {{ formatMoney(Number(row.total_quantity || 0) * Number(row.selling_price || 0)) }}
              </td>
              <td>
                <span class="status-pill" :class="`status-${stockStatus(row).key}`">
                  <v-icon size="13">{{ stockStatus(row).icon }}</v-icon>
                  {{ stockStatus(row).label }}
                </span>
              </td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="190">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View details" :to="`/inventory/stocks/${row.id}`" />
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit item" :to="`/inventory/stocks/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- CATEGORIES -->
        <table v-else-if="tab === 'categories'" class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Category</th>
              <th>Description</th>
              <th class="text-right">SKUs</th>
              <th class="text-right">Units on hand</th>
              <th class="text-right">Retail value</th>
              <th>Share</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="inv-avatar" :style="{ background: categoryColor(row.id) + '22', color: categoryColor(row.id) }">
                    <v-icon size="16">mdi-shape</v-icon>
                  </div>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ row.id }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width: 280px">
                <div class="text-truncate">{{ row.description || '—' }}</div>
              </td>
              <td class="text-right font-weight-medium">{{ countByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right font-weight-bold">{{ formatMoney(retailByCategory(row.id)) }}</td>
              <td style="min-width: 150px">
                <div class="d-flex align-center ga-2">
                  <v-progress-linear
                    :model-value="sharePctByCategory(row.id)"
                    :color="categoryColor(row.id)"
                    height="6"
                    rounded
                    class="flex-grow-1"
                  />
                  <span class="text-caption text-medium-emphasis">{{ sharePctByCategory(row.id) }}%</span>
                </div>
              </td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="160">
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit" :to="`/inventory/categories/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- UNITS -->
        <table v-else-if="tab === 'units'" class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Unit</th>
              <th>Abbreviation</th>
              <th class="text-right">SKUs</th>
              <th class="text-right">Total on hand</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="inv-avatar inv-av-ok">
                    <v-icon size="16">mdi-ruler</v-icon>
                  </div>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ row.id }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" variant="tonal" color="success">{{ row.abbreviation || row.symbol || '—' }}</v-chip>
              </td>
              <td class="text-right font-weight-medium">{{ countByUnit(row.id).toLocaleString() }}</td>
              <td class="text-right">
                {{ unitsByUnit(row.id).toLocaleString() }}
                <span class="text-caption text-medium-emphasis">{{ row.abbreviation || '' }}</span>
              </td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="160">
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit" :to="`/inventory/units/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- CLASSIFICATIONS -->
        <table v-else-if="tab === 'classifications'" class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Classification</th>
              <th>Description</th>
              <th>Status</th>
              <th class="text-right">SKUs</th>
              <th class="text-right">Units on hand</th>
              <th class="text-right">Retail value</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="inv-avatar">
                    <v-icon size="16">mdi-label-multiple-outline</v-icon>
                  </div>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">
                      ID #{{ row.id }}
                      <v-chip v-if="row.name === 'Routine'" size="x-small" variant="tonal" color="primary" class="ml-1">Default</v-chip>
                    </div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width: 280px">
                <div class="text-truncate">{{ row.description || '—' }}</div>
              </td>
              <td>
                <v-chip :color="row.is_active === false ? 'grey' : 'success'" size="x-small" variant="tonal">
                  {{ row.is_active === false ? 'Inactive' : 'Active' }}
                </v-chip>
              </td>
              <td class="text-right font-weight-medium">{{ (row.stock_count ?? countByClassification(row.id)).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByClassification(row.id).toLocaleString() }}</td>
              <td class="text-right font-weight-bold">{{ formatMoney(retailByClassification(row.id)) }}</td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="160">
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit" :to="`/inventory/classifications/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
            <tr v-if="!pagedItems.length">
              <td colspan="8" class="text-center text-medium-emphasis py-6">
                No classifications yet. "Routine" is created automatically.
              </td>
            </tr>
          </tbody>
        </table>

        <!-- ADJUSTMENTS -->
        <table v-else class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Item</th>
              <th>Reason</th>
              <th class="text-right">Change</th>
              <th>{{ $t('common.notes') }}</th>
              <th>Adjusted by</th>
              <th>When</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="inv-avatar" :class="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'inv-av-ok' : 'inv-av-out'">
                    <v-icon size="15">{{ (row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'mdi-arrow-up-bold' : 'mdi-arrow-down-bold' }}</v-icon>
                  </div>
                  <div>
                    <div class="font-weight-medium">{{ row.stock_name || '—' }}</div>
                    <div v-if="row.batch" class="text-caption text-medium-emphasis">Batch #{{ row.batch }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" :color="reasonColor(row.reason)" variant="tonal" :prepend-icon="reasonIcon(row.reason)">
                  {{ reasonLabel(row.reason) }}
                </v-chip>
              </td>
              <td class="text-right">
                <span class="qty-delta" :class="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'qty-pos' : 'qty-neg'">
                  {{ (row.quantity_change ?? row.quantity ?? 0) > 0 ? '+' : '' }}{{ Number(row.quantity_change ?? row.quantity ?? 0).toLocaleString() }}
                </span>
              </td>
              <td class="text-medium-emphasis" style="max-width: 240px">
                <div class="text-truncate">{{ row.notes || row.reason_text || '—' }}</div>
              </td>
              <td class="text-medium-emphasis">{{ row.adjusted_by_name || 'System' }}</td>
              <td class="text-caption text-medium-emphasis">{{ formatDateTime(row.created_at) }}</td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="160">
                    <v-list-item prepend-icon="mdi-pencil" title="Edit" :to="`/inventory/adjustments/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- ══ PAGINATION ══ -->
      <template v-if="filteredItems.length">
        <v-divider />
        <div class="d-flex flex-wrap align-center pa-3 inv-pagination" style="gap:12px">
          <span class="text-caption text-medium-emphasis">
            Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of
            <strong>{{ filteredItems.length.toLocaleString() }}</strong>
          </span>
          <v-spacer />
          <div class="d-flex align-center" style="gap:8px">
            <span class="text-caption text-medium-emphasis">Rows</span>
            <v-select
              v-model="pageSize"
              :items="pageSizeOptions"
              density="compact"
              variant="outlined"
              rounded="lg"
              hide-details
              style="width: 88px"
            />
          </div>
          <v-pagination
            v-if="totalPages > 1"
            v-model="page"
            :length="totalPages"
            :total-visible="5"
            density="comfortable"
            rounded="lg"
            color="primary"
          />
        </div>
      </template>
    </v-card>

    <!-- ═══════════════ CUSTOM DATE DIALOG ═══════════════ -->
    <v-dialog v-model="customDateDialog" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center" style="gap:8px">
          <v-icon color="primary">mdi-calendar-range</v-icon>
          Custom Date Range
        </v-card-title>
        <v-card-text>
          <v-text-field
            v-model="customDateFromTemp"
            type="date"
            label="From"
            density="compact"
            variant="outlined"
            rounded="lg"
            class="mb-3"
          />
          <v-text-field
            v-model="customDateToTemp"
            type="date"
            label="To"
            density="compact"
            variant="outlined"
            rounded="lg"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDateDialog = false">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            :disabled="!customDateFromTemp || !customDateToTemp"
            @click="applyCustomDate"
          >Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatMoney, formatDateTime } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'
import { useBranding } from '~/composables/useBranding'
import { ADMIN_ROLES } from '~/utils/permissions'

const branchStore = useBranchStore()
const auth = useAuthStore()

// Tenant palette configured at /ims/organization/branding. Exposed to the
// hero's CSS through custom properties so the stylesheet stays declarative.
//
// The third gradient stop is the accent *mixed toward the primary* rather than
// the raw accent: accent colours are typically near-white highlights, and the
// action buttons sit at that end of the panel — a raw accent would leave the
// glass/outline tiers as white-on-pale-peach.
const brand = useBranding()
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

// RBAC: supervisors (admins + branch managers) manage items; destructive
// deletes are tenant-admin only (mirrors the backend matrix).
const canEdit = computed(() =>
  [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))
const canDelete = computed(() => ADMIN_ROLES.has(auth.role))

const tab = ref('stocks')
const search = ref('')
const batchFilter = ref('')
const categoryFilter = ref('all')
const classificationFilter = ref('all')
const statusFilter = ref('all')
const branchFilter = ref('all')
const dateFilter = ref('all')
const customDateFrom = ref('')
const customDateTo = ref('')
const customDateDialog = ref(false)
const customDateFromTemp = ref('')
const customDateToTemp = ref('')
const page = ref(1)
const pageSize = ref(20)
const pageSizeOptions = [10, 20, 50, 100]

// Presentation state
const viewMode = ref('table')
const showAdvanced = ref(false)
const selectedIds = ref([])

// ── Overview panels (6 stat cards + stock health / valuation / category mix) ──
// Collapsing them hands their vertical space to the stock table, which is what
// supervisors want when working through a long pick or audit list. The choice is
// persisted so it survives a reload — see `toggleOverview`. Default: visible.
const OVERVIEW_KEY = 'inv_overview_visible'
const showOverview = ref(
  import.meta.client ? localStorage.getItem(OVERVIEW_KEY) !== '0' : true
)
function toggleOverview() {
  showOverview.value = !showOverview.value
}
watch(showOverview, (on) => {
  if (!import.meta.client) return
  localStorage.setItem(OVERVIEW_KEY, on ? '1' : '0')
})

const datePresets = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'Yesterday', value: 'yesterday' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'This month', value: 'month' },
  { label: 'Custom', value: 'custom' },
]

function setDateFilter(val) {
  dateFilter.value = val
  if (val !== 'custom') {
    customDateFrom.value = ''
    customDateTo.value = ''
  }
}

function applyCustomDate() {
  customDateFrom.value = customDateFromTemp.value
  customDateTo.value = customDateToTemp.value
  dateFilter.value = 'custom'
  customDateDialog.value = false
}

function getDateRange() {
  const now = new Date()
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())
  switch (dateFilter.value) {
    case 'today':
      return { from: startOfDay(now), to: null }
    case 'yesterday': {
      const y = new Date(now)
      y.setDate(y.getDate() - 1)
      return { from: startOfDay(y), to: startOfDay(now) }
    }
    case '7d': {
      const d = new Date(now)
      d.setDate(d.getDate() - 7)
      return { from: startOfDay(d), to: null }
    }
    case '30d': {
      const d = new Date(now)
      d.setDate(d.getDate() - 30)
      return { from: startOfDay(d), to: null }
    }
    case 'month':
      return { from: new Date(now.getFullYear(), now.getMonth(), 1), to: null }
    case 'custom': {
      const from = customDateFrom.value ? new Date(customDateFrom.value) : null
      const to = customDateTo.value ? new Date(customDateTo.value + 'T23:59:59') : null
      return { from, to }
    }
    default:
      return { from: null, to: null }
  }
}

const stocks = useResource('/inventory/stocks/')
const categoriesRes = useResource('/inventory/categories/')
const classificationsRes = useResource('/inventory/classifications/')
const units = useResource('/inventory/units/')
const adjustments = useResource('/inventory/adjustments/')

const resourceMap = { stocks, categories: categoriesRes, classifications: classificationsRes, units, adjustments }
const currentResource = computed(() => resourceMap[tab.value])
const currentItems = computed(() => currentResource.value.items.value || [])

const createPaths = {
  stocks: '/inventory/stocks/new',
  categories: '/inventory/categories/new',
  classifications: '/inventory/classifications/new',
  units: '/inventory/units/new',
  adjustments: '/inventory/adjustments/new'
}
const createLabels = {
  stocks: 'Add Stock',
  categories: 'Add Category',
  classifications: 'Add Classification',
  units: 'Add Unit',
  adjustments: 'New Adjustment'
}

const searchPlaceholder = computed(() => {
  if (tab.value === 'stocks') return 'Search by name, brand, generic, strength, barcode…'
  if (tab.value === 'categories') return 'Search categories…'
  if (tab.value === 'classifications') return 'Search classifications…'
  if (tab.value === 'units') return 'Search units…'
  return 'Search adjustments…'
})

const tabs = computed(() => [
  { value: 'stocks', label: 'Stocks', icon: 'mdi-pill', count: stocks.items.value?.length },
  { value: 'categories', label: 'Categories', icon: 'mdi-shape', count: categoriesRes.items.value?.length },
  { value: 'classifications', label: 'Classifications', icon: 'mdi-label-multiple-outline', count: classificationsRes.items.value?.length },
  { value: 'units', label: 'Units', icon: 'mdi-ruler', count: units.items.value?.length },
  { value: 'adjustments', label: 'Adjustments', icon: 'mdi-tune-vertical', count: adjustments.items.value?.length }
])

// --- status helpers ---
function stockStatus(s) {
  const qty = Number(s.total_quantity ?? s.quantity ?? 0)
  const reorder = Number(s.reorder_level ?? 0)
  if (qty <= 0) return { key: 'out', label: 'Out of stock', icon: 'mdi-alert-octagon' }
  if (qty <= reorder) return { key: 'low', label: 'Low', icon: 'mdi-alert' }
  return { key: 'ok', label: 'In stock', icon: 'mdi-check-circle' }
}

/** Stock cover relative to twice the reorder level, capped at 100%. */
function stockLevelPct(row) {
  const qty = Number(row.total_quantity ?? 0)
  const reorder = Number(row.reorder_level ?? 0)
  const target = Math.max(reorder * 2, qty, 1)
  return Math.max(0, Math.min(100, (qty / target) * 100))
}

function activeBatches(row) {
  return (row.batches || []).filter((b) => b.quantity_remaining > 0)
}

function initials(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '—'
  return parts.map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}

// --- KPIs (always reflect stocks) ---
const kpis = computed(() => {
  const all = stocks.items.value || []
  const horizon = Date.now() + 90 * 86400000
  let healthy = 0
  let low = 0
  let out = 0
  let expiring = 0
  let unitsTotal = 0
  let retail = 0
  let cost = 0
  for (const s of all) {
    const qty = Number(s.total_quantity ?? s.quantity ?? 0)
    const reorder = Number(s.reorder_level ?? 0)
    if (qty <= 0) out += 1
    else if (qty <= reorder) low += 1
    else healthy += 1
    unitsTotal += qty
    retail += qty * Number(s.selling_price || 0)
    cost += qty * Number(s.cost_price || 0)
    const batches = s.batches || []
    if (
      batches.some((b) => b.expiry_date && new Date(b.expiry_date).getTime() <= horizon) ||
      (s.expiry_date && new Date(s.expiry_date).getTime() <= horizon)
    ) expiring += 1
  }
  return {
    skus: all.length,
    healthy,
    low,
    out,
    expiring,
    units: unitsTotal,
    retail,
    cost,
    margin: retail - cost,
    alert: low + out
  }
})

const marginPct = computed(() => (kpis.value.retail ? (kpis.value.margin / kpis.value.retail) * 100 : 0))

const kpiCards = computed(() => {
  const k = kpis.value
  const total = Math.max(k.skus, 1)
  return [
    {
      title: 'Stock items',
      value: k.skus.toLocaleString(),
      hint: `${k.units.toLocaleString()} units on hand`,
      icon: 'mdi-cube-outline',
      tone: 'blue',
      badge: null,
      bars: null
    },
    {
      title: 'Healthy stock',
      value: k.healthy.toLocaleString(),
      hint: `${Math.round((k.healthy / total) * 100)}% of the catalogue`,
      icon: 'mdi-check-circle-outline',
      tone: 'green',
      badge: null,
      bars: null
    },
    {
      title: 'Low / out of stock',
      value: k.alert.toLocaleString(),
      hint: `${k.out} out · ${k.low} below reorder`,
      icon: 'mdi-alert-circle-outline',
      tone: 'amber',
      badge: k.alert ? 'Action' : null,
      bars: [
        { pct: (k.healthy / total) * 100, color: '#22c55e' },
        { pct: (k.low / total) * 100, color: '#f59e0b' },
        { pct: (k.out / total) * 100, color: '#ef4444' }
      ]
    },
    {
      title: 'Expiring ≤ 90 days',
      value: k.expiring.toLocaleString(),
      hint: 'Batches approaching expiry',
      icon: 'mdi-clock-alert-outline',
      tone: 'red',
      badge: k.expiring ? 'Risk' : null,
      bars: null
    },
    {
      title: 'Value at cost',
      value: formatMoney(k.cost),
      hint: 'Capital tied up in stock',
      icon: 'mdi-cash-lock',
      tone: 'violet',
      badge: null,
      bars: null
    },
    {
      title: 'Retail value',
      value: formatMoney(k.retail),
      hint: `${marginPct.value.toFixed(1)}% margin potential`,
      icon: 'mdi-cash-multiple',
      tone: 'teal',
      badge: null,
      bars: null
    }
  ]
})

const healthSegments = computed(() => [
  { value: kpis.value.healthy, color: '#22c55e', label: 'Healthy' },
  { value: kpis.value.low, color: '#f59e0b', label: 'Low' },
  { value: kpis.value.out, color: '#ef4444', label: 'Out of stock' }
])

const healthPct = computed(() => (kpis.value.skus ? Math.round((kpis.value.healthy / kpis.value.skus) * 100) : 0))
const healthChipColor = computed(() => (healthPct.value >= 80 ? 'success' : healthPct.value >= 60 ? 'warning' : 'error'))

const healthLegend = computed(() => {
  const total = Math.max(kpis.value.skus, 1)
  return [
    { label: 'Healthy', count: kpis.value.healthy, color: '#22c55e' },
    { label: 'Low stock', count: kpis.value.low, color: '#f59e0b' },
    { label: 'Out of stock', count: kpis.value.out, color: '#ef4444' }
  ].map((r) => ({ ...r, pct: Math.round((r.count / total) * 100) }))
})

// --- Filters ---
const categoryOptions = computed(() => {
  const opts = [{ label: 'All categories', value: 'all' }]
  for (const c of categoriesRes.items.value || []) opts.push({ label: c.name, value: c.id })
  return opts
})
const classificationOptions = computed(() => {
  const opts = [{ label: 'All classifications', value: 'all' }]
  for (const c of classificationsRes.items.value || []) opts.push({ label: c.name, value: c.id, description: c.description })
  return opts
})
const statusOptions = computed(() => [
  { label: 'All', value: 'all', icon: 'mdi-view-grid-outline', count: kpis.value.skus },
  { label: 'In stock', value: 'ok', icon: 'mdi-check-circle-outline', count: kpis.value.healthy },
  { label: 'Low', value: 'low', icon: 'mdi-alert-outline', count: kpis.value.low },
  { label: 'Out', value: 'out', icon: 'mdi-alert-octagon-outline', count: kpis.value.out }
])

function setStatusFilter(val) {
  // v-chip-group can emit null when a chip is toggled off — fall back to "all".
  statusFilter.value = val || 'all'
}

const SOFT_ROLES = new Set(['cashier', 'pharmacist', 'pharmacy_tech'])
const branchOptions = computed(() => {
  if (branchStore.branchLocked) {
    // Locked users only see their branch
    const b = branchStore.currentBranch
    return b ? [{ label: b.name, value: b.id }] : [{ label: 'All branches', value: 'all' }]
  }
  // Soft-assign roles see only allowed (assigned + nearby) branches
  const source = SOFT_ROLES.has(auth.role) ? branchStore.allowedBranches : branchStore.activeBranches
  const opts = source.length > 1 ? [{ label: 'All branches', value: 'all' }] : []
  for (const b of source) opts.push({ label: b.name, value: b.id })
  return opts
})

const activeBranchName = computed(() => {
  const b = branchStore.currentBranch
  if (b) return b.name
  if (branchFilter.value !== 'all') {
    return branchOptions.value.find((o) => o.value === branchFilter.value)?.label || ''
  }
  return ''
})

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = currentItems.value.slice()
  if (tab.value === 'stocks') {
    if (categoryFilter.value !== 'all') arr = arr.filter(s => s.category === categoryFilter.value)
    if (classificationFilter.value !== 'all') arr = arr.filter(s => s.classification === classificationFilter.value)
    if (statusFilter.value !== 'all') arr = arr.filter(s => stockStatus(s).key === statusFilter.value)
    if (branchFilter.value !== 'all') arr = arr.filter(s => s.branch === branchFilter.value)
    const bn = (batchFilter.value || '').toLowerCase().trim()
    if (bn) {
      arr = arr.filter(s => (s.batches || []).some(b =>
        (b.batch_number || '').toLowerCase().includes(bn)
      ))
    }
  }
  // Date filter on created_at
  if (dateFilter.value !== 'all') {
    const { from, to } = getDateRange()
    if (from || to) {
      arr = arr.filter(row => {
        const created = row.created_at ? new Date(row.created_at) : null
        if (!created) return false
        if (from && created < from) return false
        if (to && created > to) return false
        return true
      })
    }
  }
  if (!q) return arr
  return arr.filter(row => {
    const fields = ['medication_name', 'brand_name', 'generic_name', 'strength', 'dosage_form',
      'barcode', 'abbreviation', 'category_name', 'classification_name', 'unit_name',
      'unit_abbreviation', 'branch_name', 'location_in_store', 'batch_number']
    return fields.some(f => {
      const v = row[f]
      return v != null && String(v).toLowerCase().includes(q)
    })
  })
})

const advancedFilterCount = computed(() => {
  let n = 0
  if (batchFilter.value) n += 1
  if (dateFilter.value !== 'all') n += 1
  return n
})

const activeFilters = computed(() => {
  const out = []
  if (tab.value === 'stocks') {
    if (categoryFilter.value !== 'all') {
      const label = categoryOptions.value.find(o => o.value === categoryFilter.value)?.label || 'Category'
      out.push({ key: 'category', label, clear: () => { categoryFilter.value = 'all' } })
    }
    if (classificationFilter.value !== 'all') {
      const label = classificationOptions.value.find(o => o.value === classificationFilter.value)?.label || 'Classification'
      out.push({ key: 'classification', label, clear: () => { classificationFilter.value = 'all' } })
    }
    if (statusFilter.value !== 'all') {
      const label = statusOptions.value.find(o => o.value === statusFilter.value)?.label || 'Status'
      out.push({ key: 'status', label: `Status: ${label}`, clear: () => { statusFilter.value = 'all' } })
    }
    if (branchFilter.value !== 'all') {
      const label = branchOptions.value.find(o => o.value === branchFilter.value)?.label || 'Branch'
      out.push({ key: 'branch', label, clear: () => { branchFilter.value = 'all' } })
    }
    if (batchFilter.value) {
      out.push({ key: 'batch', label: `Batch: ${batchFilter.value}`, clear: () => { batchFilter.value = '' } })
    }
  }
  if (dateFilter.value !== 'all') {
    const label = datePresets.find(d => d.value === dateFilter.value)?.label || 'Date'
    out.push({ key: 'date', label: `Added: ${label}`, clear: () => setDateFilter('all') })
  }
  if (search.value) {
    out.push({ key: 'search', label: `“${search.value}”`, clear: () => { search.value = '' } })
  }
  return out
})

const hasActiveFilters = computed(() => activeFilters.value.length > 0)

function clearAllFilters() {
  search.value = ''
  batchFilter.value = ''
  categoryFilter.value = 'all'
  classificationFilter.value = 'all'
  statusFilter.value = 'all'
  if (!branchStore.branchLocked) branchFilter.value = 'all'
  setDateFilter('all')
}

// --- Stock sorting ---
const stockSortKey = ref('created_at')
const stockSortDir = ref('desc')
const NUMERIC_SORT_KEYS = new Set(['total_quantity', 'reorder_level', 'cost_price', 'selling_price'])

function toggleStockSort(key) {
  if (stockSortKey.value === key) {
    stockSortDir.value = stockSortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    stockSortKey.value = key
    stockSortDir.value = 'asc'
  }
  page.value = 1
}

function sortValue(row, key) {
  if (key === 'created_at') return row.created_at ? new Date(row.created_at).getTime() : 0
  if (key === 'retail_value') return Number(row.total_quantity || 0) * Number(row.selling_price || 0)
  if (NUMERIC_SORT_KEYS.has(key)) return Number(row[key] || 0)
  return String(row[key] || '').toLowerCase()
}

const sortedStocks = computed(() => {
  if (tab.value !== 'stocks') return filteredItems.value
  const arr = filteredItems.value.slice()
  const key = stockSortKey.value
  const dir = stockSortDir.value === 'asc' ? 1 : -1
  arr.sort((a, b) => {
    const va = sortValue(a, key)
    const vb = sortValue(b, key)
    if (va < vb) return -1 * dir
    if (va > vb) return 1 * dir
    return 0
  })
  return arr
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredItems.value.length / pageSize.value)))
const pagedItems = computed(() => {
  const items = tab.value === 'stocks' ? sortedStocks.value : filteredItems.value
  const s = (page.value - 1) * pageSize.value
  return items.slice(s, s + pageSize.value)
})
const rangeStart = computed(() => filteredItems.value.length === 0 ? 0 : (page.value - 1) * pageSize.value + 1)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filteredItems.value.length))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }

// --- Selection ---
const pagedIds = computed(() => pagedItems.value.map(r => r.id))
const allSelected = computed(() => pagedIds.value.length > 0 && pagedIds.value.every(id => selectedIds.value.includes(id)))
const someSelected = computed(() => selectedIds.value.length > 0 && !allSelected.value)

function toggleAll(checked) {
  if (checked) {
    selectedIds.value = [...new Set([...selectedIds.value, ...pagedIds.value])]
  } else {
    selectedIds.value = selectedIds.value.filter(id => !pagedIds.value.includes(id))
  }
}
function toggleRow(id) {
  const i = selectedIds.value.indexOf(id)
  if (i === -1) selectedIds.value.push(id)
  else selectedIds.value.splice(i, 1)
}

watch(
  [tab, search, batchFilter, categoryFilter, classificationFilter, statusFilter, branchFilter, dateFilter, customDateFrom, customDateTo, pageSize],
  () => {
    page.value = 1
    selectedIds.value = []
  }
)

watch(tab, () => { viewMode.value = 'table' })

// Row selection only exists in the table view — drop it when switching away.
watch(viewMode, (mode) => { if (mode !== 'table') selectedIds.value = [] })

function countByCategory(id) {
  return (stocks.items.value || []).filter(s => s.category === id).length
}
function unitsByCategory(id) {
  return (stocks.items.value || [])
    .filter(s => s.category === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}
function retailByCategory(id) {
  return (stocks.items.value || [])
    .filter(s => s.category === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
}
const totalRetailAll = computed(() =>
  (stocks.items.value || []).reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
)
function sharePctByCategory(id) {
  const total = totalRetailAll.value
  if (!total) return 0
  return Math.round((retailByCategory(id) / total) * 100)
}
const _catColors = ['#3b82f6', '#22c55e', '#f59e0b', '#a855f7', '#ef4444', '#06b6d4', '#84cc16', '#ec4899', '#14b8a6', '#eab308']
function categoryColor(id) {
  return _catColors[(Number(id) || 0) % _catColors.length]
}

const topCategories = computed(() =>
  (categoriesRes.items.value || [])
    .map(c => ({
      id: c.id,
      name: c.name || '—',
      count: countByCategory(c.id),
      retail: retailByCategory(c.id),
      pct: sharePctByCategory(c.id),
      color: categoryColor(c.id)
    }))
    .filter(c => c.retail > 0)
    .sort((a, b) => b.retail - a.retail)
    .slice(0, 6)
)

function countByUnit(id) {
  return (stocks.items.value || []).filter(s => s.unit === id).length
}
function unitsByUnit(id) {
  return (stocks.items.value || [])
    .filter(s => s.unit === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}

function countByClassification(id) {
  return (stocks.items.value || []).filter(s => s.classification === id).length
}
function unitsByClassification(id) {
  return (stocks.items.value || [])
    .filter(s => s.classification === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}
function retailByClassification(id) {
  return (stocks.items.value || [])
    .filter(s => s.classification === id)
    .reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
}
const _classColors = {
  routine: 'primary', emergency: 'error', 'cold chain': 'info',
  controlled: 'purple', 'high value': 'warning', other: 'grey',
}
function classificationColor(name) {
  if (!name) return 'grey'
  const key = String(name).toLowerCase()
  if (_classColors[key]) return _classColors[key]
  return _catColors[(name.charCodeAt(0) || 0) % _catColors.length]
}

const _reasonMeta = {
  damage:             { label: 'Damage',             color: 'error',   icon: 'mdi-alert-octagon' },
  theft:              { label: 'Theft',              color: 'error',   icon: 'mdi-shield-alert' },
  expiry:             { label: 'Expiry',             color: 'warning', icon: 'mdi-clock-alert' },
  count_correction:   { label: 'Count correction',   color: 'info',    icon: 'mdi-counter' },
  return_to_supplier: { label: 'Return to supplier', color: 'purple',  icon: 'mdi-truck-fast' },
  other:              { label: 'Other',              color: 'grey',    icon: 'mdi-dots-horizontal' },
}
function reasonLabel(r) { return _reasonMeta[r]?.label || (r ? r.replace(/_/g, ' ') : '\u2014') }
function reasonColor(r) { return _reasonMeta[r]?.color || 'grey' }
function reasonIcon(r)  { return _reasonMeta[r]?.icon  || 'mdi-tag' }

// --- Export ---
function csvEscape(v) {
  const s = v == null ? '' : String(v)
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

function downloadCsv(filename, rows) {
  if (!rows.length) return
  const headers = [
    'id', 'medication_name', 'generic_name', 'brand_name', 'strength', 'dosage_form',
    'barcode', 'category_name', 'classification_name', 'unit_abbreviation',
    'branch_name', 'location_in_store', 'total_quantity', 'reorder_level',
    'cost_price', 'selling_price', 'retail_value', 'status', 'created_at'
  ]
  const lines = [headers.join(',')]
  for (const r of rows) {
    lines.push(headers.map((h) => {
      if (h === 'retail_value') return Number(r.total_quantity || 0) * Number(r.selling_price || 0)
      if (h === 'status') return stockStatus(r).label
      return csvEscape(r[h])
    }).join(','))
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${filename}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

function exportCsv() {
  if (tab.value !== 'stocks') return
  downloadCsv(`inventory-stocks-${new Date().toISOString().slice(0, 10)}`, sortedStocks.value)
}

function exportSelected() {
  if (tab.value !== 'stocks') return
  downloadCsv(
    `inventory-selected-${new Date().toISOString().slice(0, 10)}`,
    sortedStocks.value.filter(r => selectedIds.value.includes(r.id))
  )
}

function reload() {
  const params = { page_size: 2000 }
  if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
  currentResource.value.list(params)
}

function loadWithBranch(resource) {
  const params = { page_size: 2000 }
  if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
  resource.list(params)
}

watch(tab, (t) => { loadWithBranch(resourceMap[t]) }, { immediate: true })
onMounted(() => {
  brand.load()
  // Always load stocks + categories so KPIs and category filter populate even on other tabs
  if (!stocks.items.value?.length) loadWithBranch(stocks)
  if (!categoriesRes.items.value?.length) loadWithBranch(categoriesRes)
  if (!classificationsRes.items.value?.length) loadWithBranch(classificationsRes)
  branchStore.load()
  // Default branch filter to user's branch when locked
  if (branchStore.branchLocked && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  }
})

// Reload when branch changes
watch(() => branchStore.currentBranchId, () => {
  loadWithBranch(stocks)
  loadWithBranch(categoriesRes)
  loadWithBranch(classificationsRes)
  loadWithBranch(units)
  loadWithBranch(adjustments)
})
</script>

<style scoped>
/* ─────────────── Hero ───────────────
   Colours come from the tenant palette (see `heroTheme` in the script);
   the var() fallbacks mirror `BRAND_DEFAULTS` in utils/branding.js so the
   panel still renders if the vars are ever missing. */
.inv-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.inv-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.inv-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.inv-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.inv-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.inv-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.inv-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.inv-hero-iconbtn {
  color: #fff !important;
}

/* Hero action buttons — a saturated brand gradient washes out tonal/primary
   fills, so each tier gets an explicit high-contrast treatment. The emphasised
   tier always paints a white pill with the tenant's *darkest* brand colour as
   text, which stays readable whatever palette the tenant saves. */

/* 1. Emphasised — solid white chip with a lift. */
.inv-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  letter-spacing: 0.1px;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.inv-hero-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
  box-shadow: 0 9px 24px rgba(6, 44, 40, 0.34) !important;
}
.inv-hero-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}

/* 2. Outline — transparent with a bright white edge. */
.inv-hero-btn-outline {
  background: transparent !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1.5px solid rgba(255, 255, 255, 0.72) !important;
}
.inv-hero-btn-outline:hover {
  background: rgba(255, 255, 255, 0.18) !important;
  border-color: #ffffff !important;
}
.inv-hero-btn-outline :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}

/* 3. Glass — translucent fill for utility actions. */
.inv-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.inv-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.inv-hero-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
/* ─────────────── KPI cards ─────────────── */
.inv-kpi {
  position: relative;
  border-radius: 14px;
  padding: 14px 16px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.inv-kpi:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 28px rgba(15, 23, 42, 0.09);
}
.inv-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  border-radius: 14px 14px 0 0;
  background: currentColor;
  opacity: 0.85;
}
.inv-kpi-blue { color: #3b82f6; }
.inv-kpi-green { color: #22c55e; }
.inv-kpi-amber { color: #f59e0b; }
.inv-kpi-red { color: #ef4444; }
.inv-kpi-violet { color: #8b5cf6; }
.inv-kpi-teal { color: #0d9488; }
.inv-kpi-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: currentColor;
  color: #fff;
  opacity: 0.92;
}
.inv-kpi-icon :deep(.v-icon) { color: #fff; }
.inv-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.inv-kpi-value {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.2;
  color: rgb(var(--v-theme-on-surface));
}
.inv-kpi-foot {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.inv-kpi-bars {
  display: flex;
  height: 6px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(15, 23, 42, 0.06);
}
.inv-kpi-bars span { display: block; height: 100%; }

/* ─────────────── Panels ─────────────── */
.inv-panel { transition: box-shadow 0.18s ease; }
.inv-panel:hover { box-shadow: 0 10px 26px rgba(15, 23, 42, 0.07); }
.inv-panel-icon {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 10px;
  flex-shrink: 0;
}
.inv-panel-icon-green { background: rgba(34, 197, 94, 0.12); color: #16a34a; }
.inv-panel-icon-teal { background: rgba(13, 148, 136, 0.12); color: #0d9488; }
.inv-panel-icon-indigo { background: rgba(99, 102, 241, 0.12); color: #6366f1; }

.inv-legend {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 0;
}
.inv-legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 3px;
  flex-shrink: 0;
}
.inv-legend-pct { width: 38px; text-align: right; }

.inv-valuation-hero {
  border-radius: 12px;
  padding: 12px 14px;
  background: linear-gradient(135deg, rgba(13, 148, 136, 0.1), rgba(13, 148, 136, 0.02));
  border: 1px solid rgba(13, 148, 136, 0.16);
}
.inv-valuation-amount {
  font-size: 22px;
  font-weight: 800;
  color: #0d9488;
  line-height: 1.2;
}
.inv-metric-row {
  display: flex;
  justify-content: space-between;
  padding: 5px 0;
}

/* ─────────────── Tabs ─────────────── */
.inv-tabs {
  border-radius: 14px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  padding: 4px;
  overflow: hidden;
}
.inv-tabs :deep(.v-tab) {
  border-radius: 10px;
  text-transform: none;
  font-weight: 600;
  letter-spacing: 0;
  min-height: 42px;
}
.inv-tabs :deep(.v-tab.v-tab--selected) {
  background: rgba(var(--v-theme-primary), 0.1);
}

/* ─────────────── Toolbar ─────────────── */
.inv-search { flex: 1 1 300px; min-width: 220px; max-width: 460px; }
.inv-select { min-width: 170px; max-width: 220px; }
.inv-select-wide { min-width: 200px; max-width: 260px; }
.inv-status-chips { flex-wrap: wrap; }
.inv-advanced { background: rgba(15, 23, 42, 0.018); }
.inv-active-filters { background: rgba(var(--v-theme-primary), 0.045); }

/* ─────────────── Bulk bar ─────────────── */
.inv-bulkbar {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  color: #fff;
  background: linear-gradient(120deg, #0f766e, #0d9488);
  box-shadow: 0 10px 24px rgba(13, 148, 136, 0.22);
}
.inv-bulkbar :deep(.v-btn) { color: #fff !important; }

/* ─────────────── Grid cards ─────────────── */
.inv-card {
  border-radius: 14px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  padding: 14px;
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
}
.inv-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 16px 34px rgba(15, 23, 42, 0.11);
  border-color: rgba(var(--v-theme-primary), 0.35);
}
.inv-card-avatar {
  width: 38px;
  height: 38px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.3px;
  flex-shrink: 0;
  background: rgba(15, 23, 42, 0.06);
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.inv-card-metric {
  border-radius: 10px;
  padding: 10px;
  background: rgba(15, 23, 42, 0.025);
}

/* ─────────────── Avatars ─────────────── */
.inv-avatar {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.3px;
  flex-shrink: 0;
  background: rgba(15, 23, 42, 0.06);
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.inv-av-ok { background: rgba(34, 197, 94, 0.14); color: #15803d; }
.inv-av-low { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.inv-av-out { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }

/* ─────────────── Tables ─────────────── */
.table-wrap { overflow-x: auto; }
.table-sticky { max-height: 72vh; overflow-y: auto; }
/* With the overview panels collapsed there is nothing above the list, so the
   table can claim the extra height instead of leaving a dead gap. */
.table-sticky.table-tall { max-height: 84vh; }
.inv-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 14px; }
.inv-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgb(var(--v-theme-surface));
  border-bottom: 1.5px solid rgba(15, 23, 42, 0.1);
  padding: 11px 14px;
  white-space: nowrap;
}
.inv-table thead th.text-right { text-align: right; }
.inv-table tbody td {
  padding: 11px 14px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.055);
  vertical-align: middle;
}
.inv-table tbody td.text-right { text-align: right; }
.inv-table tbody tr { transition: background 0.12s ease; }
.inv-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.035); }
.inv-table tbody tr:last-child td { border-bottom: none; }
.inv-row-click { cursor: pointer; }
.inv-row-selected { background: rgba(var(--v-theme-primary), 0.07) !important; }

.col-check { width: 46px; text-align: center; }
.inv-table thead th.col-check { text-align: center; }

.inv-price-cell {
  display: inline-flex;
  flex-direction: column;
  align-items: flex-end;
  line-height: 1.35;
}
.inv-price-cell :deep(.v-icon) { opacity: 0.5; vertical-align: middle; }

/* ─────────────── Status pills ─────────────── */
.status-pill {
  display: inline-flex;
  align-items: center;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  border: 1px solid transparent;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  white-space: nowrap;
}
.status-pill :deep(.v-icon) { margin-right: 4px; }
.status-ok {
  background: rgb(220, 252, 231);
  color: rgb(22, 101, 52);
  border-color: rgb(134, 239, 172);
}
.status-low {
  background: rgb(254, 243, 199);
  color: rgb(120, 53, 15);
  border-color: rgb(252, 211, 77);
}
.status-out {
  background: rgb(254, 226, 226);
  color: rgb(153, 27, 27);
  border-color: rgb(252, 165, 165);
  animation: pulse-out 2s ease-in-out infinite;
}
@keyframes pulse-out {
  0%, 100% { box-shadow: 0 1px 2px rgba(239, 68, 68, 0.2); }
  50% { box-shadow: 0 0 0 4px rgba(239, 68, 68, 0.15); }
}

.row-num { width: 56px; text-align: center; font-variant-numeric: tabular-nums; }
.inv-table thead th.row-num { text-align: center; }

/* ─────────────── Pagination ─────────────── */
.inv-pagination { background: rgba(15, 23, 42, 0.018); }

/* ─────────────── Adjustment deltas ─────────────── */
.qty-delta {
  display: inline-block;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 13px;
}
.qty-pos { background: rgb(220, 252, 231); color: rgb(22, 101, 52); }
.qty-neg { background: rgb(254, 226, 226); color: rgb(153, 27, 27); }

/* ─────────────── Sortable headers ─────────────── */
.sortable-th { cursor: pointer; user-select: none; }
.sortable-th:hover { color: rgb(var(--v-theme-primary)); }
.sort-icon { opacity: 0.35; vertical-align: middle; margin-left: 4px; }
.sort-icon.sort-active { opacity: 1; color: rgb(var(--v-theme-primary)); }
</style>
