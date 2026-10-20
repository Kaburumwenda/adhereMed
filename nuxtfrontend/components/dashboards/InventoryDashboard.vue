<template>
  <v-container fluid class="pa-3 pa-md-5 ims-dash">
    <!-- ═══════════════ HERO ═══════════════
         Brand-tinted gradient (tenant palette from /ims/organization/branding),
         same CSS-variable bridge as the inventory list/detail/form heroes so
         the whole IMS surface reads as one product. -->
    <div class="ims-hero mb-4" :style="heroTheme">
      <span class="ims-hero-glow" />
      <span class="ims-hero-glow ims-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3 ims-hero-top">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="ims-hero-icon">
            <v-icon size="30">mdi-warehouse</v-icon>
          </div>
          <div style="min-width:0">
            <div class="ims-hero-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              {{ auth.tenantName || 'INVENTORY' }} · OPERATIONS
            </div>
            <h1 class="ims-hero-title">{{ greeting }}, {{ firstName }}</h1>
            <div class="ims-hero-sub">
              Warehouse operations · {{ today }}
              <span v-if="branchLabel"> · {{ branchLabel }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="ims-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none ims-hero-btn-glass"
            prepend-icon="mdi-download-outline"
            title="Download a CSV snapshot of this dashboard"
            :disabled="loading"
            @click="exportSnapshot"
          >Snapshot</v-btn>
          <v-btn
            v-if="canAccessRoute(auth.role, '/ims/inventory/stock-take')"
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none ims-hero-btn-glass"
            prepend-icon="mdi-clipboard-check-outline"
            to="/ims/inventory/stock-take"
          >New stock take</v-btn>
          <v-btn
            v-if="canAccessRoute(auth.role, '/ims/inventory/stocks/new')"
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none ims-hero-btn-strong"
            prepend-icon="mdi-plus"
            to="/ims/inventory/stocks/new"
          >Add stock item</v-btn>
        </div>
      </div>

      <div class="ims-hero-foot d-flex flex-wrap align-center" style="gap:8px">
        <span class="ims-hero-chip">
          <v-icon size="14">mdi-package-variant-closed</v-icon>
          {{ num(analytics?.total_items ?? stocks.length) }} SKUs
        </span>
        <span class="ims-hero-chip">
          <v-icon size="14">mdi-scale-balance</v-icon>
          {{ num(unitsOnHand) }} units on hand
        </span>
        <span class="ims-hero-chip">
          <v-icon size="14">mdi-cash-multiple</v-icon>
          {{ formatMoney(analytics?.total_cost_value ?? 0) }} at cost
        </span>
        <span class="ims-hero-chip" :class="healthChipClass">
          <v-icon size="14">{{ health.icon }}</v-icon>
          {{ healthPct }}% healthy
        </span>
        <span v-if="openPOs.length" class="ims-hero-chip ims-hero-chip-alert">
          <v-icon size="14">mdi-cart-clock</v-icon>
          {{ openPOs.length }} open PO{{ openPOs.length === 1 ? '' : 's' }}
        </span>
        <span v-if="stockHealth.out" class="ims-hero-chip ims-hero-chip-alert">
          <v-icon size="14">mdi-package-variant-remove</v-icon>
          {{ stockHealth.out }} out of stock
        </span>
      </div>
    </div>

    <!-- ═══════════════ KPI STRIP ═══════════════ -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.key" cols="6" md="4" lg="2">
        <component
          :is="linkOr(k.to)"
          :to="k.to || undefined"
          class="ims-kpi h-100"
          :class="[`ims-kpi-t-${k.key}`, k.to ? 'ims-kpi-link' : '']"
        >
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="ims-kpi-icon">
              <v-icon size="18">{{ k.icon }}</v-icon>
            </div>
            <v-chip
              v-if="k.chip"
              size="x-small"
              :color="k.chipColor"
              variant="tonal"
              class="font-weight-bold"
            >{{ k.chip }}</v-chip>
          </div>
          <div class="ims-kpi-label">{{ k.title }}</div>
          <div class="ims-kpi-value">{{ k.value }}</div>
          <div v-if="k.hint" class="ims-kpi-foot">{{ k.hint }}</div>
          <div v-if="k.share != null" class="ims-kpi-bars mt-2">
            <span :style="{ width: k.share + '%' }" />
          </div>
        </component>
      </v-col>
    </v-row>

    <!-- ═══════════════ OPS PULSE ═══════════════
         Derived observations rather than another row of raw counts: each tile
         says what the number means and links to the screen that acts on it. -->
    <div class="ims-pulse my-3">
      <div class="ims-pulse-head">
        <v-icon size="17">mdi-pulse</v-icon>
        <span>Operational pulse</span>
        <div class="ims-pulse-compare">
          <span class="ims-compare-label">vs previous {{ trendDays }}d</span>
          <span
            v-for="c in periodCompare"
            :key="c.label"
            class="ims-compare"
            :class="c.good ? 'ims-compare-up' : 'ims-compare-down'"
          >
            <v-icon size="12">{{ c.icon }}</v-icon>
            {{ c.label }} {{ c.value }}
          </span>
        </div>
      </div>
      <div class="ims-pulse-grid">
        <component
          :is="linkOr(p.to)"
          :to="p.to || undefined"
          v-for="p in pulse"
          :key="p.label"
          class="ims-pulse-tile"
          :class="{ 'ims-pulse-link': !!p.to }"
          :style="{ '--pulse-tone': p.tone }"
        >
          <div class="ims-pulse-icon"><v-icon size="17">{{ p.icon }}</v-icon></div>
          <div style="min-width:0">
            <div class="ims-pulse-label">{{ p.label }}</div>
            <div class="ims-pulse-value">{{ p.value }}</div>
            <div class="ims-pulse-hint">{{ p.hint }}</div>
          </div>
        </component>
      </div>
    </div>

    <!-- ═══════════════ INTELLIGENCE ROW ═══════════════
         Two forward-looking panels: what will run out, and how concentrated
         the capital is. Both derive entirely from the payloads already loaded
         (stocks + the movement rollup), so no extra endpoint is needed. -->
    <v-row dense class="mb-1">
      <v-col cols="12" lg="7">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#dc2626">
                <v-icon size="17">mdi-timer-alert-outline</v-icon>
              </div>
              <div>
                <h3 class="ims-panel-title">Stockout forecast</h3>
                <div class="text-caption text-medium-emphasis">
                  Days of cover at the current run rate ({{ trendDays }}d average)
                </div>
              </div>
            </div>
            <v-chip
              size="small"
              :color="stockoutRisk.length ? 'error' : 'success'"
              variant="tonal"
              class="font-weight-bold"
            >
              {{ stockoutRisk.length ? `${stockoutRisk.length} at risk` : 'All healthy' }}
            </v-chip>
          </div>

          <EmptyState
            v-if="!coverRows.length"
            icon="mdi-chart-timeline-variant"
            title="No consumption data yet"
            message="Cover days appear once items start issuing stock."
          />

          <template v-else>
            <div class="ims-risk-head">
              <span>Item · tightest cover first</span>
              <span class="text-right">On hand</span>
              <span class="text-right">Daily use</span>
              <span class="text-right">Cover</span>
            </div>
            <component
              :is="linkOr(`/ims/inventory/stocks/${s.id}/edit`)"
              :to="`/ims/inventory/stocks/${s.id}/edit`"
              v-for="s in coverRows.slice(0, 6)"
              :key="s.id"
              class="ims-risk-row"
            >
              <div class="ims-risk-name">
                <span class="ims-risk-dot" :class="`ims-risk-${s.severity}`" />
                <span class="text-truncate">{{ s.name }}</span>
              </div>
              <span class="text-right ims-nowrap">{{ num(s.qty) }}</span>
              <span class="text-right ims-nowrap">{{ s.rate.toFixed(1) }}/day</span>
              <span class="text-right ims-nowrap">
                <span class="ims-cover" :class="`ims-cover-${s.severity}`">
                  {{ s.coverDays == null ? '—' : s.coverDays.toFixed(0) + 'd' }}
                </span>
              </span>
              <span class="ims-risk-bar">
                <span
                  :style="{ width: Math.min(100, (s.coverRatio || 0) * 100) + '%' }"
                  :class="`ims-risk-fill-${s.severity}`"
                />
              </span>
            </component>
            <NuxtLink v-if="stockoutRisk.length" to="/ims/inventory" class="ims-row-more mt-1">
              Review all {{ num(stockoutRisk.length) }} at-risk items
              <v-icon size="13">mdi-arrow-right</v-icon>
            </NuxtLink>
            <div v-else class="text-caption text-medium-emphasis mt-2 d-flex align-center" style="gap:6px">
              <v-icon size="14" color="success">mdi-check-circle-outline</v-icon>
              Every moving item has more than {{ COVER_WATCH_DAYS }} days of cover at the current run rate.
            </div>
          </template>
        </v-card>
      </v-col>

      <v-col cols="12" lg="5">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#7c3aed">
                <v-icon size="17">mdi-chart-donut-variant</v-icon>
              </div>
              <div>
                <h3 class="ims-panel-title">Value concentration</h3>
                <div class="text-caption text-medium-emphasis">ABC analysis of capital at cost</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="purple" class="font-weight-bold">
              {{ compactMoney(abc.totalValue) }}
            </v-chip>
          </div>

          <EmptyState v-if="!abc.classes.length" icon="mdi-chart-donut" title="No valued stock yet" />

          <template v-else>
            <div class="ims-abc-bar mb-3">
              <span
                v-for="c in abc.classes"
                :key="c.key"
                :style="{ flex: c.valueShare, background: c.color }"
                :title="`${c.label}: ${c.valueShare}% of value`"
              />
            </div>
            <div class="d-flex flex-column ga-2">
              <div v-for="c in abc.classes" :key="c.key" class="ims-abc-row">
                <span class="ims-abc-key" :style="{ background: c.color }">{{ c.key }}</span>
                <div style="min-width:0; flex:1">
                  <div class="text-body-2 font-weight-medium">{{ c.label }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ num(c.count) }} SKU{{ c.count === 1 ? '' : 's' }} · {{ c.valueShare }}% of value
                  </div>
                </div>
                <span class="ims-abc-val">{{ formatMoney(c.value) }}</span>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex align-center" style="gap:10px">
              <v-icon size="18" color="warning">mdi-lightbulb-on-outline</v-icon>
              <div class="text-caption" style="line-height: 1.45">{{ abc.insight }}</div>
            </div>
          </template>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ FLOW + HEALTH ═══════════════ -->
    <v-row dense>
      <v-col cols="12" lg="8">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex flex-wrap align-center justify-space-between ga-2 mb-3">
            <div>
              <h3 class="ims-panel-title">Stock flow</h3>
              <div class="text-caption text-medium-emphasis">Inflow vs outflow across all warehouses</div>
            </div>
            <div class="d-flex align-center ga-2">
              <div class="ims-flowstat ims-flowstat-in">
                <span class="ims-flowstat-label">In</span>
                <span class="ims-flowstat-value">{{ num(flowKpis.total_in) }}</span>
              </div>
              <div class="ims-flowstat ims-flowstat-out">
                <span class="ims-flowstat-label">Out</span>
                <span class="ims-flowstat-value">{{ num(flowKpis.total_out) }}</span>
              </div>
              <div class="ims-flowstat ims-flowstat-net">
                <span class="ims-flowstat-label">Net</span>
                <span class="ims-flowstat-value">{{ netChange > 0 ? '+' : '' }}{{ num(netChange) }}</span>
              </div>
            </div>
          </div>

          <EmptyState
            v-if="!inflowValues.length"
            icon="mdi-chart-timeline-variant"
            title="No stock movement in this period"
            message="Movements appear here once goods are received, sold or transferred."
          />
          <template v-else>
            <div class="d-flex align-center ga-4 mb-1">
              <div class="d-flex align-center">
                <span class="ims-legend-dot" style="background:#22c55e" />
                <span class="text-caption text-medium-emphasis ml-1">Inflow</span>
              </div>
              <div class="d-flex align-center">
                <span class="ims-legend-dot" style="background:#ef4444" />
                <span class="text-caption text-medium-emphasis ml-1">Outflow</span>
              </div>
              <span class="text-caption text-medium-emphasis ml-auto" style="font-size: 11px">
                {{ trendLabels.length }} active day{{ trendLabels.length === 1 ? '' : 's' }}
              </span>
            </div>
            <StockFlowChart
              :inflow="inflowValues"
              :outflow="outflowValues"
              :labels="trendLabels"
              :height="220"
            />
          </template>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Stock health</h3>
              <div class="text-caption text-medium-emphasis">Availability by item</div>
            </div>
            <v-chip size="small" :color="healthChipColor" variant="tonal" class="font-weight-bold">
              {{ healthPct }}% healthy
            </v-chip>
          </div>

          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="healthSegments" :size="176" :thickness="16">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ num(totalSkus) }}</div>
                <div class="text-caption text-medium-emphasis">SKUs</div>
              </div>
            </DonutRing>
          </div>

          <div v-for="h in healthLegend" :key="h.label" class="ims-legend">
            <span class="ims-legend-dot" :style="{ background: h.color }" />
            <span class="text-body-2 flex-grow-1">{{ h.label }}</span>
            <span class="text-body-2 font-weight-bold">{{ h.count }}</span>
            <span class="text-caption text-medium-emphasis ims-legend-pct">{{ h.pct }}%</span>
          </div>

          <v-btn
            block
            variant="tonal"
            color="primary"
            rounded="lg"
            class="text-none mt-3"
            prepend-icon="mdi-chart-line"
            to="/ims/inventory/stock-analysis"
          >Open stock analysis</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ VALUE + MOVEMENTS ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" lg="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Top items by stock value</h3>
              <div class="text-caption text-medium-emphasis">Capital tied up, valued at cost</div>
            </div>
            <v-btn
              variant="text" size="small" class="text-none" color="primary"
              to="/ims/inventory/stock-analysis" append-icon="mdi-arrow-right"
            >Analysis</v-btn>
          </div>
          <EmptyState v-if="!topValueItems.length" icon="mdi-package-variant-closed" title="No stock yet" />
          <div v-else>
            <div v-for="(p, i) in topValueItems" :key="p.name" class="mb-3">
              <div class="d-flex justify-space-between align-center text-body-2 mb-1">
                <span class="text-truncate d-flex align-center" style="gap:8px; min-width:0">
                  <span class="ims-rank">{{ i + 1 }}</span>
                  <span class="text-truncate">{{ p.name }}</span>
                  <span class="text-caption text-medium-emphasis ims-nowrap">{{ p.qty }} {{ p.unit || 'units' }}</span>
                </span>
                <span class="font-weight-bold ims-nowrap ml-2">{{ formatMoney(p.value) }}</span>
              </div>
              <div class="ims-bar-track">
                <span :style="{ width: p.pct + '%', background: p.color }" />
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div>
              <h3 class="ims-panel-title">Recent stock movements</h3>
              <div class="text-caption text-medium-emphasis">Latest postings to the ledger</div>
            </div>
            <v-btn
              variant="text" size="small" class="text-none" color="primary"
              to="/ims/inventory/stock-movements" append-icon="mdi-arrow-right"
            >Ledger</v-btn>
          </div>
          <EmptyState v-if="!recentMovements.length" icon="mdi-swap-vertical" title="No movements recorded yet" />
          <div v-else class="d-flex flex-column">
            <div v-for="m in recentMovements.slice(0, 7)" :key="m.id" class="ims-movement">
              <span class="ims-movement-dot" :class="`ims-mv-${m.direction}`">
                <v-icon size="14">{{ movementIcon(m.direction) }}</v-icon>
              </span>
              <div class="ims-row-main">
                <div class="ims-row-title text-truncate">{{ m.stock_name }}</div>
                <div class="ims-row-sub text-truncate">{{ m.source }} · {{ formatRelative(m.timestamp) }}</div>
              </div>
              <span class="ims-movement-qty" :class="`ims-mv-text-${m.direction}`">
                {{ m.direction === 'outflow' ? '' : '+' }}{{ num(m.quantity_change) }}
              </span>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ NETWORK INTELLIGENCE ═══════════════
         Warehouse benchmarking, expiry runway and idle capital — the three
         questions a warehouse lead asks that raw counts never answer. -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6" xl="4">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#2563eb">
                <v-icon size="17">mdi-warehouse</v-icon>
              </div>
              <div>
                <h3 class="ims-panel-title">Warehouse comparison</h3>
                <div class="text-caption text-medium-emphasis">Value and health by location</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">
              {{ branchBreakdown.length }}
            </v-chip>
          </div>

          <EmptyState v-if="!branchBreakdown.length" icon="mdi-warehouse" title="No warehouses configured" />

          <div v-for="b in branchBreakdown" :key="b.name" class="ims-branch">
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-body-2 font-weight-medium text-truncate">{{ b.name }}</span>
              <span class="ims-nowrap text-body-2 font-weight-bold">{{ formatMoney(b.value) }}</span>
            </div>
            <div class="ims-bar-track mb-1">
              <span :style="{ width: b.valuePct + '%', background: b.color }" />
            </div>
            <div class="d-flex align-center justify-space-between text-caption text-medium-emphasis">
              <span>{{ num(b.skus) }} SKUs · {{ b.healthPct }}% healthy</span>
              <span v-if="b.flags" class="ims-branch-flags">{{ b.flags }}</span>
            </div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" md="6" xl="4">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#d97706">
                <v-icon size="17">mdi-calendar-clock-outline</v-icon>
              </div>
              <div>
                <h3 class="ims-panel-title">Expiry runway</h3>
                <div class="text-caption text-medium-emphasis">Units leaving shelf life, next 6 months</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="warning" class="font-weight-bold">
              {{ compactMoney(expiryTotalValue) }}
            </v-chip>
          </div>

          <EmptyState v-if="!expiryRunway.length" icon="mdi-calendar-check" title="No dated batches in this window" />

          <div v-else class="ims-runway">
            <div v-for="m in expiryRunway" :key="m.key" class="ims-runway-col">
              <span class="ims-runway-value">{{ num(m.units) }}</span>
              <div class="ims-runway-bar-wrap">
                <span
                  class="ims-runway-bar"
                  :class="{ 'ims-runway-bar-soon': m.soon }"
                  :style="{ height: Math.max(4, m.pct) + '%' }"
                  :title="`${num(m.units)} units · ${formatMoney(m.value)}`"
                />
              </div>
              <span class="ims-runway-label">{{ m.label }}</span>
            </div>
          </div>
          <div v-if="expiryRunway.length" class="text-caption text-medium-emphasis mt-3 d-flex align-center" style="gap:6px">
            <v-icon size="14" color="error">mdi-alert-circle-outline</v-icon>
            {{ num(expiring.length) }} batch{{ expiring.length === 1 ? '' : 'es' }} expire within {{ expiryWindow }} days
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" md="12" xl="4">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#64748b">
                <v-icon size="17">mdi-sleep</v-icon>
              </div>
              <div>
                <h3 class="ims-panel-title">Idle capital</h3>
                <div class="text-caption text-medium-emphasis">Stock with no movement in {{ trendDays }} days</div>
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="grey" class="font-weight-bold">
              {{ compactMoney(idleCapital.value) }}
            </v-chip>
          </div>

          <EmptyState
            v-if="!idleCapital.items.length"
            icon="mdi-check-circle-outline"
            title="No idle stock"
            message="Every item with value on hand moved during the period."
          />

          <template v-else>
            <div class="d-flex align-center mb-3" style="gap:16px">
              <div>
                <div class="ims-mini-label">Items</div>
                <div class="ims-mini-value">{{ num(idleCapital.items.length) }}</div>
              </div>
              <div>
                <div class="ims-mini-label">Units</div>
                <div class="ims-mini-value">{{ num(idleCapital.units) }}</div>
              </div>
              <div>
                <div class="ims-mini-label">Share of value</div>
                <div class="ims-mini-value">{{ idleCapital.sharePct }}%</div>
              </div>
            </div>
            <component
              :is="linkOr(`/ims/inventory/stocks/${s.id}/edit`)"
              :to="`/ims/inventory/stocks/${s.id}/edit`"
              v-for="s in idleCapital.items.slice(0, 4)"
              :key="s.id"
              class="ims-row ims-row-link"
            >
              <div class="ims-row-main">
                <div class="ims-row-title text-truncate">{{ s.name }}</div>
                <div class="ims-row-sub">{{ num(s.qty) }} {{ s.unit || 'units' }} on hand</div>
              </div>
              <span class="ims-row-badge ims-badge-neutral">{{ formatMoney(s.value) }}</span>
            </component>
            <NuxtLink to="/ims/inventory/stock-analysis" class="ims-row-more mt-1">
              Investigate idle stock
              <v-icon size="13">mdi-arrow-right</v-icon>
            </NuxtLink>
          </template>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ NEEDS ATTENTION ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col v-for="q in queues" :key="q.key" cols="12" md="4">
        <v-card rounded="lg" border class="h-100 ims-panel ims-queue" :class="`ims-queue-${q.key}`">
          <div class="ims-queue-head">
            <div class="ims-queue-icon">
              <v-icon size="18">{{ q.icon }}</v-icon>
            </div>
            <div style="min-width:0">
              <div class="ims-panel-title">{{ q.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ q.sub }}</div>
            </div>
            <span class="ims-queue-count">{{ q.count }}</span>
          </div>

          <div class="ims-queue-body">
            <EmptyState v-if="!q.items.length" :icon="q.emptyIcon" :title="q.emptyTitle" />
            <div v-else class="d-flex flex-column ga-1">
              <component
                :is="linkOr(q.linkOf ? q.linkOf(item) : null)"
                :to="q.linkOf ? q.linkOf(item) : undefined"
                v-for="(item, idx) in q.items.slice(0, 4)"
                :key="idx"
                class="ims-row"
                :class="{ 'ims-row-link': !!q.linkOf }"
              >
                <div class="ims-row-main">
                  <div class="ims-row-title text-truncate">{{ q.titleOf(item) }}</div>
                  <div class="ims-row-sub text-truncate">{{ q.subOf(item) }}</div>
                </div>
                <span v-if="q.badgeOf" class="ims-row-badge">{{ q.badgeOf(item) }}</span>
              </component>
              <NuxtLink v-if="q.items.length > 4" :to="q.moreTo" class="ims-row-more">
                +{{ q.items.length - 4 }} more
                <v-icon size="13">mdi-arrow-right</v-icon>
              </NuxtLink>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ TRANSFERS + STOCK TAKES ═══════════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#7c3aed">
                <v-icon size="17">mdi-truck-delivery-outline</v-icon>
              </div>
              <h3 class="ims-panel-title">Warehouse transfers</h3>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/inventory/transfers" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentTransfers.length" icon="mdi-truck-delivery" title="No transfers yet" />
          <table v-else class="ims-table">
            <thead>
              <tr><th>Ref</th><th>Route</th><th>Status</th></tr>
            </thead>
            <tbody>
              <tr v-for="tr in recentTransfers" :key="tr.id">
                <td class="font-weight-medium">{{ tr.reference }}</td>
                <td class="text-truncate" style="max-width:180px">
                  {{ tr.source_branch_name }}
                  <v-icon size="12" class="mx-1">mdi-arrow-right</v-icon>
                  {{ tr.dest_branch_name }}
                </td>
                <td><StatusChip v-if="tr.status" :status="tr.status" /></td>
              </tr>
            </tbody>
          </table>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card rounded="lg" border class="pa-4 h-100 ims-panel">
          <div class="d-flex align-center justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <div class="ims-panel-icon" style="--panel-tone:#0d9488">
                <v-icon size="17">mdi-clipboard-list-outline</v-icon>
              </div>
              <h3 class="ims-panel-title">Stock takes</h3>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/inventory/stock-take" append-icon="mdi-arrow-right">All</v-btn>
          </div>
          <EmptyState v-if="!recentCounts.length" icon="mdi-clipboard-check-outline" title="No stock takes yet" />
          <table v-else class="ims-table">
            <thead>
              <tr><th>Ref</th><th>Name</th><th class="text-right">Variance</th><th>Status</th></tr>
            </thead>
            <tbody>
              <tr v-for="c in recentCounts" :key="c.id">
                <td class="font-weight-medium">{{ c.reference }}</td>
                <td class="text-truncate" style="max-width:150px">{{ c.name }}</td>
                <td class="text-right font-weight-bold" :class="varianceTone(c)">{{ varianceLabel(c) }}</td>
                <td><StatusChip v-if="c.status" :status="c.status" /></td>
              </tr>
            </tbody>
          </table>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════ QUICK ACTIONS ═══════════════ -->
    <v-card rounded="lg" border class="pa-4 mt-3 ims-panel">
      <h3 class="ims-panel-title mb-3">Quick actions</h3>
      <div class="ims-actions">
        <NuxtLink
          v-for="a in actions"
          :key="a.label"
          :to="a.to"
          class="ims-action"
          :style="{ '--act-tone': a.tone }"
        >
          <v-icon size="19">{{ a.icon }}</v-icon>
          <span class="text-truncate">{{ a.label }}</span>
        </NuxtLink>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { NuxtLink } from '#components'
import { useAuthStore } from '~/stores/auth'
import { useBranchStore } from '~/stores/branch'
import { formatMoney, formatDate } from '~/utils/format'
import { canAccessRoute } from '~/utils/permissions'
import { useBranding } from '~/composables/useBranding'

const auth = useAuthStore()
const branchStore = useBranchStore()
const { $api } = useNuxtApp()

/**
 * `<component :is>` needs a component *object*. The string `'NuxtLink'` is NOT
 * resolved by Nuxt's auto-import (it silently renders an inert custom element
 * named NUXTLINK), so pass the imported component instead.
 */
const linkOr = (to) => (to ? NuxtLink : 'div')

// Tenant palette configured at /ims/organization/branding. Same CSS-var bridge
// the inventory list / detail / form pages use, so the IMS screens match.
const brand = useBranding()

// The third gradient stop is the accent mixed toward the primary: accent
// colours are typically near-white highlights, and the glass/solid buttons sit
// at that end of the panel.
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

const today = new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
const loading = ref(false)
const trendDays = 30
const expiryWindow = 90
const analytics = ref(null)
const stocks = ref([])
const flowKpis = reactive({ total_in: 0, total_out: 0, total_transfer: 0, net_change: 0 })
const trendLabels = ref([])
const inflowValues = ref([])
const outflowValues = ref([])
const recentMovements = ref([])
const topValueItems = ref([])
const lowStock = ref([])
const expiring = ref([])
const openPOs = ref([])
const recentTransfers = ref([])
const recentCounts = ref([])

// ── Premium analytics state ──────────────────────────────────────────────
// `movementItems` is the per-item rollup returned alongside the movement
// report — the source of truth for run-rate (and therefore cover days).
const movementItems = ref([])
const previousKpis = ref(null)
const runwayMonths = 6

const stockHealth = reactive({ healthy: 0, low: 0, out: 0 })
const barColors = ['#2563eb', '#0d9488', '#16a34a', '#d97706', '#7c3aed', '#0ea5e9']

const branchLabel = computed(() =>
  branchStore.currentBranch ? branchStore.currentBranch.name : 'All warehouses')

const unitsOnHand = computed(() => stocks.value.reduce((s, x) => s + (Number(x.total_quantity) || 0), 0))

// ── Greeting ─────────────────────────────────────────────────────────────
const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 17) return 'Good afternoon'
  return 'Good evening'
})
const firstName = computed(() => {
  const name = auth.user?.full_name || auth.user?.first_name || ''
  return String(name).trim().split(/\s+/)[0] || 'there'
})

/** 1,234 — explicit locale so grouping can't drift between renders. */
function num(v) {
  return Number(v || 0).toLocaleString('en-US')
}

/** KES 88.9K / KES 1.2M — for chips where full precision would wrap. */
function compactMoney(v) {
  const n = Number(v) || 0
  if (Math.abs(n) >= 1_000_000) return `KES ${(n / 1_000_000).toFixed(1)}M`
  if (Math.abs(n) >= 1_000) return `KES ${(n / 1_000).toFixed(1)}K`
  return `KES ${n.toFixed(0)}`
}

// ── KPI strip ────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const a = analytics.value || {}
  const total = Math.max(stocks.value.length, 1)
  return [
    {
      key: 'skus', title: 'Total SKUs', icon: 'mdi-package-variant-closed',
      value: num(a.total_items ?? stocks.value.length),
      hint: `${num(stocks.value.filter(s => s.is_active !== false).length)} active`,
      chip: null, share: null,
      to: '/ims/inventory'
    },
    {
      key: 'value', title: 'Stock value (cost)', icon: 'mdi-cash-multiple',
      value: formatMoney(a.total_cost_value ?? 0),
      hint: a.potential_profit ? `${formatMoney(a.potential_profit)} profit potential` : 'Capital tied up',
      chip: null, share: null
    },
    {
      key: 'units', title: 'Units on hand', icon: 'mdi-scale-balance',
      value: num(unitsOnHand.value),
      hint: `across ${num(stocks.value.length)} line items`,
      chip: null, share: null
    },
    {
      key: 'low', title: 'Low stock', icon: 'mdi-alert-outline',
      value: num(a.low_stock_count ?? stockHealth.low),
      hint: 'below reorder level',
      chip: null, share: Math.round((stockHealth.low / total) * 100),
      to: '/ims/inventory'
    },
    {
      key: 'out', title: 'Out of stock', icon: 'mdi-package-variant-remove',
      value: num(a.out_of_stock ?? stockHealth.out),
      hint: 'unavailable to sell',
      chip: null, share: Math.round((stockHealth.out / total) * 100),
      to: '/ims/inventory'
    },
    {
      key: 'expiring', title: `Expiring ≤${expiryWindow}d`, icon: 'mdi-clock-alert-outline',
      // Deliberately the 90-day list, not analytics.expiring_30_days — the
      // label says 90d and the two windows would otherwise disagree.
      value: num(expiring.value.length),
      hint: a.expired_batches ? `${a.expired_batches} already expired` : 'within the window',
      chip: a.expired_batches ? `${a.expired_batches} expired` : null,
      chipColor: 'error', share: null
    }
  ]
})

// ── Hero health ──────────────────────────────────────────────────────────
const totalSkus = computed(() => stockHealth.healthy + stockHealth.low + stockHealth.out)
const healthPct = computed(() =>
  totalSkus.value ? Math.round((stockHealth.healthy / totalSkus.value) * 100) : 0)
const healthChipColor = computed(() =>
  healthPct.value >= 85 ? 'success' : healthPct.value >= 60 ? 'warning' : 'error')

/** Hero chip tone — inherits the same thresholds as the health panel. */
const healthChipClass = computed(() =>
  healthPct.value >= 85 ? '' : 'ims-hero-chip-alert')

const health = computed(() => {
  if (!totalSkus.value) return { tone: 'ok', label: 'No stock loaded', icon: 'mdi-information-outline' }
  if (healthPct.value >= 85) return { tone: 'ok', label: `Healthy · ${healthPct.value}%`, icon: 'mdi-check-circle' }
  if (healthPct.value >= 60) return { tone: 'low', label: `Needs review · ${healthPct.value}%`, icon: 'mdi-alert' }
  return { tone: 'out', label: `Critical · ${healthPct.value}%`, icon: 'mdi-alert-octagon' }
})

const healthSegments = computed(() => [
  { value: stockHealth.healthy, color: '#22c55e', label: 'Healthy' },
  { value: stockHealth.low, color: '#f59e0b', label: 'Low' },
  { value: stockHealth.out, color: '#ef4444', label: 'Out' }
])

const healthLegend = computed(() => {
  const t = Math.max(totalSkus.value, 1)
  const pct = n => `${Math.round((n / t) * 100)}%`
  return [
    { label: 'Healthy', count: stockHealth.healthy, color: '#22c55e', pct: pct(stockHealth.healthy) },
    { label: 'Low stock', count: stockHealth.low, color: '#f59e0b', pct: pct(stockHealth.low) },
    { label: 'Out of stock', count: stockHealth.out, color: '#ef4444', pct: pct(stockHealth.out) }
  ]
})

// ── Net flow ─────────────────────────────────────────────────────────────
const netChange = computed(() =>
  Number(flowKpis.net_change ?? (Number(flowKpis.total_in || 0) - Number(flowKpis.total_out || 0))))

// ── Ops pulse ────────────────────────────────────────────────────────────
// Shortfall = units needed to lift every flagged item back over its reorder
// level (an out-of-stock item is short a full reorder quantity).
const shortfall = computed(() => {
  let units = 0
  for (const s of lowStock.value) {
    const q = Number(s.total_quantity || 0)
    if (q <= 0) units += Number(s.reorder_quantity || s.reorder_level || 0)
    else units += Math.max(0, Number(s.reorder_level || 0) - q)
  }
  return units
})

const expiringUnits = computed(() => expiring.value.reduce((s, b) => s + (Number(b.qty) || 0), 0))
const expiringValue = computed(() =>
  expiring.value.reduce((s, b) => s + (Number(b.qty) || 0) * (Number(b.cost_price) || 0), 0))

const pulse = computed(() => [
  {
    icon: health.value.icon,
    tone: healthPct.value >= 85 ? '#16a34a' : healthPct.value >= 60 ? '#d97706' : '#dc2626',
    label: 'Availability',
    value: `${healthPct.value}%`,
    hint: `${num(stockHealth.healthy)} of ${num(totalSkus.value)} SKUs at healthy levels`,
    to: '/ims/inventory/stock-analysis'
  },
  {
    icon: 'mdi-cart-arrow-down',
    tone: stockHealth.low + stockHealth.out ? '#d97706' : '#16a34a',
    label: 'Replenishment',
    value: num(stockHealth.low + stockHealth.out),
    hint: stockHealth.low + stockHealth.out
      ? `${num(shortfall.value)} units short of reorder level`
      : 'every item above its reorder level',
    to: stockHealth.low + stockHealth.out ? '/ims/inventory' : null
  },
  {
    icon: 'mdi-timer-sand',
    tone: expiring.value.length ? '#dc2626' : '#16a34a',
    label: `Expiring ≤${expiryWindow}d`,
    value: num(expiringUnits.value),
    hint: expiring.value.length
      ? `${num(expiring.value.length)} batch${expiring.value.length === 1 ? '' : 'es'} · ${formatMoney(expiringValue.value)} at risk`
      : 'no batches approaching expiry',
    to: expiring.value.length ? '/ims/inventory' : null
  },
  {
    icon: netChange.value >= 0 ? 'mdi-trending-up' : 'mdi-trending-down',
    tone: netChange.value >= 0 ? '#2563eb' : '#dc2626',
    label: 'Net movement',
    value: `${netChange.value > 0 ? '+' : ''}${num(netChange.value)}`,
    hint: `${num(flowKpis.total_in)} in · ${num(flowKpis.total_out)} out`,
    to: '/ims/inventory/stock-movements'
  }
])

// ── Period comparison (vs the previous window) ───────────────────────────
// Processed volume is the honest "are we busier?" signal; value is not
// comparable across periods because prices move.
const periodCompare = computed(() => {
  const prev = previousKpis.value
  if (!prev) return []
  const pct = (cur, before) => {
    const c = Number(cur) || 0
    const b = Number(before) || 0
    if (!b) return c > 0 ? 100 : 0
    return ((c - b) / b) * 100
  }
  return [
    { label: 'Inflow', delta: pct(flowKpis.total_in, prev.total_in) },
    { label: 'Outflow', delta: pct(flowKpis.total_out, prev.total_out) },
    { label: 'Postings', delta: pct(flowKpis.count, prev.count) }
  ].map((r) => ({
    label: r.label,
    value: `${Math.abs(r.delta).toFixed(1)}%`,
    icon: r.delta >= 0 ? 'mdi-arrow-up' : 'mdi-arrow-down',
    good: r.delta >= 0
  }))
})

// ── Stockout forecast ────────────────────────────────────────────────────
// Run rate comes from the movement rollup (units out per item over the same
// window the chart uses), so cover days stay consistent with the KPI strip.
// `coverRows` is every moving item ranked by cover; `stockoutRisk` is the
// subset inside the watch window. Showing the tightest covers even when none
// are technically at risk keeps the panel informative on a healthy tenant.
const COVER_WATCH_DAYS = 21

const coverRows = computed(() => {
  if (!movementItems.value.length) return []
  const byId = new Map()
  for (const it of movementItems.value) {
    if (it.stock_id != null) byId.set(it.stock_id, it)
  }
  const windowDays = Math.max(1, trendDays)
  const rows = []

  for (const s of stocks.value) {
    const mv = byId.get(s.id)
    if (!mv) continue
    const out = Number(mv.out) || 0
    if (out <= 0) continue

    const rate = out / windowDays                 // units consumed per day
    const qty = Number(s.total_quantity) || 0
    const coverDays = rate > 0 ? qty / rate : null

    const severity =
      qty <= 0 ? 'out'
        : coverDays <= 7 ? 'critical'
          : coverDays <= 14 ? 'high'
            : coverDays <= COVER_WATCH_DAYS ? 'watch'
              : 'ok'

    rows.push({
      id: s.id,
      name: s.medication_name,
      qty,
      rate,
      coverDays,
      severity,
      coverRatio: Math.min(1, (coverDays || 0) / COVER_WATCH_DAYS)
    })
  }

  const rank = { out: 0, critical: 1, high: 2, watch: 3, ok: 4 }
  return rows.sort(
    (a, b) => rank[a.severity] - rank[b.severity] || (a.coverDays ?? 0) - (b.coverDays ?? 0)
  )
})

const stockoutRisk = computed(() =>
  coverRows.value.filter((r) => r.severity !== 'ok'))

// ── ABC value concentration ──────────────────────────────────────────────
// Classic Pareto: class A covers the stock lines that make up the first 70%
// of capital, B the next 20%, and C the long tail.
const abc = computed(() => {
  const rows = stocks.value
    .map((s) => ({
      id: s.id,
      value: (Number(s.total_quantity) || 0) * (Number(s.cost_price) || 0)
    }))
    .filter((r) => r.value > 0)
    .sort((a, b) => b.value - a.value)

  const total = rows.reduce((n, r) => n + r.value, 0)
  if (!total || !rows.length) return { classes: [], totalValue: 0, insight: '' }

  const acc = {
    A: { count: 0, value: 0, label: 'Class A · high value', color: '#7c3aed' },
    B: { count: 0, value: 0, label: 'Class B · mid value', color: '#0ea5e9' },
    C: { count: 0, value: 0, label: 'Class C · long tail', color: '#94a3b8' }
  }

  let cumulative = 0
  for (const r of rows) {
    const shareBefore = cumulative / total
    const key = shareBefore < 0.7 ? 'A' : shareBefore < 0.9 ? 'B' : 'C'
    acc[key].count += 1
    acc[key].value += r.value
    cumulative += r.value
  }

  const classes = ['A', 'B', 'C'].map((key) => ({
    key,
    label: acc[key].label,
    color: acc[key].color,
    count: acc[key].count,
    value: acc[key].value,
    valueShare: Math.round((acc[key].value / total) * 100)
  }))

  const a = acc.A
  const c = acc.C
  const insight = a.count
    ? `Class A is just ${a.count} SKU${a.count === 1 ? '' : 's'} (${Math.round(
      (a.count / rows.length) * 100
    )}% of the catalogue) but holds ${Math.round((a.value / total) * 100)}% of the capital. Cycle-count those first; the ${c.count}-SKU long tail can wait.`
    : `Capital is evenly spread across ${rows.length} SKUs.`

  return { classes, totalValue: total, insight }
})

// ── Idle capital ─────────────────────────────────────────────────────────
// Any valued item that neither received nor issued stock in the window.
const idleCapital = computed(() => {
  const moved = new Set()
  for (const it of movementItems.value) {
    if (it.stock_id == null) continue
    if ((Number(it.out) || 0) > 0 || (Number(it.in) || 0) > 0) moved.add(it.stock_id)
  }

  let totalValue = 0
  const items = []
  for (const s of stocks.value) {
    const qty = Number(s.total_quantity) || 0
    const value = qty * (Number(s.cost_price) || 0)
    totalValue += value
    if (qty <= 0 || value <= 0 || moved.has(s.id)) continue
    items.push({
      id: s.id,
      name: s.medication_name,
      qty,
      unit: s.unit_abbreviation || s.unit_name,
      value
    })
  }

  items.sort((a, b) => b.value - a.value)
  const value = items.reduce((n, i) => n + i.value, 0)
  const units = items.reduce((n, i) => n + i.qty, 0)
  return {
    items,
    value,
    units,
    sharePct: totalValue > 0 ? Math.round((value / totalValue) * 100) : 0
  }
})

// ── Warehouse comparison ─────────────────────────────────────────────────
const branchBreakdown = computed(() => {
  const map = new Map()
  for (const s of stocks.value) {
    const name = s.branch_name || 'Unassigned'
    const d = map.get(name) || { name, value: 0, skus: 0, healthy: 0, flagged: 0 }
    const qty = Number(s.total_quantity) || 0
    d.value += qty * (Number(s.cost_price) || 0)
    d.skus += 1
    if (qty <= 0 || s.is_low_stock) d.flagged += 1
    else d.healthy += 1
    map.set(name, d)
  }

  const rows = [...map.values()].sort((a, b) => b.value - a.value)
  const max = rows[0]?.value || 1
  return rows.map((r, i) => ({
    ...r,
    valuePct: Math.max(3, (r.value / max) * 100),
    healthPct: r.skus ? Math.round((r.healthy / r.skus) * 100) : 0,
    color: barColors[i % barColors.length],
    flags: r.flagged ? `${r.flagged} flagged` : ''
  }))
})

// ── Expiry runway (month buckets) ────────────────────────────────────────
const expiryRunway = computed(() => {
  const now = new Date()
  now.setHours(0, 0, 0, 0)

  const buckets = []
  for (let i = 0; i < runwayMonths; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() + i, 1)
    buckets.push({
      key: `${d.getFullYear()}-${d.getMonth()}`,
      label: d.toLocaleDateString(undefined, { month: 'short' }),
      units: 0,
      value: 0,
      soon: i <= 1
    })
  }

  for (const s of stocks.value) {
    const cost = Number(s.cost_price) || 0
    for (const b of (s.batches || [])) {
      const qty = Number(b.quantity_remaining) || 0
      if (qty <= 0 || !b.expiry_date) continue
      const exp = new Date(b.expiry_date)
      if (Number.isNaN(exp.getTime())) continue
      const offset =
        (exp.getFullYear() - now.getFullYear()) * 12 + (exp.getMonth() - now.getMonth())
      if (offset < 0 || offset >= runwayMonths) continue
      buckets[offset].units += qty
      buckets[offset].value += qty * cost
    }
  }

  const max = Math.max(...buckets.map((b) => b.units), 1)
  return buckets.map((b) => ({ ...b, pct: (b.units / max) * 100 }))
})

const expiryTotalValue = computed(() =>
  expiryRunway.value.reduce((n, b) => n + b.value, 0))

// ── Snapshot export ──────────────────────────────────────────────────────
// A one-click CSV of everything on the page, for the weekly ops review.
function exportSnapshot() {
  if (!import.meta.client) return
  const rows = [
    ['Warehouse operations snapshot', new Date().toISOString().slice(0, 19).replace('T', ' ')],
    ['Tenant', auth.tenantName || ''],
    ['Branch', branchLabel.value],
    [],
    ['KPI', 'Value'],
    ...kpis.value.map((k) => [k.title, k.value]),
    [],
    ['Stock health', 'Count'],
    ['Healthy', stockHealth.healthy],
    ['Low stock', stockHealth.low],
    ['Out of stock', stockHealth.out],
    [],
    ['Stockout forecast', 'On hand', 'Daily use', 'Days of cover', 'Status'],
    ...coverRows.value.map((s) => [
      s.name,
      s.qty,
      s.rate.toFixed(2),
      s.coverDays == null ? '' : s.coverDays.toFixed(1),
      s.severity
    ]),
    [],
    ['ABC class', 'SKUs', 'Value', '% of value'],
    ...abc.value.classes.map((c) => [c.key, c.count, c.value.toFixed(2), c.valueShare]),
    [],
    ['Warehouse', 'SKUs', 'Value', 'Healthy %'],
    ...branchBreakdown.value.map((b) => [b.name, b.skus, b.value.toFixed(2), b.healthPct]),
    [],
    ['Expiry month', 'Units', 'Value'],
    ...expiryRunway.value.map((m) => [m.label, m.units, m.value.toFixed(2)]),
    [],
    ['Idle capital', 'Units', 'Value'],
    ...idleCapital.value.items.map((i) => [i.name, i.qty, i.value.toFixed(2)])
  ]

  const csv = rows
    .map((line) => line.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `ims-snapshot-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

// ── Attention queues ─────────────────────────────────────────────────────
const queues = computed(() => [
  {
    key: 'low', title: 'Low / out of stock', sub: 'Below reorder level',
    icon: 'mdi-alert-outline', count: lowStock.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'All items stocked',
    items: lowStock.value,
    moreTo: '/ims/inventory',
    titleOf: s => s.medication_name,
    subOf: s => `${num(s.total_quantity)} on hand · reorder at ${num(s.reorder_level)}`,
    linkOf: s => `/ims/inventory/stocks/${s.id}/edit`,
    badgeOf: s => (Number(s.total_quantity || 0) <= 0 ? 'OUT' : 'LOW')
  },
  {
    key: 'expiring', title: 'Expiring batches', sub: `Within ${expiryWindow} days`,
    icon: 'mdi-clock-alert-outline', count: expiring.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'No batches expiring soon',
    items: expiring.value,
    moreTo: '/ims/inventory',
    titleOf: b => b.name,
    subOf: b => `Batch ${b.batch_number || '—'} · expires ${formatDate(b.expiry_date)}`,
    linkOf: b => `/ims/inventory/stocks/${b.stockId}/edit`,
    badgeOf: b => `${num(b.qty)} left`
  },
  {
    key: 'po', title: 'Open purchase orders', sub: 'Draft, sent or partially received',
    icon: 'mdi-cart-arrow-down', count: openPOs.value.length,
    emptyIcon: 'mdi-check-circle', emptyTitle: 'No open purchase orders',
    items: openPOs.value,
    moreTo: '/ims/purchase-orders',
    titleOf: o => o.po_number || `PO #${o.id}`,
    subOf: o => `${o.supplier_name || 'Supplier'} · ${formatMoney(o.total_cost)}`,
    linkOf: o => `/ims/purchase-orders/${o.id}`,
    badgeOf: o => o.status || ''
  }
])

const actions = computed(() => [
  { icon: 'mdi-plus-circle', label: 'Add Stock Item', to: '/ims/inventory/stocks/new', tone: '#2563eb' },
  { icon: 'mdi-clipboard-list-outline', label: 'Stock Take', to: '/ims/inventory/stock-take', tone: '#0d9488' },
  { icon: 'mdi-cart', label: 'Purchase Orders', to: '/ims/purchase-orders', tone: '#d97706' },
  { icon: 'mdi-truck-delivery-outline', label: 'Transfers', to: '/ims/inventory/transfers', tone: '#7c3aed' },
  { icon: 'mdi-swap-vertical-bold', label: 'Movements', to: '/ims/inventory/stock-movements', tone: '#0ea5e9' },
  { icon: 'mdi-chart-line', label: 'Stock Analysis', to: '/ims/inventory/stock-analysis', tone: '#16a34a' },
  { icon: 'mdi-file-excel', label: 'Excel Tools', to: '/ims/inventory/excel', tone: '#15803d' },
  { icon: 'mdi-file-chart', label: 'Reports', to: '/ims/reports', tone: '#4f46e5' }
].filter(a => canAccessRoute(auth.role, a.to)))

// ── Helpers ──────────────────────────────────────────────────────────────
function formatRelative(v) {
  if (!v) return ''
  const d = new Date(v)
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}

function movementIcon(direction) {
  if (direction === 'inflow') return 'mdi-arrow-down'
  if (direction === 'outflow') return 'mdi-arrow-up'
  return 'mdi-swap-horizontal'
}

// `>=` cannot appear in a template binding, so the comparison lives here.
function varianceTone(c) {
  const v = Number(c.total_variance || 0)
  if (v === 0) return 'text-medium-emphasis'
  return v < 0 ? 'text-error' : 'text-success'
}
function varianceLabel(c) {
  const v = Number(c.total_variance || 0)
  return v > 0 ? `+${num(v)}` : num(v)
}

async function load() {
  loading.value = true
  const safeGet = (p) => $api.get(p).then(r => r.data).catch(() => null)
  const safeList = (p) => safeGet(p).then(d => d?.results || (Array.isArray(d) ? d : []))

  const bid = branchStore.currentBranchId
  const bp = bid ? `&branch_id=${bid}` : ''
  const bpStocks = bid ? `&branch=${bid}` : ''

  const end = new Date()
  const start = new Date(end.getTime() - (trendDays - 1) * 86400000)
  // Previous window of identical length, for the "vs previous 30d" deltas.
  const prevEnd = new Date(start.getTime() - 86400000)
  const prevStart = new Date(prevEnd.getTime() - (trendDays - 1) * 86400000)
  const iso = (d) => d.toISOString().slice(0, 10)

  const [an, st, mv, po, tr, cnt, prevMv] = await Promise.all([
    safeGet(`/inventory/analytics/${bid ? `?branch_id=${bid}` : ''}`),
    safeList(`/inventory/stocks/?page_size=1000${bpStocks}`),
    safeGet(`/inventory/stock-movements/?date_from=${iso(start)}&date_to=${iso(end)}${bp}`),
    safeList(`/purchase-orders/?page_size=100${bid ? `&branch=${bid}` : ''}`),
    safeList(`/inventory/transfers/?page_size=100${bid ? `&branch=${bid}` : ''}`),
    safeList(`/inventory/counts/?page_size=100${bid ? `&branch=${bid}` : ''}`),
    safeGet(`/inventory/stock-movements/?date_from=${iso(prevStart)}&date_to=${iso(prevEnd)}${bp}`),
  ])

  analytics.value = an
  stocks.value = st

  // Stock health + low stock
  let healthy = 0, low = 0, out = 0
  const lowList = []
  for (const s of stocks.value) {
    const q = Number(s.total_quantity || 0)
    if (q <= 0) { out++; lowList.push(s) }
    else if (s.is_low_stock) { low++; lowList.push(s) }
    else healthy++
  }
  stockHealth.healthy = healthy
  stockHealth.low = low
  stockHealth.out = out
  lowStock.value = lowList.sort((a, b) => (Number(a.total_quantity) || 0) - (Number(b.total_quantity) || 0))

  // Expiring batches (next 90 days, from stock batches)
  const soon = new Date(); soon.setDate(soon.getDate() + expiryWindow)
  const expList = []
  for (const s of stocks.value) {
    for (const b of (s.batches || [])) {
      if (b.quantity_remaining > 0 && b.expiry_date && new Date(b.expiry_date) <= soon) {
        expList.push({
          stockId: s.id, name: s.medication_name, batch_number: b.batch_number,
          expiry_date: b.expiry_date, qty: b.quantity_remaining,
          cost_price: s.cost_price,
        })
      }
    }
  }
  expiring.value = expList.sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date))

  // Top items by stock value (at cost)
  const byValue = stocks.value
    .map(s => ({
      name: s.medication_name,
      qty: Number(s.total_quantity || 0),
      unit: s.unit_abbreviation || s.unit_name,
      value: (Number(s.total_quantity) || 0) * (Number(s.cost_price) || 0),
    }))
    .filter(p => p.value > 0)
    .sort((a, b) => b.value - a.value)
    .slice(0, 6)
  const maxVal = byValue[0]?.value || 1
  topValueItems.value = byValue.map((p, i) => ({
    ...p,
    pct: (p.value / maxVal) * 100,
    color: barColors[i % barColors.length]
  }))

  // Stock flow trend
  if (mv) {
    Object.assign(flowKpis, mv.kpis || {})
    movementItems.value = mv.items || []
    const trend = mv.trend || []
    const active = trend
      .map(d => ({
        label: new Date(d.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }),
        inflow: (d.inflow || 0) + (d.transfer || 0),
        outflow: d.outflow || 0,
      }))
      .filter(d => d.inflow > 0 || d.outflow > 0)
    trendLabels.value = active.map(d => d.label)
    inflowValues.value = active.map(d => d.inflow)
    outflowValues.value = active.map(d => d.outflow)
    recentMovements.value = (mv.movements || [])
      .slice()
      .sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0))
      .slice(0, 8)
  }

  previousKpis.value = prevMv?.kpis || null

  // Open POs (draft / sent / partially received)
  openPOs.value = (po || []).filter(o => ['draft', 'sent', 'partial'].includes(o.status))

  // Transfers + counts
  recentTransfers.value = (tr || []).slice(0, 6)
  recentCounts.value = (cnt || []).slice(0, 6)

  loading.value = false
}

onMounted(() => {
  // Deep-linking straight to /ims means nothing has fetched the tenant palette
  // yet (useBranding caches in shared state, so this is a no-op when the
  // inventory list already loaded it).
  brand.load()
  load()
})

watch(() => branchStore.currentBranchId, () => {
  load()
})
</script>

<style scoped>
.ims-dash { max-width: 1600px; margin: 0 auto; }
.ims-nowrap { white-space: nowrap; }

/* ═══════════════ Hero ═══════════════
   var() fallbacks mirror BRAND_DEFAULTS in utils/branding.js so the panel
   still renders if the custom properties are ever missing. */
.ims-hero {
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
.ims-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.ims-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.ims-hero-top { position: relative; }
.ims-hero-icon {
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
.ims-hero-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.ims-hero-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.ims-hero-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.ims-hero-iconbtn { color: #fff !important; }

/* Two explicit action tiers: a saturated gradient washes out tonal fills, so
   the emphasised button paints a white pill with the tenant's darkest brand
   colour as text, and the secondary one is translucent glass. */
.ims-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.ims-hero-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
}
.ims-hero-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.ims-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.ims-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.ims-hero-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
.ims-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.ims-hero-chip {
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
.ims-hero-chip-alert {
  background: rgba(239, 68, 68, 0.3);
  border-color: rgba(255, 255, 255, 0.45);
}

/* ═══════════════ KPI cards ═══════════════
   Tone travels via `color`, so the top rail, the icon chip and the mini share
   bar can all derive from currentColor. */
.ims-kpi {
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
.ims-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  background: currentColor;
  opacity: 0.85;
}
.ims-kpi:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1); }
.ims-kpi-link { cursor: pointer; }
.ims-kpi-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: currentColor;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.ims-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}
.ims-kpi-value {
  font-size: 21px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  margin-top: 1px;
}
.ims-kpi-foot {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
  margin-top: 2px;
}
.ims-kpi-bars { height: 4px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.ims-kpi-bars span { display: block; height: 100%; border-radius: 999px; background: currentColor; }

/* Per-KPI hues. The `t-` infix keeps these distinct from `.ims-kpi-value`,
   which is the inner value *text* class — without it every KPI number picks up
   the green tone rule. */
.ims-kpi-t-skus { color: #2563eb; }
.ims-kpi-t-value { color: #16a34a; }
.ims-kpi-t-units { color: #0d9488; }
.ims-kpi-t-low { color: #d97706; }
.ims-kpi-t-out { color: #dc2626; }
.ims-kpi-t-expiring { color: #7c3aed; }

/* ═══════════════ Ops pulse ═══════════════ */
.ims-pulse {
  border-radius: 16px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  overflow: hidden;
}
.ims-pulse-head {
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
.ims-pulse-compare {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  text-transform: none;
  letter-spacing: 0;
}
.ims-compare-label {
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.ims-compare {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.2px;
}
.ims-compare-up { color: #15803d; background: rgba(34, 197, 94, 0.12); }
.ims-compare-down { color: #64748b; background: rgba(100, 116, 139, 0.12); }
.ims-pulse-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
.ims-pulse-tile {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
  color: inherit;
  text-decoration: none;
  border-left: 1px solid rgba(15, 23, 42, 0.07);
  transition: background 0.16s ease;
}
.ims-pulse-tile:first-child { border-left: none; }
.ims-pulse-link { cursor: pointer; }
.ims-pulse-link:hover { background: rgba(var(--v-theme-primary), 0.045); }
.ims-pulse-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--pulse-tone, #2563eb);
  background: color-mix(in srgb, var(--pulse-tone, #2563eb) 14%, transparent);
}
.ims-pulse-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.ims-pulse-value {
  font-size: 20px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.4px;
  color: var(--pulse-tone, #2563eb);
}
.ims-pulse-hint {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.35;
  margin-top: 1px;
}

/* ═══════════════ Panels ═══════════════
   Each panel carries a very faint brand wash at the top so the cards read as
   curated sections rather than flat white boxes, without competing with the
   data. */
.ims-panel {
  position: relative;
  border-color: rgba(15, 23, 42, 0.08) !important;
  background:
    linear-gradient(180deg, rgba(var(--v-theme-primary), 0.03) 0%, transparent 110px),
    rgb(var(--v-theme-surface)) !important;
  transition: box-shadow 0.18s ease, transform 0.18s ease;
}
.ims-panel:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 26px rgba(15, 23, 42, 0.08);
}
.ims-panel-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: -0.1px;
}
.ims-panel-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--panel-tone, #2563eb);
  background: color-mix(in srgb, var(--panel-tone, #2563eb) 14%, transparent);
}

/* Flow stats */
.ims-flowstat {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 66px;
  padding: 5px 10px;
  border-radius: 10px;
  line-height: 1.2;
}
.ims-flowstat-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  opacity: 0.7;
}
.ims-flowstat-value { font-size: 15px; font-weight: 800; }
.ims-flowstat-in { background: rgba(34, 197, 94, 0.12); color: #15803d; }
.ims-flowstat-out { background: rgba(239, 68, 68, 0.12); color: #b91c1c; }
.ims-flowstat-net { background: rgba(14, 165, 233, 0.12); color: #0369a1; }

/* Shared legend */
.ims-legend { display: flex; align-items: center; gap: 8px; padding: 5px 0; }
.ims-legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}
.ims-legend-pct { min-width: 34px; text-align: right; }

/* Ranked bars */
.ims-rank {
  width: 20px;
  height: 20px;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 10.5px;
  font-weight: 800;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.ims-bar-track { height: 7px; border-radius: 999px; background: rgba(15, 23, 42, 0.07); overflow: hidden; }
.ims-bar-track span { display: block; height: 100%; border-radius: 999px; }

/* ═══════════════ Stockout forecast ═══════════════ */
.ims-risk-head,
.ims-risk-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 74px 86px 62px;
  gap: 10px;
  align-items: center;
}
.ims-risk-head {
  padding: 0 8px 7px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}
.ims-risk-row {
  position: relative;
  padding: 9px 8px 11px;
  border-radius: 8px;
  color: inherit;
  text-decoration: none;
  font-size: 13px;
  transition: background 0.14s ease;
}
.ims-risk-row:hover { background: rgba(var(--v-theme-primary), 0.05); }
.ims-risk-name {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.ims-risk-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.ims-risk-out { background: #991b1b; box-shadow: 0 0 0 3px rgba(153, 27, 27, 0.16); }
.ims-risk-critical { background: #dc2626; box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.14); }
.ims-risk-high { background: #f59e0b; box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.14); }
.ims-risk-watch { background: #0ea5e9; box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.14); }
.ims-risk-ok { background: #22c55e; box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.14); }
.ims-cover {
  display: inline-block;
  min-width: 42px;
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 800;
  text-align: center;
}
.ims-cover-out { color: #fff; background: #991b1b; }
.ims-cover-critical { color: #b91c1c; background: rgba(239, 68, 68, 0.14); }
.ims-cover-high { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.ims-cover-watch { color: #0369a1; background: rgba(14, 165, 233, 0.14); }
.ims-cover-ok { color: #15803d; background: rgba(34, 197, 94, 0.14); }
.ims-risk-bar {
  grid-column: 1 / -1;
  display: block;
  height: 3px;
  margin-top: -3px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  overflow: hidden;
}
.ims-risk-bar span { display: block; height: 100%; border-radius: 999px; }
.ims-risk-fill-out { background: #991b1b; }
.ims-risk-fill-critical { background: #ef4444; }
.ims-risk-fill-high { background: #f59e0b; }
.ims-risk-fill-watch { background: #0ea5e9; }
.ims-risk-fill-ok { background: #22c55e; }

/* ═══════════════ ABC concentration ═══════════════ */
.ims-abc-bar {
  display: flex;
  height: 14px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(15, 23, 42, 0.06);
}
.ims-abc-bar span { display: block; height: 100%; transition: width 0.3s ease; }
.ims-abc-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.ims-abc-key {
  width: 24px;
  height: 24px;
  border-radius: 8px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 800;
  color: #fff;
}
.ims-abc-val {
  font-size: 12.5px;
  font-weight: 700;
  white-space: nowrap;
}

/* ═══════════════ Warehouse comparison ═══════════════ */
.ims-branch + .ims-branch { margin-top: 12px; }
.ims-branch-flags {
  font-weight: 700;
  color: #b45309;
}

/* ═══════════════ Expiry runway ═══════════════ */
.ims-runway {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  height: 132px;
  padding-top: 6px;
}
.ims-runway-col {
  flex: 1 1 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 0;
}
.ims-runway-value {
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-bottom: 3px;
  white-space: nowrap;
}
.ims-runway-bar-wrap {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.ims-runway-bar {
  width: 70%;
  max-width: 34px;
  border-radius: 6px 6px 3px 3px;
  background: linear-gradient(180deg, #fbbf24, #f59e0b);
  transition: height 0.3s ease;
}
.ims-runway-bar-soon { background: linear-gradient(180deg, #f87171, #dc2626); }
.ims-runway-label {
  margin-top: 6px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ═══════════════ Idle capital ═══════════════ */
.ims-mini-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.ims-mini-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.3px;
}
.ims-badge-neutral {
  color: rgba(var(--v-theme-on-surface), 0.7) !important;
  background: rgba(var(--v-theme-on-surface), 0.07) !important;
}

/* ═══════════════ Attention queues ═══════════════ */
.ims-queue { position: relative; overflow: hidden; border-color: rgba(15, 23, 42, 0.08); }
.ims-queue::after {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--queue-tone, #2563eb);
}
.ims-queue-low { --queue-tone: #d97706; }
.ims-queue-expiring { --queue-tone: #dc2626; }
.ims-queue-po { --queue-tone: #4f46e5; }

.ims-queue-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.07);
}
.ims-queue-icon {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 14%, transparent);
}
.ims-queue-count {
  margin-left: auto;
  height: 24px;
  padding: 0 10px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12.5px;
  font-weight: 800;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 13%, transparent);
}
.ims-queue-body { padding: 12px 16px 16px; }

/* Generic list row — used by the queues. */
.ims-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 10px;
  color: inherit;
  text-decoration: none;
  transition: background 0.14s ease;
}
.ims-row-link { cursor: pointer; }
.ims-row-link:hover { background: rgba(var(--v-theme-primary), 0.06); }
.ims-row-main { min-width: 0; flex: 1 1 auto; }
.ims-row-title { font-size: 13.5px; font-weight: 600; line-height: 1.3; }
.ims-row-sub { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.6); line-height: 1.3; }
.ims-row-badge {
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.5px;
  padding: 2px 8px;
  border-radius: 999px;
  color: var(--queue-tone, #2563eb);
  background: color-mix(in srgb, var(--queue-tone, #2563eb) 13%, transparent);
}
.ims-row-more {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  font-weight: 600;
  color: rgb(var(--v-theme-primary));
  text-decoration: none;
  padding: 2px 10px;
}
.ims-row-more:hover { text-decoration: underline; }

/* Movements */
.ims-movement {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 7px 4px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.055);
}
.ims-movement:last-child { border-bottom: none; }
.ims-movement-dot {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.ims-mv-inflow { background: rgba(34, 197, 94, 0.14); color: #15803d; }
.ims-mv-outflow { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.ims-mv-transfer { background: rgba(14, 165, 233, 0.14); color: #0369a1; }
.ims-movement-qty { font-size: 13.5px; font-weight: 800; white-space: nowrap; }
.ims-mv-text-inflow { color: #15803d; }
.ims-mv-text-outflow { color: #b91c1c; }
.ims-mv-text-transfer { color: #0369a1; }

/* ═══════════════ Compact tables ═══════════════ */
.ims-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13.5px; }
.ims-table th {
  text-align: left;
  padding: 8px 10px;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  border-bottom: 1px solid rgba(15, 23, 42, 0.1);
  white-space: nowrap;
}
.ims-table td {
  padding: 9px 10px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  white-space: nowrap;
}
.ims-table tbody tr:last-child td { border-bottom: none; }
.ims-table tbody tr { transition: background 0.14s ease; }
.ims-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.045); }

/* ═══════════════ Quick actions ═══════════════ */
.ims-actions { display: grid; grid-template-columns: repeat(auto-fit, minmax(175px, 1fr)); gap: 10px; }
.ims-action {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  color: rgba(var(--v-theme-on-surface), 0.87);
  font-size: 13.5px;
  font-weight: 600;
  text-decoration: none;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease,
    background 0.16s ease;
}
.ims-action :deep(.v-icon) {
  flex-shrink: 0;
  width: 30px;
  height: 30px;
  padding: 7px;
  border-radius: 9px;
  color: var(--act-tone, #2563eb);
  background: color-mix(in srgb, var(--act-tone, #2563eb) 13%, transparent);
}
.ims-action:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--act-tone, #2563eb) 42%, transparent);
  background: color-mix(in srgb, var(--act-tone, #2563eb) 5%, rgb(var(--v-theme-surface)));
  box-shadow: 0 10px 22px rgba(15, 23, 42, 0.1);
}

@media (max-width: 700px) {
  .ims-hero { padding: 16px 16px 14px; border-radius: 16px; }
  .ims-hero-title { font-size: 21px; }
  .ims-hero-icon { width: 48px; height: 48px; border-radius: 14px; }
}
</style>
