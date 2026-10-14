<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-package-variant</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ $t('inventory.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Stock items, categories, units &amp; adjustments</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="currentResource.loading.value" @click="reload">{{ $t('common.refresh') }}</v-btn>
        <v-btn v-if="canEdit && tab === 'stocks'" variant="tonal" color="success" prepend-icon="mdi-microsoft-excel" rounded="lg" class="text-none" to="/inventory/excel">Import / Export</v-btn>
        <v-btn v-if="canEdit && tab === 'stocks'" variant="tonal" color="warning" prepend-icon="mdi-table-edit" rounded="lg" class="text-none" to="/inventory/bulk?mode=edit">Edit mode</v-btn>
        <v-btn v-if="canDelete && tab === 'stocks'" variant="tonal" color="error" prepend-icon="mdi-trash-can" rounded="lg" class="text-none" to="/inventory/bulk?mode=delete">Delete mode</v-btn>
        <v-btn v-if="canEdit" color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" :to="createPaths[tab]">{{ createLabels[tab] }}</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-blue">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cube-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">SKUs</div>
              <div class="text-h6 font-weight-bold">{{ kpis.skus.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-amber">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-alert-circle-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Low / out of stock</div>
              <div class="text-h6 font-weight-bold">{{ kpis.low.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-red">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="40"><v-icon>mdi-clock-alert-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Expiring ≤90d</div>
              <div class="text-h6 font-weight-bold">{{ kpis.expiring.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-green">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cash-multiple</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Retail value</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(kpis.retail) }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card rounded="lg" elevation="0" class="mb-3 pa-1" style="border:1px solid rgba(0,0,0,0.06)">
      <v-tabs v-model="tab" color="primary" density="compact" align-tabs="start" hide-slider>
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value" class="text-none rounded-lg mx-1">
          <v-icon start size="18">{{ t.icon }}</v-icon>
          {{ t.label }}
          <v-chip v-if="t.count != null" size="x-small" class="ml-2" variant="tonal">{{ t.count }}</v-chip>
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Toolbar -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-select
          v-if="tab === 'stocks'"
          v-model="categoryFilter"
          :items="categoryOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-shape" style="min-width: 180px"
        />
        <v-select
          v-if="tab === 'stocks'"
          v-model="classificationFilter"
          :items="classificationOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-label-multiple-outline" style="min-width: 220px"
        >
          <template #item="{ props: ip, item }">
            <v-list-item v-bind="ip" :title="item.raw?.label" :subtitle="item.raw?.description">
              <template #prepend>
                <v-icon size="18" color="primary">mdi-label-multiple-outline</v-icon>
              </template>
            </v-list-item>
          </template>
        </v-select>
        <v-text-field
          v-if="tab === 'stocks'"
          v-model="batchFilter"
          placeholder="Batch #…"
          prepend-inner-icon="mdi-package-variant-closed"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 180px; max-width: 200px"
        />
        <v-select
          v-if="tab === 'stocks'"
          v-model="statusFilter"
          :items="statusOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-filter-variant" style="min-width: 180px"
        />
        <v-select
          v-if="tab === 'stocks' && branchOptions.length > 1"
          v-model="branchFilter"
          :items="branchOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-store-outline" style="min-width: 180px"
          :disabled="branchStore.branchLocked"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filteredItems.length }} of {{ currentItems.length }}</span>
      </div>

      <!-- Date filter chips + search bar -->
      <div class="d-flex flex-wrap align-center mt-2" style="gap:6px">
        <v-icon size="18" class="text-medium-emphasis mr-1">mdi-calendar-filter</v-icon>
        <v-chip
          v-for="df in datePresets" :key="df.value"
          :color="dateFilter === df.value ? 'primary' : undefined"
          :variant="dateFilter === df.value ? 'flat' : 'tonal'"
          size="small" rounded="lg" class="text-none"
          @click="df.value === 'custom' ? (customDateDialog = true) : setDateFilter(df.value)"
        >
          {{ df.label }}
        </v-chip>
        <span v-if="dateFilter === 'custom' && customDateFrom && customDateTo" class="text-caption text-medium-emphasis ml-1">
          {{ customDateFrom }} — {{ customDateTo }}
        </span>
        <v-chip
          v-if="dateFilter !== 'all'"
          size="small" variant="tonal" color="error" rounded="lg"
          prepend-icon="mdi-close" class="text-none"
          @click="setDateFilter('all')"
        >
          Clear
        </v-chip>
        <v-text-field
          v-model="search"
          placeholder="Search by name, brand, generic, strength, barcode…"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="flex: 1; min-width: 200px"
        />
      </div>

      <!-- Custom date range dialog -->
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
              density="compact" variant="outlined" rounded="lg"
              class="mb-3"
            />
            <v-text-field
              v-model="customDateToTemp"
              type="date"
              label="To"
              density="compact" variant="outlined" rounded="lg"
            />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn variant="text" class="text-none" @click="customDateDialog = false">Cancel</v-btn>
            <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :disabled="!customDateFromTemp || !customDateToTemp" @click="applyCustomDate">Apply</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </v-card>

    <!-- Table -->
    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="currentResource.loading.value" color="primary" indeterminate />

      <div v-if="!currentResource.loading.value && !filteredItems.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-inbox-outline</v-icon>
        <div class="text-h6 mt-3">No records found</div>
        <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Get started by adding your first item.' }}</div>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" :to="createPaths[tab]">{{ createLabels[tab] }}</v-btn>
      </div>

      <div v-else class="table-wrap">
        <!-- STOCKS -->
        <table v-if="tab === 'stocks'" class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th class="sortable-th" @click="toggleStockSort('medication_name')">
                Item
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'medication_name' }">{{ stockSortKey === 'medication_name' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}</v-icon>
              </th>
              <th>Generic Name</th>
              <th>Batches</th>
              <th>Category</th>
              <th>Classification</th>
              <th class="text-right">On hand</th>
              <th class="text-right">Reorder</th>
              <th class="text-right">Cost</th>
              <th class="text-right">Price</th>
              <th class="text-right">Retail value</th>
              <th class="sortable-th" @click="toggleStockSort('created_at')">
                Added
                <v-icon size="14" class="sort-icon" :class="{ 'sort-active': stockSortKey === 'created_at' }">{{ stockSortKey === 'created_at' ? (stockSortDir === 'asc' ? 'mdi-arrow-up' : 'mdi-arrow-down') : 'mdi-arrow-up-down' }}</v-icon>
              </th>
              <th>{{ $t('common.status') }}</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id" class="inv-row-click" @click="$router.push(`/inventory/stocks/${row.id}`)">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="primary" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-pill</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.medication_name || row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">
                      <span v-if="row.barcode">{{ row.barcode }}</span>
                      <span v-else-if="row.location_in_store">{{ row.location_in_store }}</span>
                      <span v-else>SKU #{{ row.id }}</span>
                    </div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis">{{ row.generic_name || '—' }}</td>
              <td>
                <div v-if="row.batches &amp;&amp; row.batches.length" class="d-flex flex-wrap" style="gap:4px">
                  <v-chip
                    v-for="b in row.batches.filter(x => x.quantity_remaining > 0)"
                    :key="b.id"
                    size="x-small" variant="tonal" color="primary"
                  >
                    {{ b.batch_number || 'No #' }}
                    <span class="text-medium-emphasis ml-1">×{{ b.quantity_remaining }}</span>
                  </v-chip>
                </div>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td>{{ row.category_name || '—' }}</td>
              <td>
                <v-chip
                  v-if="row.classification_name"
                  size="x-small" variant="tonal"
                  :color="classificationColor(row.classification_name)"
                  prepend-icon="mdi-label-multiple-outline"
                >{{ row.classification_name }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td class="text-right font-weight-medium">{{ Number(row.total_quantity ?? 0).toLocaleString() }} <span class="text-caption text-medium-emphasis">{{ row.unit_abbreviation || '' }}</span><span v-if="row.items_per_unit > 0" class="text-caption text-info d-block">{{ row.items_per_unit }} items/{{ row.unit_abbreviation || row.unit_name || 'unit' }}</span></td>
              <td class="text-right">{{ Number(row.reorder_level ?? 0).toLocaleString() }}</td>
              <td class="text-right">{{ formatMoney(row.cost_price) }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(row.selling_price) }}</td>
              <td class="text-right">{{ formatMoney(Number(row.total_quantity || 0) * Number(row.selling_price || 0)) }}</td>
              <td class="text-caption text-medium-emphasis">{{ row.created_at ? new Date(row.created_at).toLocaleDateString() : '—' }}</td>
              <td>
                <span class="status-pill" :class="`status-${stockStatus(row).key}`">
                  <v-icon size="14">{{ stockStatus(row).icon }}</v-icon>
                  {{ stockStatus(row).label }}
                </span>
              </td>
              <td class="text-right">
                <v-menu offset="4">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="180">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View details" :to="`/inventory/stocks/${row.id}`" />
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit" :to="`/inventory/stocks/${row.id}/edit`" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- CATEGORIES -->
        <table v-else-if="tab === 'categories'" class="inv-table">
          <thead><tr><th class="row-num">#</th><th>Category</th><th>Description</th><th class="text-right">SKUs</th><th class="text-right">Units on hand</th><th class="text-right">Retail value</th><th>Share</th><th class="text-right">{{ $t('common.actions') }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="categoryColor(row.id)" variant="tonal" rounded="lg" size="34"><v-icon size="18">mdi-shape</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ row.id }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width:280px">
                <div class="text-truncate">{{ row.description || '—' }}</div>
              </td>
              <td class="text-right font-weight-medium">{{ countByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByCategory(row.id).toLocaleString() }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(retailByCategory(row.id)) }}</td>
              <td style="min-width:140px">
                <v-progress-linear
                  :model-value="sharePctByCategory(row.id)"
                  :color="categoryColor(row.id)"
                  height="6" rounded
                />
                <div class="text-caption text-medium-emphasis mt-1">{{ sharePctByCategory(row.id) }}%</div>
              </td>
              <td class="text-right">
                <v-menu offset="4">
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
          <thead><tr><th class="row-num">#</th><th>Unit</th><th>Abbreviation</th><th class="text-right">SKUs</th><th class="text-right">Total on hand</th><th class="text-right">{{ $t('common.actions') }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="success" variant="tonal" rounded="lg" size="34"><v-icon size="16">mdi-ruler</v-icon></v-avatar>
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
              <td class="text-right">{{ unitsByUnit(row.id).toLocaleString() }} <span class="text-caption text-medium-emphasis">{{ row.abbreviation || '' }}</span></td>
              <td class="text-right">
                <v-menu offset="4">
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
                  <v-avatar :color="classificationColor(row.name)" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-label-multiple-outline</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">
                      ID #{{ row.id }}
                      <v-chip v-if="row.name === 'Routine'" size="x-small" variant="tonal" color="primary" class="ml-1">Default</v-chip>
                    </div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width:280px">
                <div class="text-truncate">{{ row.description || '—' }}</div>
              </td>
              <td>
                <v-chip :color="row.is_active === false ? 'default' : 'success'" size="x-small" variant="tonal">
                  {{ row.is_active === false ? 'Inactive' : 'Active' }}
                </v-chip>
              </td>
              <td class="text-right font-weight-medium">{{ (row.stock_count ?? countByClassification(row.id)).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByClassification(row.id).toLocaleString() }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(retailByClassification(row.id)) }}</td>
              <td class="text-right">
                <v-menu offset="4">
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
              <td colspan="8" class="text-center text-medium-emphasis py-6">No classifications yet. "Routine" is created automatically.</td>
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
                  <v-avatar :color="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'success' : 'error'" variant="tonal" rounded="lg" size="32">
                    <v-icon size="16">{{ (row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'mdi-arrow-up-bold' : 'mdi-arrow-down-bold' }}</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.stock_name || '—' }}</div>
                    <div v-if="row.batch" class="text-caption text-medium-emphasis">Batch #{{ row.batch }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" :color="reasonColor(row.reason)" variant="tonal" :prepend-icon="reasonIcon(row.reason)">{{ reasonLabel(row.reason) }}</v-chip>
              </td>
              <td class="text-right">
                <span class="qty-delta" :class="(row.quantity_change ?? row.quantity ?? 0) >= 0 ? 'qty-pos' : 'qty-neg'">
                  {{ (row.quantity_change ?? row.quantity ?? 0) > 0 ? '+' : '' }}{{ Number(row.quantity_change ?? row.quantity ?? 0).toLocaleString() }}
                </span>
              </td>
              <td class="text-medium-emphasis" style="max-width:240px">
                <div class="text-truncate">{{ row.notes || row.reason_text || '—' }}</div>
              </td>
              <td class="text-medium-emphasis">{{ row.adjusted_by_name || 'System' }}</td>
              <td class="text-medium-emphasis">{{ formatDateTime(row.created_at) }}</td>
              <td class="text-right">
                <v-menu offset="4">
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

      <!-- Pagination -->
      <div v-if="filteredItems.length" class="d-flex flex-wrap align-center pa-3 pagination-bar" style="gap:12px">
        <span class="text-caption text-medium-emphasis">
          Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filteredItems.length }}</strong>
        </span>
        <v-spacer />
        <div class="d-flex align-center" style="gap:6px">
          <span class="text-caption text-medium-emphasis">Rows per page</span>
          <v-select
            v-model="pageSize"
            :items="pageSizeOptions"
            density="compact" variant="outlined" rounded="lg" hide-details
            style="width: 92px"
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
    </v-card>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, watch, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatMoney, formatDateTime } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const branchStore = useBranchStore()
const auth = useAuthStore()

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

const tabs = computed(() => [
  { value: 'stocks', label: 'Stocks', icon: 'mdi-pill', count: stocks.items.value?.length },
  { value: 'categories', label: 'Categories', icon: 'mdi-shape', count: categoriesRes.items.value?.length },
  { value: 'classifications', label: 'Classifications', icon: 'mdi-label-multiple-outline', count: classificationsRes.items.value?.length },
  { value: 'units', label: 'Units', icon: 'mdi-ruler', count: units.items.value?.length },
  { value: 'adjustments', label: 'Adjustments', icon: 'mdi-tune-vertical', count: adjustments.items.value?.length }
])

// --- KPIs (always reflect stocks) ---
function stockStatus(s) {
  const qty = Number(s.total_quantity ?? s.quantity ?? 0)
  const reorder = Number(s.reorder_level ?? 0)
  if (qty <= 0) return { key: 'out', label: 'Out of stock', icon: 'mdi-alert-octagon' }
  if (qty <= reorder) return { key: 'low', label: 'Low', icon: 'mdi-alert' }
  return { key: 'ok', label: 'In stock', icon: 'mdi-check-circle' }
}

const kpis = computed(() => {
  const all = stocks.items.value || []
  const skus = all.length
  const low = all.filter(s => stockStatus(s).key !== 'ok').length
  const horizon = Date.now() + 90 * 86400000
  const expiring = all.reduce((acc, s) => {
    const batches = s.batches || []
    if (batches.some(b => b.expiry_date && new Date(b.expiry_date).getTime() <= horizon)) return acc + 1
    if (s.expiry_date && new Date(s.expiry_date).getTime() <= horizon) return acc + 1
    return acc
  }, 0)
  const retail = all.reduce((acc, s) => acc + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
  return { skus, low, expiring, retail }
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
const statusOptions = [
  { label: 'All status', value: 'all' },
  { label: 'In stock', value: 'ok' },
  { label: 'Low stock', value: 'low' },
  { label: 'Out of stock', value: 'out' }
]

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

// --- Stock sorting ---
const stockSortKey = ref('created_at')
const stockSortDir = ref('desc')
function toggleStockSort(key) {
  if (stockSortKey.value === key) {
    stockSortDir.value = stockSortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    stockSortKey.value = key
    stockSortDir.value = 'asc'
  }
}
const sortedStocks = computed(() => {
  if (tab.value !== 'stocks') return filteredItems.value
  const arr = filteredItems.value.slice()
  const key = stockSortKey.value
  const dir = stockSortDir.value === 'asc' ? 1 : -1
  arr.sort((a, b) => {
    let va = a[key], vb = b[key]
    if (key === 'created_at') {
      va = va ? new Date(va).getTime() : 0
      vb = vb ? new Date(vb).getTime() : 0
    } else {
      va = (va || '').toString().toLowerCase()
      vb = (vb || '').toString().toLowerCase()
    }
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

watch([tab, search, batchFilter, categoryFilter, classificationFilter, statusFilter, branchFilter, dateFilter, customDateFrom, customDateTo, pageSize], () => { page.value = 1 })

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
  other:              { label: 'Other',              color: 'default', icon: 'mdi-dots-horizontal' },
}
function reasonLabel(r) { return _reasonMeta[r]?.label || (r ? r.replace(/_/g, ' ') : '\u2014') }
function reasonColor(r) { return _reasonMeta[r]?.color || 'default' }
function reasonIcon(r)  { return _reasonMeta[r]?.icon  || 'mdi-tag' }

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
.kpi-card { border: 1px solid rgba(0,0,0,0.06); }
.kpi-blue { background: linear-gradient(135deg, rgba(59,130,246,0.06), rgba(59,130,246,0.01)); }
.kpi-amber { background: linear-gradient(135deg, rgba(245,158,11,0.07), rgba(245,158,11,0.01)); }
.kpi-red { background: linear-gradient(135deg, rgba(239,68,68,0.07), rgba(239,68,68,0.01)); }
.kpi-green { background: linear-gradient(135deg, rgba(34,197,94,0.07), rgba(34,197,94,0.01)); }

.table-wrap { overflow-x: auto; }
.inv-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.inv-table thead th {
  text-align: left;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgb(var(--v-theme-on-surface));
  background: rgba(var(--v-theme-primary), 0.08);
  border-bottom: 2px solid rgba(var(--v-theme-primary), 0.25);
  padding: 10px 14px;
  white-space: nowrap;
}
.inv-table thead th.text-right { text-align: right; }
.inv-table tbody td { padding: 10px 14px; border-bottom: 1px solid rgba(0,0,0,0.05); vertical-align: middle; }
.inv-table tbody td.text-right { text-align: right; }
.inv-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.04); }
.inv-row-click { cursor: pointer; }

.status-pill {
  display: inline-flex; align-items: center;
  padding: 6px 12px; border-radius: 999px;
  font-size: 12px; font-weight: 700;
  letter-spacing: 0.04em; text-transform: uppercase;
  border: 1px solid transparent;
  box-shadow: 0 1px 2px rgba(0,0,0,0.06);
  white-space: nowrap;
}
.status-pill .v-icon { margin-right: 4px; font-size: 14px !important; }

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
  0%, 100% { box-shadow: 0 1px 2px rgba(239,68,68,0.2); }
  50% { box-shadow: 0 0 0 4px rgba(239,68,68,0.15); }
}

.row-num { width: 56px; text-align: center; font-variant-numeric: tabular-nums; }
.inv-table thead th.row-num { text-align: center; }
.pagination-bar { border-top: 1px solid rgba(0,0,0,0.06); background: rgba(0,0,0,0.015); }

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

.sortable-th { cursor: pointer; user-select: none; }
.sortable-th:hover { background: rgba(var(--v-theme-primary), 0.14); }
.sort-icon { opacity: 0.35; vertical-align: middle; margin-left: 4px; }
.sort-icon.sort-active { opacity: 1; color: rgb(var(--v-theme-primary)); }
</style>
