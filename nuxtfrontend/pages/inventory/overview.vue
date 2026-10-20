<template>
  <v-container fluid class="pa-3 pa-md-5 iov-page">

    <!-- ═══════════════ HERO ═══════════════
         Brand gradient from the tenant palette (same CSS-var bridge as the
         inventory list / stock detail / RFQ screens) so every IMS surface
         reads as one product. -->
    <div class="iov-hero mb-4" :style="heroTheme">
      <span class="iov-hero-glow" />
      <span class="iov-hero-glow iov-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3 iov-hero-top">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="iov-hero-icon">
            <v-icon size="30">mdi-chart-box-outline</v-icon>
          </div>
          <div style="min-width:0">
            <div class="iov-hero-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              INVENTORY · OVERVIEW
            </div>
            <h1 class="iov-hero-title">Inventory overview</h1>
            <div class="iov-hero-sub">
              Stock, valuation, expiry, procurement &amp; fulfilment in one view
              <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="iov-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="refresh"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none iov-hero-btn-glass"
            prepend-icon="mdi-download-outline"
            title="Download a CSV snapshot of this overview"
            :disabled="loading"
            @click="exportSnapshot"
          >Snapshot</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none iov-hero-btn-glass"
            prepend-icon="mdi-clipboard-text-search-outline"
            :to="p('/inventory/stock-movements')"
          >Movement ledger</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none iov-hero-btn-strong"
            prepend-icon="mdi-package-variant"
            :to="p('/inventory')"
          >Stock list</v-btn>
        </div>
      </div>

      <div class="iov-hero-foot d-flex flex-wrap align-center" style="gap:8px">
        <span class="iov-hero-chip">
          <v-icon size="14">mdi-package-variant-closed</v-icon>
          {{ num(overview.stock.total_items) }} SKUs
        </span>
        <span class="iov-hero-chip">
          <v-icon size="14">mdi-scale-balance</v-icon>
          {{ num(overview.stock.units_on_hand) }} units on hand
        </span>
        <span class="iov-hero-chip">
          <v-icon size="14">mdi-cash-multiple</v-icon>
          {{ compactMoney(analytics.total_cost_value) }} at cost
        </span>
        <span class="iov-hero-chip" :class="healthChipClass">
          <v-icon size="14">{{ healthIcon }}</v-icon>
          {{ healthPct }}% healthy
        </span>
        <span v-if="overview.expiry.expiring_30" class="iov-hero-chip iov-hero-chip-warn">
          <v-icon size="14">mdi-clock-alert-outline</v-icon>
          {{ overview.expiry.expiring_30 }} expiring ≤30d
        </span>
        <span v-if="overview.stock.out_of_stock" class="iov-hero-chip iov-hero-chip-alert">
          <v-icon size="14">mdi-package-variant-remove</v-icon>
          {{ overview.stock.out_of_stock }} out of stock
        </span>
      </div>
    </div>

    <!-- ═══════════════ RANGE TOOLBAR ═══════════════ -->
    <v-card rounded="lg" elevation="0" class="iov-card mb-3">
      <div class="pa-3 d-flex flex-wrap align-center" style="gap:12px">
        <div class="d-flex align-center" style="gap:8px">
          <div class="iov-toolbar-icon"><v-icon size="16">mdi-calendar-range</v-icon></div>
          <div>
            <div class="iov-toolbar-label">Reporting period</div>
            <div class="iov-toolbar-sub">{{ rangeLabel }}</div>
          </div>
        </div>

        <v-chip-group
          v-model="datePreset"
          mandatory
          selected-class="text-primary"
          class="iov-date-chips"
          @update:model-value="onPresetSelect"
        >
          <v-chip v-for="pr in presets" :key="pr.value" :value="pr.value" size="small" variant="tonal" class="text-none">
            {{ pr.label }}
          </v-chip>
        </v-chip-group>

        <v-spacer />

        <div class="d-flex align-center" style="gap:8px">
          <v-text-field
            v-model="dateFrom"
            type="date"
            label="From"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            prepend-inner-icon="mdi-calendar-start"
            class="iov-date-field"
            @update:model-value="onCustomChange"
          />
          <v-text-field
            v-model="dateTo"
            type="date"
            label="To"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            prepend-inner-icon="mdi-calendar-end"
            class="iov-date-field"
            @update:model-value="onCustomChange"
          />
          <v-btn
            v-if="hasActiveRange"
            size="small"
            variant="text"
            color="error"
            class="text-none"
            prepend-icon="mdi-close"
            @click="clearRange"
          >Clear</v-btn>
        </div>
      </div>
    </v-card>

    <!-- ═══════════════ KPI STRIP ═══════════════
         Six focused, linkable metrics tone-railed by currentColor. -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="4" xl="2">
        <component
          :is="linkOr(k.to)"
          :to="k.to || undefined"
          class="iov-kpi h-100"
          :class="[`iov-kpi-t-${k.tone}`, k.to ? 'iov-kpi-link' : '']"
        >
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="iov-kpi-icon">
              <v-icon size="18">{{ k.icon }}</v-icon>
            </div>
            <v-chip
              v-if="k.chip"
              size="x-small"
              :color="k.chipColor || k.tone"
              variant="tonal"
              class="font-weight-bold"
            >{{ k.chip }}</v-chip>
          </div>
          <div class="iov-kpi-label">{{ k.title }}</div>
          <div class="iov-kpi-value">{{ k.value }}</div>
          <div v-if="k.hint" class="iov-kpi-foot">{{ k.hint }}</div>
        </component>
      </v-col>
    </v-row>

    <!-- ═══════════════ VALUATION + FLOW ═══════════════
         The two questions the KPI strip can't answer: how much capital is on
         the shelves (and what margin it carries), and how stock is physically
         moving through the period. -->
    <v-row dense class="mt-1 mb-2">
      <v-col cols="12" lg="5">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="iov-panel-icon" style="--panel-tone:#0d9488">
                <v-icon size="17">mdi-cash-multiple</v-icon>
              </div>
              <div>
                <h3 class="iov-panel-title">Inventory valuation</h3>
                <div class="text-caption text-medium-emphasis">Capital at cost vs realisable retail</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" :color="marginPct >= 25 ? 'success' : 'warning'" class="font-weight-bold">
              {{ marginPct }}% margin
            </v-chip>
          </div>

          <div class="iov-val-grid">
            <div class="iov-val-tile">
              <div class="iov-val-label">At cost</div>
              <div class="iov-val-value">{{ formatMoney(analytics.total_cost_value ?? 0) }}</div>
              <div class="iov-val-hint">capital tied up</div>
            </div>
            <div class="iov-val-tile">
              <div class="iov-val-label">At retail</div>
              <div class="iov-val-value">{{ formatMoney(analytics.total_retail_value ?? 0) }}</div>
              <div class="iov-val-hint">if all stock sells</div>
            </div>
            <div class="iov-val-tile iov-val-tile-good">
              <div class="iov-val-label">Potential profit</div>
              <div class="iov-val-value">{{ formatMoney(analytics.potential_profit ?? 0) }}</div>
              <div class="iov-val-hint">gross, before costs</div>
            </div>
          </div>

          <div class="mt-3">
            <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
              <span>Cost share</span>
              <span>{{ 100 - marginPct }}% · {{ marginPct }}% margin</span>
            </div>
            <div class="iov-split-bar">
              <span class="iov-split-cost" :style="{ width: (100 - marginPct) + '%' }" />
              <span class="iov-split-margin" :style="{ width: marginPct + '%' }" />
            </div>
          </div>

          <v-divider class="my-3" />
          <div class="d-flex align-center" style="gap:8px">
            <v-icon size="16" color="teal">mdi-information-outline</v-icon>
            <div class="text-caption" style="line-height: 1.45">{{ valuationInsight }}</div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="7">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 iov-panel">
          <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-2">
            <div class="d-flex align-center" style="gap:10px">
              <div class="iov-panel-icon" style="--panel-tone:#0284c7">
                <v-icon size="17">mdi-swap-vertical-bold</v-icon>
              </div>
              <div>
                <h3 class="iov-panel-title">Stock flow</h3>
                <div class="text-caption text-medium-emphasis">Inflow vs outflow across the period</div>
              </div>
            </div>
            <div class="d-flex align-center" style="gap:6px">
              <div class="iov-flowstat iov-flowstat-in">
                <span class="iov-flowstat-label">In</span>
                <span class="iov-flowstat-value">{{ num(flowKpis.total_in) }}</span>
              </div>
              <div class="iov-flowstat iov-flowstat-out">
                <span class="iov-flowstat-label">Out</span>
                <span class="iov-flowstat-value">{{ num(flowKpis.total_out) }}</span>
              </div>
              <div class="iov-flowstat iov-flowstat-net">
                <span class="iov-flowstat-label">Net</span>
                <span class="iov-flowstat-value">{{ netChange > 0 ? '+' : '' }}{{ num(netChange) }}</span>
              </div>
            </div>
          </div>

          <EmptyState
            v-if="!inflowValues.length"
            icon="mdi-chart-timeline-variant"
            title="No movement in this period"
            message="Receipts, sales, adjustments and transfers will appear here once recorded."
          />
          <template v-else>
            <div class="d-flex align-center ga-4 mb-1">
              <div class="d-flex align-center">
                <span class="iov-legend-dot" style="background:#22c55e" />
                <span class="text-caption text-medium-emphasis ml-1">Inflow</span>
              </div>
              <div class="d-flex align-center">
                <span class="iov-legend-dot" style="background:#ef4444" />
                <span class="text-caption text-medium-emphasis ml-1">Outflow</span>
              </div>
              <span class="text-caption text-medium-emphasis ml-auto" style="font-size: 11px">
                {{ num(flowKpis.count) }} postings · {{ trendLabels.length }} active day{{ trendLabels.length === 1 ? '' : 's' }}
              </span>
            </div>
            <StockFlowChart
              :inflow="inflowValues"
              :outflow="outflowValues"
              :labels="trendLabels"
              :height="196"
            />
          </template>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ OPERATIONAL INSIGHTS ═══════════════
         Four derived signals with the destination that acts on each. Reads as
         an advisory band rather than another row of counts. -->
    <div class="iov-insights mb-2">
      <div class="iov-insights-head">
        <v-icon size="16">mdi-lightbulb-on-outline</v-icon>
        <span>Operational insights</span>
        <span class="iov-insights-note">derived from live stock, expiry and fulfilment data</span>
      </div>
      <div class="iov-insights-grid">
        <component
          :is="linkOr(i.to)"
          :to="i.to || undefined"
          v-for="i in insights"
          :key="i.label"
          class="iov-insight"
          :class="{ 'iov-insight-link': !!i.to }"
          :style="{ '--insight-tone': i.tone }"
        >
          <div class="iov-insight-icon"><v-icon size="17">{{ i.icon }}</v-icon></div>
          <div style="min-width:0">
            <div class="iov-insight-label">{{ i.label }}</div>
            <div class="iov-insight-value">{{ i.value }}</div>
            <div class="iov-insight-hint">{{ i.hint }}</div>
          </div>
        </component>
      </div>
    </div>

    <!-- ═══════════════ HEALTH + EXPIRY + FULFILMENT ═══════════════ -->
    <v-row dense class="mt-1">
      <!-- Stock health -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center">
              <div class="iov-panel-icon" style="--panel-tone:#2563eb">
                <v-icon size="18">mdi-package-variant-closed</v-icon>
              </div>
              <div>
                <div class="iov-panel-title">Stock health</div>
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
                <div class="text-h5 font-weight-bold">{{ overview.stock.total_items ?? 0 }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>

          <div v-for="h in healthLegend" :key="h.label" class="iov-legend">
            <span class="iov-legend-dot" :style="{ background: h.color }" />
            <span class="text-body-2 flex-grow-1">{{ h.label }}</span>
            <span class="text-body-2 font-weight-bold">{{ h.count }}</span>
            <span class="text-caption text-medium-emphasis iov-legend-pct">{{ h.pct }}%</span>
          </div>

          <div class="iov-metric-row mt-2">
            <span class="text-body-2 text-medium-emphasis">Units on hand</span>
            <span class="text-body-2 font-weight-bold">{{ (overview.stock.units_on_hand ?? 0).toLocaleString() }}</span>
          </div>

          <v-btn
            block variant="tonal" color="primary" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-package-variant" :to="p('/inventory')"
          >Manage stock items</v-btn>
        </v-card>
      </v-col>

      <!-- Expiry pipeline -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#ea580c">
              <v-icon size="18">mdi-clock-alert-outline</v-icon>
            </div>
            <div>
              <div class="iov-panel-title">Expiry pipeline</div>
              <div class="text-caption text-medium-emphasis">Batches expiring or already expired</div>
            </div>
          </div>

          <!-- Expiry runway: relative volumes across the three windows. -->
          <div class="iov-runway mb-2">
            <div v-for="r in expiryRunway" :key="r.key" class="iov-runway-col">
              <span class="iov-runway-value">{{ r.count }}</span>
              <div class="iov-runway-track">
                <span class="iov-runway-bar" :class="`iov-runway-${r.key}`" :style="{ height: Math.max(6, r.pct) + '%' }" />
              </div>
              <span class="iov-runway-label">{{ r.label }}</span>
            </div>
          </div>

          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/inventory') + '?batchFilter=expiring'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#ea580c"><v-icon size="18">mdi-clock-alert</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.expiry.expiring_30 ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expiring within 30 days</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
            <v-divider inset />
            <v-list-item class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#f59e0b"><v-icon size="18">mdi-calendar-alert</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.expiry.expiring_90 ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expiring within 90 days</v-list-item-subtitle>
            </v-list-item>
            <v-divider inset />
            <v-list-item class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#ef4444"><v-icon size="18">mdi-alert-octagon</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6 text-error">{{ overview.expiry.expired ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>Expired batches</v-list-item-subtitle>
            </v-list-item>
          </v-list>

          <v-btn
            block variant="tonal" color="deep-orange" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-alert" :to="p('/alerts')"
          >Open stock alerts</v-btn>
        </v-card>
      </v-col>

      <!-- Outbound fulfilment -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#4f46e5">
              <v-icon size="18">mdi-truck-fast</v-icon>
            </div>
            <div>
              <div class="iov-panel-title">Outbound fulfilment</div>
              <div class="text-caption text-medium-emphasis">Pipeline of pending deliveries</div>
            </div>
          </div>

          <div v-if="fulfilmentTotal" class="iov-fulfil-bar mb-3">
            <span class="iov-fulfil-pack" :style="{ width: (fulfilmentShare.pack) + '%' }" />
            <span class="iov-fulfil-ship" :style="{ width: (fulfilmentShare.ship) + '%' }" />
          </div>

          <v-list density="comfortable" class="bg-transparent py-0">
            <v-list-item :to="p('/deliveries') + '?status=to_be_packed'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#14b8a6"><v-icon size="18">mdi-package-variant-closed</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.deliveries.to_be_packed ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>To be packed</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
            <v-divider inset />
            <v-list-item :to="p('/deliveries') + '?status=to_be_shipped'" class="iov-list-item">
              <template #prepend>
                <div class="iov-list-icon" style="--tone:#0891b2"><v-icon size="18">mdi-package-up</v-icon></div>
              </template>
              <v-list-item-title class="font-weight-bold text-h6">{{ overview.deliveries.to_be_shipped ?? 0 }}</v-list-item-title>
              <v-list-item-subtitle>To be shipped / in transit</v-list-item-subtitle>
              <template #append><v-icon size="18">mdi-chevron-right</v-icon></template>
            </v-list-item>
          </v-list>

          <v-btn
            block variant="tonal" color="indigo" rounded="lg" class="text-none mt-3"
            prepend-icon="mdi-truck-outline" :to="p('/deliveries')"
          >Manage deliveries</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ PROCUREMENT + SALES ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#16a34a">
              <v-icon size="18">mdi-cart-arrow-down</v-icon>
            </div>
            <div>
              <div class="iov-panel-title">Inbound (Procurement)</div>
              <div class="text-caption text-medium-emphasis">Items received and open purchase orders</div>
            </div>
          </div>

          <div class="iov-mini-grid">
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Items received</div>
              <div class="text-h5 font-weight-bold text-success">{{ (overview.procurement.items_received ?? 0).toLocaleString() }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Goods received notes</div>
              <div class="text-h5 font-weight-bold">{{ overview.procurement.received_grns ?? 0 }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Open POs</div>
              <div class="text-h5 font-weight-bold text-warning">{{ overview.procurement.open_purchase_orders ?? 0 }}</div>
            </div>
          </div>

          <v-btn
            block variant="tonal" color="success" rounded="lg" class="text-none mt-4"
            prepend-icon="mdi-cart" :to="p('/purchase-orders')"
          >Purchase orders</v-btn>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center mb-3">
            <div class="iov-panel-icon" style="--panel-tone:#9333ea">
              <v-icon size="18">mdi-point-of-sale</v-icon>
            </div>
            <div>
              <div class="iov-panel-title">Sales (Outbound)</div>
              <div class="text-caption text-medium-emphasis">Units sold and revenue in period</div>
            </div>
          </div>

          <div class="iov-mini-grid">
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Units sold</div>
              <div class="text-h5 font-weight-bold">{{ (overview.sales.units_sold ?? 0).toLocaleString() }}</div>
            </div>
            <div class="iov-mini-tile">
              <div class="text-caption text-medium-emphasis">Revenue</div>
              <div class="text-h5 font-weight-bold text-primary">{{ formatMoney(overview.sales.revenue ?? 0) }}</div>
            </div>
          </div>

          <div v-if="(overview.sales.recent || []).length" class="mt-4">
            <div class="text-caption text-medium-emphasis mb-2">Recent completed sales</div>
            <v-table density="compact" class="iov-table">
              <thead>
                <tr>
                  <th>Transaction</th>
                  <th>Customer</th>
                  <th class="text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="t in overview.sales.recent" :key="t.transaction_number">
                  <td class="text-caption font-weight-medium">{{ t.transaction_number }}</td>
                  <td class="text-caption text-medium-emphasis">{{ t.customer_name }}</td>
                  <td class="text-caption text-right font-weight-medium">{{ formatMoney(t.total) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>

          <v-btn
            block variant="tonal" color="purple" rounded="lg" class="text-none mt-4"
            prepend-icon="mdi-receipt-text-plus" :to="p('/pos/history')"
          >Sales history</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ TOP MOVING + DEAD STOCK ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="iov-panel-icon" style="--panel-tone:#2563eb">
                <v-icon size="17">mdi-trending-up</v-icon>
              </div>
              <div>
                <h3 class="iov-panel-title">Top moving items</h3>
                <div class="text-caption text-medium-emphasis">Best sellers in the selected period</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">
              {{ overview.top_moving.length ?? 0 }}
            </v-chip>
          </div>

          <EmptyState
            v-if="!overview.top_moving.length"
            icon="mdi-trending-up" title="No movement yet"
            message="Items sold in the selected period will appear here."
          />

          <div v-else>
            <div v-for="(m, i) in overview.top_moving" :key="m.stock_id" class="iov-rankrow">
              <div class="d-flex align-center justify-space-between mb-1" style="gap:8px">
                <div class="d-flex align-center" style="gap:8px; min-width:0">
                  <span class="iov-rank">{{ i + 1 }}</span>
                  <span class="text-body-2 text-truncate">{{ m.name }}</span>
                </div>
                <div class="d-flex align-center" style="gap:10px">
                  <span class="iov-nowrap text-caption text-medium-emphasis">{{ num(m.qty) }} {{ m.unit }}</span>
                  <span class="iov-nowrap text-body-2 font-weight-bold">{{ formatMoney(m.revenue) }}</span>
                </div>
              </div>
              <div class="iov-bar-track">
                <span :style="{ width: topMovingShare(m) + '%' }" />
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="iov-panel-icon" style="--panel-tone:#64748b">
                <v-icon size="17">mdi-package-off</v-icon>
              </div>
              <div>
                <h3 class="iov-panel-title">Dead stock</h3>
                <div class="text-caption text-medium-emphasis">On hand with no sale in the last 90 days</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="grey" class="font-weight-bold">
              {{ overview.dead_stock.length ?? 0 }}
            </v-chip>
          </div>

          <EmptyState
            v-if="!overview.dead_stock.length"
            icon="mdi-package-check" title="No dead stock"
            message="Every item on hand has sold within the last 90 days."
          />

          <div v-else class="d-flex flex-column" style="gap:2px">
            <component
              :is="linkOr(`/ims/inventory/stocks/${d.stock_id}/edit`)"
              :to="p(`/inventory/stocks/${d.stock_id}/edit`)"
              v-for="d in overview.dead_stock"
              :key="d.stock_id"
              class="iov-dead-row"
            >
              <span class="iov-idle-dot" :class="idleTone(d).cls" />
              <div style="min-width:0; flex:1">
                <div class="text-body-2 text-truncate">{{ d.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ num(d.qty) }} {{ d.unit || 'units' }} idle</div>
              </div>
              <v-chip size="x-small" :color="idleTone(d).color" variant="tonal" class="font-weight-bold">
                {{ d.days_idle == null ? 'never sold' : `${num(d.days_idle)}d` }}
              </v-chip>
            </component>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ RECENT MOVEMENTS ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 iov-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="iov-panel-icon" style="--panel-tone:#0284c7">
                <v-icon size="17">mdi-swap-vertical-bold</v-icon>
              </div>
              <div>
                <h3 class="iov-panel-title">Recent stock movements</h3>
                <div class="text-caption text-medium-emphasis">Last 12 receipts, sales, adjustments and transfers</div>
              </div>
            </div>
            <v-btn variant="text" size="small" color="primary" class="text-none" :to="p('/inventory/stock-movements')" append-icon="mdi-arrow-right">
              Full ledger
            </v-btn>
          </div>

          <EmptyState
            v-if="!movements.length && !movementsLoading"
            icon="mdi-swap-vertical" title="No movements recorded"
            message="Receipts, sales, adjustments and transfers will appear here."
          />
          <v-table v-else density="compact" :loading="movementsLoading" class="iov-table">
            <thead>
              <tr>
                <th>Item</th>
                <th>Source</th>
                <th class="text-right">Qty Change</th>
                <th class="text-right">On Hand</th>
                <th>Reference</th>
                <th>When</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in movements.slice(0, 12)" :key="m.id">
                <td class="text-truncate" style="max-width: 200px">
                  <span class="font-weight-medium">{{ m.stock_name }}</span>
                  <div v-if="m.batch_number" class="text-caption text-medium-emphasis">Batch {{ m.batch_number }}</div>
                </td>
                <td>
                  <v-chip size="x-small" :color="sourceMeta(m).color" variant="tonal">
                    <v-icon start size="12">{{ sourceMeta(m).icon }}</v-icon>
                    {{ m.source }}
                  </v-chip>
                </td>
                <td class="text-right font-weight-medium" :class="m.direction === 'inflow' ? 'text-success' : m.direction === 'outflow' ? 'text-error' : 'text-info'">
                  {{ m.direction === 'outflow' ? '' : '+' }}{{ m.quantity_change }}
                </td>
                <td class="text-right text-body-2">{{ m.qty_after ?? '—' }}</td>
                <td class="text-caption text-medium-emphasis">{{ m.reference || '—' }}</td>
                <td class="text-caption text-medium-emphasis">{{ formatRelative(m.timestamp) }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-card>
      </v-col>
    </v-row>

  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { NuxtLink } from '#components'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()

// Reuse the same NuxtLink import for linkable KPI cards; falls back to a plain
// div when no `to` is set so the code paths below stay declarative.
function linkOr(to) {
  return to ? NuxtLink : 'div'
}

// Pharmacy tenants reuse this page under /pharmacy, inventory/warehouse
// tenants under /ims — the sub-paths are identical after the prefix.
const { isInventory } = useTenantEndpoints()
const base = computed(() => isInventory.value ? '/ims' : '/pharmacy')
// Build a tenant-namespaced path from a suffix (e.g. '/inventory').
const p = (suffix) => `${base.value}${suffix}`

// Tenant palette → CSS custom properties for the hero (same bridge used by the
// inventory list, stock detail and RFQ screens).
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

const loading = ref(false)
const movementsLoading = ref(false)

const overview = reactive({
  stock: {},
  expiry: {},
  deliveries: {},
  procurement: {},
  sales: {},
  top_moving: [],
  dead_stock: [],
})

// Valuation payload (`/inventory/analytics/`) and the movement report
// (`/inventory/stock-movements/`) power the new panels. Both were already
// fetched by the dashboard, so the overview reuses the same contracts.
const analytics = reactive({
  total_cost_value: 0,
  total_retail_value: 0,
  potential_profit: 0,
})
const flowKpis = reactive({ total_in: 0, total_out: 0, total_transfer: 0, net_change: 0, count: 0 })
const trendLabels = ref([])
const inflowValues = ref([])
const outflowValues = ref([])

const movements = ref([])

const SOURCE_META = {
  'POS Sale': { color: 'success', icon: 'mdi-point-of-sale' },
  'Dispensing': { color: 'teal', icon: 'mdi-pill' },
  'Dispense Return': { color: 'orange', icon: 'mdi-undo' },
  'Stock Adjustment': { color: 'warning', icon: 'mdi-tune' },
  'Branch Transfer': { color: 'info', icon: 'mdi-truck-delivery-outline' },
}

function sourceMeta(m) {
  return SOURCE_META[m.source] || { color: 'grey', icon: 'mdi-swap-vertical' }
}

function formatRelative(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (isNaN(d)) return v
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

// ── Date filters ───────────────────────────────────────────────────────
const datePreset = ref('all')
const dateFrom = ref(null)
const dateTo = ref(null)

const presets = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'This month', value: 'month' },
  { label: 'Custom', value: 'custom' },
]

const hasActiveRange = computed(() => !!(dateFrom.value || dateTo.value))

function iso(d) {
  return d.toISOString().slice(0, 10)
}

function applyPreset() {
  const now = new Date()
  switch (datePreset.value) {
    case 'today':
      dateFrom.value = iso(now)
      dateTo.value = iso(now)
      break
    case '7d': {
      const d = new Date(now.getTime() - 6 * 86400000)
      dateFrom.value = iso(d)
      dateTo.value = iso(now)
      break
    }
    case '30d': {
      const d = new Date(now.getTime() - 29 * 86400000)
      dateFrom.value = iso(d)
      dateTo.value = iso(now)
      break
    }
    case 'month': {
      const first = new Date(now.getFullYear(), now.getMonth(), 1)
      dateFrom.value = iso(first)
      dateTo.value = iso(now)
      break
    }
    case 'custom':
      break
    default:
      dateFrom.value = null
      dateTo.value = null
  }
  load()
}

function onCustomChange() {
  datePreset.value = 'custom'
}

/**
 * `v-chip-group` without `mandatory` can emit null when the active chip is
 * clicked again; guard the value and fall back to "all time".
 */
function onPresetSelect(value) {
  if (!value) {
    datePreset.value = 'all'
    dateFrom.value = null
    dateTo.value = null
  }
  applyPreset()
}

function clearRange() {
  datePreset.value = 'all'
  dateFrom.value = null
  dateTo.value = null
  load()
}

// ── Derived health signals ──────────────────────────────────────────────
const healthCount = computed(() =>
  (overview.stock.healthy ?? 0)
  + (overview.stock.low_stock ?? 0)
  + (overview.stock.out_of_stock ?? 0)
)

const healthSegments = computed(() => [
  { value: overview.stock.healthy ?? 0, color: '#22c55e', label: 'Healthy' },
  { value: overview.stock.low_stock ?? 0, color: '#f59e0b', label: 'Low' },
  { value: overview.stock.out_of_stock ?? 0, color: '#ef4444', label: 'Out' },
])

const healthPct = computed(() => {
  const total = overview.stock.total_items ?? 0
  return total ? Math.round(((overview.stock.healthy ?? 0) / total) * 100) : 0
})

const healthChipColor = computed(() =>
  healthPct.value >= 80 ? 'success' : healthPct.value >= 50 ? 'warning' : 'error'
)

/** Hero chip tone — red wash when availability drops below the 80% mark. */
const healthChipClass = computed(() => (healthPct.value >= 80 ? '' : 'iov-hero-chip-alert'))
const healthIcon = computed(() =>
  healthPct.value >= 80 ? 'mdi-check-circle-outline' : healthPct.value >= 50 ? 'mdi-alert-outline' : 'mdi-alert-octagon-outline')

// ── Valuation ───────────────────────────────────────────────────────────
const marginPct = computed(() => {
  const retail = Number(analytics.total_retail_value) || 0
  const profit = Number(analytics.potential_profit) || 0
  if (!retail) return 0
  return Math.round((profit / retail) * 100)
})

const valuationInsight = computed(() => {
  const cost = Number(analytics.total_cost_value) || 0
  if (!cost) return 'No valued stock on hand yet — add cost and selling prices to stock items to unlock valuation insight.'
  const expiring = Number(overview.expiry.expiring_90) || 0
  if (expiring) {
    return `${num(expiring)} batch${expiring === 1 ? '' : 'es'} expire within 90 days. Moving that stock first protects ${compactMoney(
      (cost * expiring) / Math.max(1, Number(overview.stock.total_items) || 1)
    )} of the capital currently tied up.`
  }
  return `Every on-hand item is priced, giving a ${marginPct.value}% gross margin at retail. No dated batches are at risk in the next 90 days.`
})

// ── Flow ────────────────────────────────────────────────────────────────
const netChange = computed(() =>
  Number(flowKpis.net_change ?? (Number(flowKpis.total_in || 0) - Number(flowKpis.total_out || 0))))

// ── Expiry runway ───────────────────────────────────────────────────────
// Non-overlapping buckets: `expiring_90` is cumulative (it includes the
// 30-day batches), so the third bar reports the 31–90 day remainder only.
const expiryRunway = computed(() => {
  const expired = Number(overview.expiry.expired) || 0
  const d30 = Number(overview.expiry.expiring_30) || 0
  const d90 = Math.max(0, (Number(overview.expiry.expiring_90) || 0) - d30)

  const rows = [
    { key: 'expired', label: 'Expired', count: expired },
    { key: 'd30', label: '≤30 days', count: d30 },
    { key: 'd90', label: '31–90 days', count: d90 },
  ]
  const max = Math.max(...rows.map((r) => r.count), 1)
  return rows.map((r) => ({ ...r, pct: (r.count / max) * 100 }))
})

// ── Fulfilment split ────────────────────────────────────────────────────
const fulfilmentTotal = computed(() =>
  (Number(overview.deliveries.to_be_packed) || 0) + (Number(overview.deliveries.to_be_shipped) || 0))
const fulfilmentShare = computed(() => {
  const total = fulfilmentTotal.value || 1
  return {
    pack: ((Number(overview.deliveries.to_be_packed) || 0) / total) * 100,
    ship: ((Number(overview.deliveries.to_be_shipped) || 0) / total) * 100,
  }
})

// ── Operational insights ────────────────────────────────────────────────
const insights = computed(() => {
  const lowOut = (Number(overview.stock.low_stock) || 0) + (Number(overview.stock.out_of_stock) || 0)
  const expiring = Number(overview.expiry.expiring_30) || 0
  const backlog = fulfilmentTotal.value
  const dead = overview.dead_stock?.length || 0

  return [
    {
      icon: lowOut ? 'mdi-cart-arrow-down' : 'mdi-check-circle-outline',
      tone: lowOut ? '#d97706' : '#16a34a',
      label: 'Replenishment',
      value: String(lowOut),
      hint: lowOut
        ? `${overview.stock.low_stock ?? 0} low · ${overview.stock.out_of_stock ?? 0} out of stock`
        : 'every item above its reorder level',
      to: lowOut ? `${p('/inventory')}?statusFilter=low` : null,
    },
    {
      icon: expiring ? 'mdi-clock-alert-outline' : 'mdi-calendar-check-outline',
      tone: expiring ? '#dc2626' : '#16a34a',
      label: 'Expiry ≤30d',
      value: String(expiring),
      hint: expiring
        ? `${overview.expiry.expired ?? 0} batch${Number(overview.expiry.expired) === 1 ? '' : 'es'} already expired`
        : 'nothing expiring this month',
      to: expiring ? `${p('/inventory')}?batchFilter=expiring` : null,
    },
    {
      icon: backlog ? 'mdi-truck-fast-outline' : 'mdi-truck-check-outline',
      tone: backlog ? '#4f46e5' : '#16a34a',
      label: 'Fulfilment queue',
      value: String(backlog),
      hint: backlog
        ? `${overview.deliveries.to_be_packed ?? 0} to pack · ${overview.deliveries.to_be_shipped ?? 0} to ship`
        : 'no deliveries waiting',
      to: backlog ? p('/deliveries') : null,
    },
    {
      icon: dead ? 'mdi-package-off' : 'mdi-package-check',
      tone: dead ? '#64748b' : '#16a34a',
      label: 'Dead stock',
      value: String(dead),
      hint: dead
        ? `top ${dead} idle lines · no sale in 90 days`
        : 'no dead stock on the shelves',
      to: dead ? p('/inventory') : null,
    },
  ]
})

// ── Range label ─────────────────────────────────────────────────────────
const rangeLabel = computed(() => {
  if (!dateFrom.value && !dateTo.value) return 'All time'
  const fmt = (v) => (v ? new Date(`${v}T00:00:00`).toLocaleDateString(undefined, {
    day: 'numeric', month: 'short', year: 'numeric'
  }) : '…')
  return `${fmt(dateFrom.value)} → ${fmt(dateTo.value)}`
})

// ── Item helpers ────────────────────────────────────────────────────────
const topMovingMax = computed(() =>
  Math.max(...(overview.top_moving || []).map((m) => Number(m.revenue) || 0), 1))
function topMovingShare(m) {
  return Math.max(4, ((Number(m.revenue) || 0) / topMovingMax.value) * 100)
}

function idleTone(d) {
  if (d.days_idle == null) return { color: 'error', cls: 'iov-idle-err' }
  if (d.days_idle > 180) return { color: 'error', cls: 'iov-idle-err' }
  if (d.days_idle > 90) return { color: 'warning', cls: 'iov-idle-warn' }
  return { color: 'info', cls: 'iov-idle-info' }
}

function num(v) {
  return Number(v || 0).toLocaleString('en-US')
}
function compactMoney(v) {
  const n = Number(v) || 0
  if (Math.abs(n) >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(1)}M`
  if (Math.abs(n) >= 1_000) return `KES ${(n / 1_000).toFixed(1)}K`
  return `KES ${n.toFixed(0)}`
}

// ── Snapshot export ─────────────────────────────────────────────────────
function exportSnapshot() {
  if (!import.meta.client) return
  const rows = [
    ['Inventory overview snapshot', new Date().toISOString().slice(0, 19).replace('T', ' ')],
    ['Period', rangeLabel.value],
    ['Branch', branchStore.currentBranch?.name || 'All warehouses'],
    [],
    ['Metric', 'Value'],
    ...kpis.value.map((k) => [k.title, k.value]),
    [],
    ['Valuation', 'Amount'],
    ['At cost', analytics.total_cost_value],
    ['At retail', analytics.total_retail_value],
    ['Potential profit', analytics.potential_profit],
    ['Gross margin %', marginPct.value],
    [],
    ['Stock flow', 'Value'],
    ['Inflow units', flowKpis.total_in],
    ['Outflow units', flowKpis.total_out],
    ['Net change', netChange.value],
    ['Postings', flowKpis.count],
    [],
    ['Expiry', 'Batches'],
    ['Expired', overview.expiry.expired ?? 0],
    ['Expiring ≤30d', overview.expiry.expiring_30 ?? 0],
    ['Expiring ≤90d', overview.expiry.expiring_90 ?? 0],
    [],
    ['Procurement', 'Value'],
    ['Open purchase orders', overview.procurement.open_purchase_orders ?? 0],
    ['GRNs received', overview.procurement.received_grns ?? 0],
    ['Units received', overview.procurement.items_received ?? 0],
    [],
    ['Top moving items', 'Qty', 'Unit', 'Revenue'],
    ...(overview.top_moving || []).map((m) => [m.name, m.qty, m.unit, m.revenue]),
    [],
    ['Dead stock', 'Qty', 'Unit', 'Days idle'],
    ...(overview.dead_stock || []).map((d) => [d.name, d.qty, d.unit, d.days_idle ?? '']),
  ]
  const csv = rows
    .map((line) => line.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `inventory-overview-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const healthLegend = computed(() => {
  const total = healthCount.value || 1
  return [
    { label: 'Healthy', count: overview.stock.healthy ?? 0, color: '#22c55e', pct: Math.round(((overview.stock.healthy ?? 0) / total) * 100) },
    { label: 'Low stock', count: overview.stock.low_stock ?? 0, color: '#f59e0b', pct: Math.round(((overview.stock.low_stock ?? 0) / total) * 100) },
    { label: 'Out of stock', count: overview.stock.out_of_stock ?? 0, color: '#ef4444', pct: Math.round(((overview.stock.out_of_stock ?? 0) / total) * 100) },
  ]
})

// ── KPI cards ───────────────────────────────────────────────────────────
// Six focused metrics, each tone-railed by currentColor and linkable to the
// screen that acts on it. `tone` drives the top accent bar + icon chip so the
// tile stays visually coherent across palettes.
const kpis = computed(() => [
  {
    title: 'Total SKUs',
    value: num(overview.stock.total_items),
    icon: 'mdi-package-variant-closed',
    tone: 'blue',
    to: p('/inventory'),
    hint: `${num(overview.stock.healthy)} healthy items`,
  },
  {
    title: 'Stock value',
    value: compactMoney(analytics.total_cost_value),
    icon: 'mdi-cash-multiple',
    tone: 'teal',
    hint: `${marginPct.value}% margin at retail`,
  },
  {
    title: 'Low stock',
    value: num(overview.stock.low_stock),
    icon: 'mdi-alert',
    tone: 'amber',
    to: p('/inventory') + '?statusFilter=low',
    hint: 'Below reorder level',
  },
  {
    title: 'Out of stock',
    value: num(overview.stock.out_of_stock),
    icon: 'mdi-package-variant-remove',
    tone: 'red',
    to: p('/inventory') + '?statusFilter=out',
    hint: 'Reorder required',
  },
  {
    title: 'Expiring ≤30d',
    value: num(overview.expiry.expiring_30),
    icon: 'mdi-clock-alert',
    tone: 'purple',
    to: p('/inventory') + '?batchFilter=expiring',
    hint: `${num(overview.expiry.expired)} already expired`,
  },
  {
    title: 'Open POs',
    value: num(overview.procurement.open_purchase_orders),
    icon: 'mdi-cart',
    tone: 'orange',
    to: p('/purchase-orders'),
    hint: `${num(overview.procurement.items_received)} units received`,
  },
])

/** Reloads everything on the page (hero refresh button). */
async function refresh() {
  await Promise.all([load(), loadMovements()])
}

async function load() {
  loading.value = true
  try {
    const params = {}
    if (dateFrom.value) params.date_from = dateFrom.value
    if (dateTo.value) params.date_to = dateTo.value
    if (branchStore.currentBranchId) params.branch_id = branchStore.currentBranchId

    const analyticsParams = branchStore.currentBranchId
      ? { branch_id: branchStore.currentBranchId }
      : {}

    // Overview + valuation in parallel; the movement report loads separately
    // so the heavier ledger call never blocks first paint.
    const [ovRes, anRes] = await Promise.all([
      $api.get('/inventory/overview/', { params }),
      $api.get('/inventory/analytics/', { params: analyticsParams }).catch(() => null),
    ])

    const data = ovRes?.data || {}
    overview.stock = data.stock || {}
    overview.expiry = data.expiry || {}
    overview.deliveries = data.deliveries || {}
    overview.procurement = data.procurement || {}
    overview.sales = data.sales || {}
    overview.top_moving = data.top_moving || []
    overview.dead_stock = data.dead_stock || []

    const an = anRes?.data || {}
    analytics.total_cost_value = an.total_cost_value ?? 0
    analytics.total_retail_value = an.total_retail_value ?? 0
    analytics.potential_profit = an.potential_profit ?? 0
  } catch (e) {
    // Leave zeroed state on failure; the page still renders.
  } finally {
    loading.value = false
  }

  loadMovements()
}

async function loadMovements() {
  movementsLoading.value = true
  try {
    const params = {}
    if (dateFrom.value) params.date_from = dateFrom.value
    if (dateTo.value) params.date_to = dateTo.value
    if (branchStore.currentBranchId) params.branch_id = branchStore.currentBranchId
    const { data } = await $api.get('/inventory/stock-movements/', { params })
    movements.value = data.movements || []

    // KPI + trend payload from the same response feeds the flow panel.
    Object.assign(flowKpis, data.kpis || {})
    const active = (data.trend || [])
      .map((d) => ({
        label: new Date(d.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }),
        inflow: (d.inflow || 0) + (d.transfer || 0),
        outflow: d.outflow || 0,
      }))
      .filter((d) => d.inflow > 0 || d.outflow > 0)
    trendLabels.value = active.map((d) => d.label)
    inflowValues.value = active.map((d) => d.inflow)
    outflowValues.value = active.map((d) => d.outflow)
  } catch (e) {
    movements.value = []
  } finally {
    movementsLoading.value = false
  }
}

onMounted(() => {
  // Deep-linking here means nothing has fetched the tenant palette yet.
  brand.load()
  load()
})

watch(() => branchStore.currentBranchId, () => {
  load()
})
</script>

<style scoped>
/* ─────────────── Page ─────────────── */
.iov-page { background: transparent; }
.iov-nowrap { white-space: nowrap; }

/* ═══════════════ Hero ═══════════════
   var() fallbacks mirror BRAND_DEFAULTS in utils/branding.js. */
.iov-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.iov-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.iov-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.iov-hero-top { position: relative; }
.iov-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
}
.iov-hero-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.iov-hero-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.iov-hero-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.iov-hero-iconbtn { color: #fff !important; }

/* Two action tiers: a saturated gradient washes out tonal fills, so the
   emphasised button paints a white pill with the tenant's darkest brand colour
   as text, and the secondary ones are translucent glass. */
.iov-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.iov-hero-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
}
.iov-hero-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.iov-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.iov-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.iov-hero-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
.iov-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.iov-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.94);
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.24);
}
.iov-hero-chip-warn {
  background: rgba(245, 158, 11, 0.34);
  border-color: rgba(255, 255, 255, 0.42);
}
.iov-hero-chip-alert {
  background: rgba(239, 68, 68, 0.3);
  border-color: rgba(255, 255, 255, 0.45);
}

/* ─────────────── Toolbar card ─────────────── */
.iov-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.iov-toolbar-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
}
.iov-toolbar-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  line-height: 1.2;
}
.iov-toolbar-sub {
  font-size: 12px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.85);
}
.iov-date-chips { flex: 1 1 auto; min-width: 260px; }
.iov-date-field { max-width: 168px; }

/* ─────────────── KPI cards ───────────────
   Tone travels via `color`, so the top rail, the icon chip and the link
   underline can all derive from currentColor. Hover gives a small lift. */
.iov-kpi {
  position: relative;
  overflow: hidden;
  display: block;
  border-radius: 14px;
  padding: 14px 16px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  color: inherit;
  text-decoration: none;
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.iov-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  background: currentColor;
  opacity: 0.85;
}
.iov-kpi:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1); }
.iov-kpi-link { cursor: pointer; }
.iov-kpi-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: currentColor;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.iov-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}
.iov-kpi-value {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  margin-top: 1px;
}
.iov-kpi-foot {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
  margin-top: 2px;
}

/* Per-KPI hues drive the top accent bar + icon chip via currentColor. */
.iov-kpi-t-blue { color: #2563eb; }
.iov-kpi-t-teal { color: #0d9488; }
.iov-kpi-t-amber { color: #d97706; }
.iov-kpi-t-red { color: #dc2626; }
.iov-kpi-t-purple { color: #7c3aed; }
.iov-kpi-t-orange { color: #ea580c; }

/* ─────────────── Panels ───────────────
   Faint brand wash at the top keeps the cards from reading as flat white
   boxes without competing with the data. */
.iov-panel {
  border-color: rgba(15, 23, 42, 0.08) !important;
  background:
    linear-gradient(180deg, rgba(var(--v-theme-primary), 0.03) 0%, transparent 110px),
    rgb(var(--v-theme-surface)) !important;
  transition: box-shadow 0.18s ease, transform 0.18s ease;
}
.iov-panel:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 26px rgba(15, 23, 42, 0.08);
}
.iov-panel-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: -0.1px;
}
.iov-panel-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 10px;
  flex-shrink: 0;
  color: var(--panel-tone, #2563eb);
  background: color-mix(in srgb, var(--panel-tone, #2563eb) 14%, transparent);
}

/* ─────────────── Valuation ─────────────── */
.iov-val-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 10px;
}
.iov-val-tile {
  padding: 10px 12px;
  border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  background: rgba(var(--v-theme-surface-variant), 0.2);
}
.iov-val-tile-good {
  border-color: rgba(22, 163, 74, 0.22);
  background: rgba(34, 197, 94, 0.08);
}
.iov-val-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.iov-val-value {
  font-size: 16px;
  font-weight: 800;
  letter-spacing: -0.3px;
  line-height: 1.25;
  margin-top: 1px;
}
.iov-val-hint {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.iov-split-bar {
  display: flex;
  height: 10px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(15, 23, 42, 0.06);
}
.iov-split-cost { display: block; height: 100%; background: #0d9488; }
.iov-split-margin { display: block; height: 100%; background: #22c55e; }

/* ─────────────── Flow stats ─────────────── */
.iov-flowstat {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 62px;
  padding: 4px 9px;
  border-radius: 10px;
  line-height: 1.2;
}
.iov-flowstat-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  opacity: 0.7;
}
.iov-flowstat-value { font-size: 14.5px; font-weight: 800; }
.iov-flowstat-in { background: rgba(34, 197, 94, 0.12); color: #15803d; }
.iov-flowstat-out { background: rgba(239, 68, 68, 0.12); color: #b91c1c; }
.iov-flowstat-net { background: rgba(14, 165, 233, 0.12); color: #0369a1; }

/* ─────────────── Insights band ─────────────── */
.iov-insights {
  border-radius: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  overflow: hidden;
}
.iov-insights-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.9px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  border-bottom: 1px solid rgba(15, 23, 42, 0.07);
}
.iov-insights-note {
  margin-left: auto;
  font-weight: 500;
  letter-spacing: 0;
  text-transform: none;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.iov-insights-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); }
.iov-insight {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  color: inherit;
  text-decoration: none;
  border-left: 1px solid rgba(15, 23, 42, 0.07);
  transition: background 0.16s ease;
}
.iov-insight:first-child { border-left: none; }
.iov-insight-link { cursor: pointer; }
.iov-insight-link:hover { background: rgba(var(--v-theme-primary), 0.045); }
.iov-insight-icon {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--insight-tone, #2563eb);
  background: color-mix(in srgb, var(--insight-tone, #2563eb) 14%, transparent);
}
.iov-insight-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.iov-insight-value {
  font-size: 19px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  color: var(--insight-tone, #2563eb);
}
.iov-insight-hint {
  font-size: 11.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.6);
}

/* ─────────────── Expiry runway ─────────────── */
.iov-runway {
  display: flex;
  align-items: flex-end;
  gap: 10px;
  height: 96px;
}
.iov-runway-col {
  flex: 1 1 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 0;
}
.iov-runway-value {
  font-size: 11px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.65);
  margin-bottom: 3px;
}
.iov-runway-track {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  border-radius: 6px;
  background: rgba(15, 23, 42, 0.035);
}
.iov-runway-bar {
  width: 62%;
  max-width: 38px;
  border-radius: 5px 5px 2px 2px;
  transition: height 0.3s ease;
}
.iov-runway-expired { background: linear-gradient(180deg, #f87171, #b91c1c); }
.iov-runway-d30 { background: linear-gradient(180deg, #fbbf24, #d97706); }
.iov-runway-d90 { background: linear-gradient(180deg, #7dd3fc, #0284c7); }
.iov-runway-label {
  margin-top: 5px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}

/* ─────────────── Fulfilment split ─────────────── */
.iov-fulfil-bar {
  display: flex;
  height: 8px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(15, 23, 42, 0.06);
}
.iov-fulfil-pack { display: block; height: 100%; background: #14b8a6; }
.iov-fulfil-ship { display: block; height: 100%; background: #0891b2; }

/* ─────────────── Ranked rows / dead stock ─────────────── */
.iov-rankrow + .iov-rankrow { margin-top: 10px; }
.iov-rank {
  width: 20px;
  height: 20px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 10.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.iov-bar-track {
  height: 6px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.07);
  overflow: hidden;
}
.iov-bar-track span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, #6366f1, #2563eb);
}
.iov-dead-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 8px;
  border-radius: 9px;
  color: inherit;
  text-decoration: none;
  transition: background 0.14s ease;
}
.iov-dead-row:hover { background: rgba(var(--v-theme-primary), 0.05); }
.iov-idle-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.iov-idle-err { background: #dc2626; box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.14); }
.iov-idle-warn { background: #f59e0b; box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.14); }
.iov-idle-info { background: #0ea5e9; box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.14); }

/* Legend rows (stock health) */
.iov-legend { display: flex; align-items: center; gap: 8px; padding: 5px 0; }
.iov-legend-dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
.iov-legend-pct { min-width: 34px; text-align: right; }

/* Inline metric row (units on hand) */
.iov-metric-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 0;
  border-top: 1px solid rgba(15, 23, 42, 0.06);
}

/* List items (expiry, fulfilment) */
.iov-list-item {
  border-radius: 10px;
  transition: background 0.16s ease;
  margin: 2px 0;
}
.iov-list-item:hover {
  background: rgba(var(--v-theme-surface-variant), 0.3);
}
.iov-list-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--tone, #2563eb);
  background: color-mix(in srgb, var(--tone, #2563eb) 14%, transparent);
}

/* Mini grid (procurement / sales tiles) */
.iov-mini-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 10px;
}
.iov-mini-tile {
  padding: 10px 14px;
  border-radius: 10px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  background: rgba(var(--v-theme-surface-variant), 0.18);
}

/* Tables */
.iov-table { border-radius: 10px; overflow: hidden; }
.iov-table :deep(th) {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
</style>
