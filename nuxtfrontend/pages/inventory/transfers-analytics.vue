<template>
  <v-container fluid class="pa-3 pa-md-5 trfa-page">
    <!-- ═══════════════════ HERO ═══════════════════ -->
    <div class="trfa-hero mb-4" :style="heroTheme">
      <span class="trfa-hero-glow" />
      <span class="trfa-hero-glow trfa-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="trfa-hero-icon">
            <v-icon size="30">mdi-chart-box-outline</v-icon>
          </div>
          <div>
            <div class="trfa-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              INVENTORY · LOGISTICS · ANALYTICS
            </div>
            <h1 class="trfa-title">Transfer Analytics</h1>
            <div class="trfa-sub">
              Throughput, cycle time, fill rate and partner performance across every warehouse move
              <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="trfa-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trfa-hero-btn-cta"
            prepend-icon="mdi-file-pdf-box"
            :loading="exportingPdf"
            @click="downloadPdf"
          >PDF Report</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trfa-hero-btn-glass"
            prepend-icon="mdi-file-delimited-outline"
            :loading="exporting"
            @click="exportCsv"
          >Export</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trfa-hero-btn-glass"
            prepend-icon="mdi-arrow-left"
            :to="listPath"
          >Transfers</v-btn>
        </div>
      </div>

      <div class="trfa-hero-facts">
        <div class="trfa-hero-fact">
          <div class="trfa-hero-fact-value">{{ data?.kpis.total ?? 0 }}</div>
          <div class="trfa-hero-fact-label">transfers in scope</div>
        </div>
        <span class="trfa-hero-divider" />
        <div class="trfa-hero-fact">
          <div class="trfa-hero-fact-value">{{ formatMoney(data?.kpis.value ?? 0) }}</div>
          <div class="trfa-hero-fact-label">total value at cost</div>
        </div>
        <span class="trfa-hero-divider" />
        <div class="trfa-hero-fact">
          <div class="trfa-hero-fact-value">{{ fmtPct(data?.kpis.fill_rate_pct) }}</div>
          <div class="trfa-hero-fact-label">fill rate</div>
        </div>
        <span class="trfa-hero-divider trfa-hero-divider-lg" />
        <div class="trfa-hero-fact">
          <div class="trfa-hero-fact-value">{{ fmtHours(data?.kpis.avg_cycle_hours) }}</div>
          <div class="trfa-hero-fact-label">avg cycle</div>
        </div>
      </div>
    </div>

    <!-- ═══════════════════ FILTER BAR ═══════════════════ -->
    <v-card rounded="xl" border class="mb-4 trfa-filterbar">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <div class="d-flex align-center ga-2">
          <v-icon size="17" color="primary">mdi-filter-variant</v-icon>
          <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing:.06em">
            Filters
          </span>
        </div>

        <v-chip-group v-model="rangePreset" mandatory selected-class="text-primary" class="trfa-presets">
          <v-chip
            v-for="p in rangePresets"
            :key="p.value"
            :value="p.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
            @click="applyPreset(p.value)"
          >{{ p.label }}</v-chip>
        </v-chip-group>

        <v-spacer class="d-none d-md-flex" />

        <v-select
          v-model="granularity"
          :items="granularityOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          class="trfa-select"
          prepend-inner-icon="mdi-calendar-range"
          @update:model-value="load"
        />
        <v-select
          v-model="branchFilter"
          :items="branchOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          class="trfa-select"
          prepend-inner-icon="mdi-warehouse"
          @update:model-value="load"
        />
      </div>
    </v-card>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-4" rounded />

    <!-- ═══════════════════ KPI STRIP ═══════════════════ -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile
          :title="k.title"
          :value="k.value"
          :sub="k.sub"
          :icon="k.icon"
          :color="k.color"
          :delta="k.delta"
          delta-label=""
          flat
        />
      </v-col>
    </v-row>

    <v-row dense>
      <!-- ═════════ TREND ═════════ -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Transfer volume &amp; value</div>
              <div class="text-caption text-medium-emphasis">
                Created vs. completed per {{ granularity }}, with value at cost
              </div>
            </div>
            <div class="d-flex align-center flex-wrap ga-3">
              <div v-for="l in trendLegend" :key="l.label" class="d-flex align-center ga-1">
                <span class="trfa-dot" :style="{ background: l.hex }" />
                <span class="text-caption text-medium-emphasis">{{ l.label }}</span>
              </div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-if="!trend.length" class="trfa-empty">
              <v-icon size="34" color="grey-lighten-1">mdi-chart-timeline-variant</v-icon>
              <div class="mt-2 text-body-2 font-weight-medium">No activity in this window</div>
              <div class="text-caption text-medium-emphasis">Widen the date range to see history.</div>
            </div>
            <template v-else>
              <div class="trfa-trend-wrap">
                <div class="trfa-trend-grid" aria-hidden="true">
                  <span v-for="i in 4" :key="i" />
                </div>
                <div class="trfa-trend-bars">
                  <div
                    v-for="(b, i) in trend"
                    :key="b.date"
                    class="trfa-trend-col"
                    :class="{ 'is-active': i === trendHover }"
                    @mouseenter="trendHover = i"
                    @mouseleave="trendHover = -1"
                  >
                    <div class="trfa-trend-stack">
                      <div
                        class="trfa-trend-bar trfa-trend-created"
                        :style="{ height: (b.created / trendMax * 100) + '%' }"
                        :title="`${b.label} · ${b.created} created`"
                      />
                      <div
                        class="trfa-trend-bar trfa-trend-completed"
                        :style="{ height: (b.completed / trendMax * 100) + '%' }"
                        :title="`${b.label} · ${b.completed} completed`"
                      />
                      <div
                        v-if="b.cancelled"
                        class="trfa-trend-bar trfa-trend-cancelled"
                        :style="{ height: (b.cancelled / trendMax * 100) + '%' }"
                        :title="`${b.label} · ${b.cancelled} cancelled`"
                      />
                    </div>
                    <div class="trfa-trend-label">
                      {{ i % labelStride === 0 ? shortLabel(b) : '' }}
                    </div>
                    <div v-if="i === trendHover" class="trfa-trend-tip">
                      <div class="trfa-trend-tip-title">{{ b.label }}</div>
                      <div><span>Created</span><strong>{{ b.created }}</strong></div>
                      <div><span>Completed</span><strong>{{ b.completed }}</strong></div>
                      <div v-if="b.cancelled"><span>Cancelled</span><strong>{{ b.cancelled }}</strong></div>
                      <div><span>Units</span><strong>{{ formatQty(b.units) }}</strong></div>
                      <div><span>Value</span><strong>{{ formatMoney(b.value) }}</strong></div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="trfa-trend-foot">
                <div>
                  <div class="text-caption text-medium-emphasis">Peak bucket</div>
                  <div class="text-body-2 font-weight-bold">{{ peakBucket.label }} · {{ peakBucket.created }} created</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Value in window</div>
                  <div class="text-body-2 font-weight-bold">{{ formatMoney(trendValueTotal) }}</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Units moved</div>
                  <div class="text-body-2 font-weight-bold">{{ formatQty(trendUnitsTotal) }}</div>
                </div>
              </div>
            </template>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ STATUS DONUT ═════════ -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Pipeline mix</div>
            <div class="text-caption text-medium-emphasis">Where every transfer sits today</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="d-flex justify-center">
              <DonutRing :segments="statusSegments" :size="190" :thickness="17">
                <div class="text-center">
                  <div class="trfa-donut-value">{{ data?.kpis.total ?? 0 }}</div>
                  <div class="text-caption text-medium-emphasis">transfers</div>
                </div>
              </DonutRing>
            </div>
            <div class="mt-4">
              <div v-for="s in statusRows" :key="s.status" class="trfa-legend-row">
                <span class="trfa-dot" :style="{ background: s.hex }" />
                <span class="text-body-2 flex-grow-1">{{ s.label }}</span>
                <span class="text-body-2 font-weight-bold">{{ s.count }}</span>
                <span class="trfa-legend-pct">{{ s.pct }}%</span>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="trfa-mini-grid">
              <div class="trfa-mini">
                <div class="trfa-mini-value">{{ fmtPct(data?.kpis.completion_pct) }}</div>
                <div class="trfa-mini-label">completion rate</div>
              </div>
              <div class="trfa-mini">
                <div class="trfa-mini-value">{{ fmtPct(data?.kpis.cancel_pct) }}</div>
                <div class="trfa-mini-label">cancellation</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ SERVICE QUALITY ═════════ -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Service quality</div>
            <div class="text-caption text-medium-emphasis">Accuracy, punctuality and speed</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="trfa-quality">
              <div class="trfa-quality-tile trfa-q-good">
                <div class="trfa-quality-value">{{ fmtPct(data?.kpis.fill_rate_pct) }}</div>
                <div class="trfa-quality-label">fill rate</div>
                <div class="trfa-quality-sub">{{ formatQty(data?.kpis.received_units) }} / {{ formatQty(data?.kpis.sent_units) }} units</div>
              </div>
              <div class="trfa-quality-tile" :class="onTimeTone">
                <div class="trfa-quality-value">{{ data?.kpis.on_time_pct == null ? '—' : fmtPct(data.kpis.on_time_pct) }}</div>
                <div class="trfa-quality-label">on-time delivery</div>
                <div class="trfa-quality-sub">
                  {{ data?.kpis.on_time_pct == null ? 'no ETA set' : 'vs scheduled delivery' }}
                </div>
              </div>
              <div class="trfa-quality-tile trfa-q-info">
                <div class="trfa-quality-value">{{ fmtHours(data?.kpis.avg_approval_hours) }}</div>
                <div class="trfa-quality-label">to approve</div>
                <div class="trfa-quality-sub">request → dispatch</div>
              </div>
              <div class="trfa-quality-tile trfa-q-info">
                <div class="trfa-quality-value">{{ fmtHours(data?.kpis.avg_transit_hours) }}</div>
                <div class="trfa-quality-label">in transit</div>
                <div class="trfa-quality-sub">dispatch → receipt</div>
              </div>
            </div>
            <v-divider class="my-4" />
            <div class="trfa-kv"><span>Units moved</span><strong>{{ formatQty(data?.kpis.units) }}</strong></div>
            <div class="trfa-kv"><span>Line items</span><strong>{{ formatQty(data?.kpis.items) }}</strong></div>
            <div class="trfa-kv"><span>Discrepancies</span><strong>{{ data?.kpis.discrepancy_count ?? 0 }}</strong></div>
            <div class="trfa-kv"><span>Completed this month</span><strong>{{ data?.kpis.completed_this_month ?? 0 }}</strong></div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ AGING ═════════ -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Open transfer aging</div>
            <div class="text-caption text-medium-emphasis">Awaiting approval or still in transit</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-for="a in data?.aging || []" :key="a.label" class="mb-3">
              <div class="d-flex justify-space-between text-body-2 mb-1">
                <span>{{ a.label }}</span>
                <span class="d-inline-flex align-center" style="gap:8px">
                  <strong>{{ a.count }}</strong>
                  <span class="text-caption text-medium-emphasis">{{ formatMoney(a.value) }}</span>
                </span>
              </div>
              <v-progress-linear
                :model-value="a.count / agingMax * 100"
                height="8"
                rounded
                :color="agingColor(a.label)"
                bg-color="surface-variant"
              />
            </div>
            <v-alert
              v-if="staleCount"
              type="warning"
              variant="tonal"
              density="compact"
              rounded="lg"
              class="mt-2"
            >
              {{ staleCount }} transfer{{ staleCount === 1 ? '' : 's' }} have been open for 3+ days —
              worth chasing.
            </v-alert>
            <v-alert v-else type="success" variant="tonal" density="compact" rounded="lg" class="mt-2">
              Nothing is aging — open transfers are all recent.
            </v-alert>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ PRIORITY ═════════ -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Priority performance</div>
            <div class="text-caption text-medium-emphasis">Volume and cycle time by urgency</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-if="!priorityRows.length" class="trfa-empty">
              <v-icon size="30" color="grey-lighten-1">mdi-flag-outline</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No priority data yet.</div>
            </div>
            <div v-for="p in priorityRows" :key="p.priority" class="trfa-priority-row">
              <div class="trfa-priority-head">
                <v-chip size="x-small" variant="flat" :color="p.color" class="font-weight-bold">
                  <v-icon size="11" start>{{ p.icon }}</v-icon>{{ p.label }}
                </v-chip>
                <span class="text-caption text-medium-emphasis">{{ p.count }} transfer{{ p.count === 1 ? '' : 's' }}</span>
                <v-spacer />
                <span class="text-body-2 font-weight-bold">{{ formatMoney(p.value) }}</span>
              </div>
              <div class="trfa-priority-meta">
                <span>{{ formatQty(p.units) }} unit{{ p.units === 1 ? '' : 's' }}</span>
                <span class="trfa-sep">·</span>
                <span>cycle {{ fmtHours(p.avg_cycle_hours) }}</span>
                <template v-if="p.on_time_pct != null">
                  <span class="trfa-sep">·</span>
                  <span>{{ fmtPct(p.on_time_pct) }} on time</span>
                </template>
              </div>
              <div class="trfa-priority-track">
                <div
                  class="trfa-priority-fill"
                  :style="{ width: (p.count / priorityMax * 100) + '%', background: p.hex }"
                />
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ TOP ROUTES ═════════ -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Busiest lanes</div>
            <div class="text-caption text-medium-emphasis">Top warehouse-to-warehouse routes</div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!routeRows.length" class="trfa-empty pa-6">
              <v-icon size="30" color="grey-lighten-1">mdi-map-marker-path</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No routes in this window.</div>
            </div>
            <table v-else class="trfa-table">
              <thead>
                <tr>
                  <th>Lane</th>
                  <th class="text-right">Transfers</th>
                  <th class="text-right">Units</th>
                  <th class="text-right">Value</th>
                  <th class="text-right">Transit</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in routeRows" :key="r.route">
                  <td>
                    <div class="trfa-lane">
                      <span class="trfa-lane-chip">{{ r.source }}</span>
                      <v-icon size="13" class="trfa-lane-arrow">mdi-arrow-right</v-icon>
                      <span class="trfa-lane-chip trfa-lane-chip-dest">{{ r.dest }}</span>
                    </div>
                  </td>
                  <td class="text-right font-weight-bold">{{ r.count }}</td>
                  <td class="text-right">{{ formatQty(r.units) }}</td>
                  <td class="text-right">{{ formatMoney(r.value) }}</td>
                  <td class="text-right text-medium-emphasis">{{ fmtHours(r.avg_transit_hours) }}</td>
                </tr>
              </tbody>
            </table>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ WAREHOUSE THROUGHPUT ═════════ -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Warehouse throughput</div>
            <div class="text-caption text-medium-emphasis">Dispatched out vs. received in</div>
          </div>
          <v-divider />
          <v-card-text>
            <div v-if="!warehouseRows.length" class="trfa-empty">
              <v-icon size="30" color="grey-lighten-1">mdi-warehouse</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No warehouse activity yet.</div>
            </div>
            <div v-for="w in warehouseRows" :key="w.branch" class="trfa-wh-row">
              <div class="trfa-wh-head">
                <v-icon size="15" color="primary">mdi-warehouse</v-icon>
                <span class="text-body-2 font-weight-bold">{{ w.branch }}</span>
                <v-spacer />
                <span class="text-caption text-medium-emphasis">{{ w.total }} moves</span>
              </div>
              <div class="trfa-wh-bars">
                <div class="trfa-wh-item">
                  <div class="d-flex justify-space-between text-caption mb-1">
                    <span>Dispatched</span><strong>{{ w.dispatched }}</strong>
                  </div>
                  <v-progress-linear
                    :model-value="w.dispatched / whMax * 100"
                    height="7"
                    rounded
                    color="primary"
                    bg-color="surface-variant"
                  />
                </div>
                <div class="trfa-wh-item">
                  <div class="d-flex justify-space-between text-caption mb-1">
                    <span>Received</span><strong>{{ w.received }}</strong>
                  </div>
                  <v-progress-linear
                    :model-value="w.received / whMax * 100"
                    height="7"
                    rounded
                    color="teal"
                    bg-color="surface-variant"
                  />
                </div>
              </div>
              <div class="trfa-wh-values">
                <span>out {{ formatMoney(w.dispatched_value) }}</span>
                <span class="trfa-sep">·</span>
                <span>in {{ formatMoney(w.received_value) }}</span>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ TOP ITEMS ═════════ -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Most transferred items</div>
            <div class="text-caption text-medium-emphasis">Ranked by units moved</div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!itemRows.length" class="trfa-empty pa-6">
              <v-icon size="30" color="grey-lighten-1">mdi-package-variant-closed</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No item movement yet.</div>
            </div>
            <div v-else class="trfa-items">
              <div v-for="(it, i) in itemRows" :key="it.name" class="trfa-item-row">
                <div class="trfa-item-rank">{{ i + 1 }}</div>
                <div class="trfa-item-body">
                  <div class="trfa-item-top">
                    <span class="trfa-item-name">{{ it.name }}</span>
                    <span class="trfa-item-units">{{ formatQty(it.units) }} units</span>
                  </div>
                  <div class="trfa-item-track">
                    <div
                      class="trfa-item-fill"
                      :style="{ width: (it.units / itemMax * 100) + '%' }"
                    />
                  </div>
                  <div class="trfa-item-meta">
                    <span>{{ formatMoney(it.value) }}</span>
                    <span class="trfa-sep">·</span>
                    <span>{{ it.transfers }} line{{ it.transfers === 1 ? '' : 's' }}</span>
                    <template v-if="it.variance">
                      <span class="trfa-sep">·</span>
                      <span class="trfa-neg">{{ it.variance > 0 ? '+' : '' }}{{ it.variance }} variance</span>
                    </template>
                  </div>
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ PARTNER PERFORMANCE ═════════ -->
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Carrier &amp; driver performance</div>
            <div class="text-caption text-medium-emphasis">Who moves the stock, and how well</div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!partnerRows.length" class="trfa-empty pa-6">
              <v-icon size="30" color="grey-lighten-1">mdi-account-group-outline</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No assignments recorded yet.</div>
            </div>
            <table v-else class="trfa-table">
              <thead>
                <tr>
                  <th>Partner</th>
                  <th class="text-right">Moves</th>
                  <th class="text-right">Units</th>
                  <th class="text-right">Transit</th>
                  <th class="text-right">On time</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="p in partnerRows" :key="p.name">
                  <td>
                    <div class="d-flex align-center ga-2">
                      <v-icon size="15" color="primary">mdi-truck-fast-outline</v-icon>
                      <span class="font-weight-medium">{{ p.name }}</span>
                    </div>
                  </td>
                  <td class="text-right font-weight-bold">{{ p.shipments }}</td>
                  <td class="text-right">{{ formatQty(p.units) }}</td>
                  <td class="text-right text-medium-emphasis">{{ fmtHours(p.avg_transit_hours) }}</td>
                  <td class="text-right">
                    <span v-if="p.on_time_pct == null" class="text-medium-emphasis">—</span>
                    <v-chip
                      v-else
                      size="x-small"
                      variant="tonal"
                      :color="p.on_time_pct >= 90 ? 'success' : p.on_time_pct >= 70 ? 'amber' : 'error'"
                      class="font-weight-bold"
                    >{{ fmtPct(p.on_time_pct) }}</v-chip>
                  </td>
                </tr>
              </tbody>
            </table>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ═════════ DISCREPANCIES ═════════ -->
      <v-col cols="12">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Receipt discrepancies</div>
              <div class="text-caption text-medium-emphasis">Short or over receipts recorded at destination</div>
            </div>
            <v-chip v-if="discrepancies.length" size="small" variant="tonal" color="error" class="font-weight-bold">
              {{ discrepancies.length }}
            </v-chip>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!discrepancies.length" class="trfa-empty pa-6">
              <v-icon size="30" color="green">mdi-check-decagram-outline</v-icon>
              <div class="mt-2 text-body-2 font-weight-medium">No discrepancies</div>
              <div class="text-caption text-medium-emphasis">Every completed receipt matched what was sent.</div>
            </div>
            <div v-else class="trfa-disc-list">
              <div v-for="d in discrepancies" :key="d.reference" class="trfa-disc-row">
                <div class="trfa-disc-icon">
                  <v-icon size="16" color="error">mdi-alert-circle-outline</v-icon>
                </div>
                <div class="trfa-disc-body">
                  <div class="d-flex align-center flex-wrap ga-2">
                    <span class="font-weight-bold">{{ d.reference }}</span>
                    <v-chip size="x-small" variant="flat" :color="priorityMeta(d.priority).color">
                      <v-icon size="10" start>{{ priorityMeta(d.priority).icon }}</v-icon>
                      {{ priorityMeta(d.priority).label }}
                    </v-chip>
                    <span class="text-caption text-medium-emphasis">{{ d.route }}</span>
                  </div>
                  <div class="text-caption text-medium-emphasis">
                    {{ d.units_received }} of {{ d.units_sent }} units received
                    <template v-if="d.received_at"> · {{ formatDateTime(d.received_at) }}</template>
                  </div>
                </div>
                <div class="text-right">
                  <div class="trfa-disc-units" :class="d.variance_units < 0 ? 'trfa-neg' : 'trfa-pos'">
                    {{ d.variance_units > 0 ? '+' : '' }}{{ d.variance_units }}
                  </div>
                  <div class="text-caption text-medium-emphasis">{{ formatMoney(d.variance_value) }}</div>
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <div class="trfa-footnote">
      <v-icon size="13">mdi-information-outline</v-icon>
      Figures cover {{ data?.kpis.total ?? 0 }} transfers{{ rangeLabel }} and are computed live from
      transfer, line and batch records.
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const brand = useBranding()
const route = useRoute()
const { branches: branchesApi } = useTenantEndpoints()

const loading = ref(false)
const exporting = ref(false)
const exportingPdf = ref(false)
const data = ref(null)

const granularity = ref('week')
const branchFilter = ref(null)
const rangePreset = ref('90d')
const trendHover = ref(-1)

const granularityOptions = [
  { title: 'Daily', value: 'day' },
  { title: 'Weekly', value: 'week' },
  { title: 'Monthly', value: 'month' },
]

const rangePresets = [
  { label: '30 days', value: '30d', days: 30 },
  { label: '90 days', value: '90d', days: 90 },
  { label: '6 months', value: '180d', days: 180 },
  { label: '1 year', value: '365d', days: 365 },
  { label: 'All time', value: 'all', days: null },
]

const dateRange = ref({ from: null, to: null })

const listPath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers'
    : '/ims/inventory/transfers',
)

const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

const branchOptions = computed(() =>
  (branchStore.branches || []).map(b => ({ title: b.name, value: b.id })),
)

// ── Formatting ──────────────────────────────────────────────────────────
function formatMoney(v) {
  const n = Number(v || 0)
  return `KES ${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
function formatQty(v) {
  return Number(v || 0).toLocaleString()
}
function fmtPct(v) {
  return v == null ? '—' : `${Number(v).toFixed(1)}%`
}
function fmtHours(v) {
  if (v == null) return '—'
  const h = Number(v)
  if (h < 1) return `${Math.round(h * 60)}m`
  if (h < 48) return `${h.toFixed(1)}h`
  return `${(h / 24).toFixed(1)}d`
}
function formatDateTime(d) {
  return d
    ? new Date(d).toLocaleString(undefined, {
        day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
      })
    : '—'
}

// ── Palette (brand-aware) ───────────────────────────────────────────────
const PALETTE = {
  grey: '#94a3b8',
  blue: '#3b82f6',
  indigo: '#6366f1',
  green: '#10b981',
  red: '#ef4444',
  amber: '#f59e0b',
  primary: brand.primary?.value || '#2f6dff',
  teal: '#14b8a6',
}

const PRIORITY_META = {
  low: { label: 'Low', icon: 'mdi-arrow-down', color: 'grey', hex: PALETTE.grey },
  normal: { label: 'Normal', icon: 'mdi-circle-medium', color: 'primary', hex: PALETTE.primary },
  high: { label: 'High', icon: 'mdi-arrow-up', color: 'amber', hex: PALETTE.amber },
  urgent: { label: 'Urgent', icon: 'mdi-alert-decagram', color: 'error', hex: PALETTE.red },
}
function priorityMeta(p) {
  return PRIORITY_META[p || 'normal'] || PRIORITY_META.normal
}

// ── Derived view models ─────────────────────────────────────────────────
const kpis = computed(() => {
  const k = data.value?.kpis || {}
  return [
    {
      title: 'Transfers',
      value: formatQty(k.total),
      sub: `${k.completed ?? 0} completed`,
      icon: 'mdi-swap-horizontal-bold',
      color: 'primary',
    },
    {
      title: 'Value moved',
      value: formatMoney(k.value),
      sub: `${formatQty(k.units)} units`,
      icon: 'mdi-cash-multiple',
      color: 'teal',
    },
    {
      title: 'In transit',
      value: formatQty(k.in_transit),
      sub: `${k.requested ?? 0} awaiting approval`,
      icon: 'mdi-truck-fast-outline',
      color: 'indigo',
    },
    {
      title: 'Fill rate',
      value: fmtPct(k.fill_rate_pct),
      sub: `${k.variance_units > 0 ? '+' : ''}${k.variance_units ?? 0} units variance`,
      icon: 'mdi-check-decagram-outline',
      color: (k.fill_rate_pct ?? 100) >= 98 ? 'green' : 'amber',
    },
    {
      title: 'Avg cycle',
      value: fmtHours(k.avg_cycle_hours),
      sub: `${fmtHours(k.avg_transit_hours)} in transit`,
      icon: 'mdi-timer-outline',
      color: 'blue',
    },
    {
      title: 'On time',
      value: k.on_time_pct == null ? '—' : fmtPct(k.on_time_pct),
      sub: k.on_time_pct == null ? 'no ETA recorded' : 'vs scheduled delivery',
      icon: 'mdi-calendar-check-outline',
      color: k.on_time_pct == null ? 'grey' : k.on_time_pct >= 90 ? 'green' : 'amber',
    },
  ]
})

const statusSegments = computed(() =>
  (data.value?.status_breakdown || [])
    .filter(s => s.count > 0)
    .map(s => ({
      label: s.label,
      value: s.count,
      color: PALETTE[s.color] || PALETTE.blue,
    })),
)

// Attach hex colours to the status rows for the legend dots.
const statusRows = computed(() =>
  (data.value?.status_breakdown || []).map(s => ({
    ...s,
    hex: PALETTE[s.color] || PALETTE.blue,
  })),
)

const trend = computed(() => data.value?.trend || [])
const trendMax = computed(() =>
  Math.max(1, ...trend.value.map(b => Math.max(b.created, b.completed, b.cancelled || 0))),
)
const trendLegend = [
  { label: 'Created', hex: PALETTE.primary },
  { label: 'Completed', hex: PALETTE.green },
  { label: 'Cancelled', hex: PALETTE.red },
]
const peakBucket = computed(() => {
  if (!trend.value.length) return { label: '—', created: 0 }
  return trend.value.reduce((a, b) => (b.created > a.created ? b : a), trend.value[0])
})
const trendValueTotal = computed(() => trend.value.reduce((s, b) => s + (b.value || 0), 0))
const trendUnitsTotal = computed(() => trend.value.reduce((s, b) => s + (b.units || 0), 0))

// Keep x-axis readable when there are many buckets.
const labelStride = computed(() => Math.ceil(trend.value.length / 12))
function shortLabel(b) {
  return (b.label || b.date || '').replace(/^wk\s+/i, '')
}

const onTimeTone = computed(() => {
  const v = data.value?.kpis?.on_time_pct
  if (v == null) return 'trfa-q-muted'
  if (v >= 90) return 'trfa-q-good'
  if (v >= 70) return 'trfa-q-warn'
  return 'trfa-q-bad'
})

const agingMax = computed(() =>
  Math.max(1, ...(data.value?.aging || []).map(a => a.count || 0)),
)
const staleCount = computed(() =>
  (data.value?.aging || [])
    .filter(a => a.label === '3–7 days' || a.label === '7+ days')
    .reduce((s, a) => s + (a.count || 0), 0),
)
function agingColor(label) {
  if (label === '7+ days') return 'error'
  if (label === '3–7 days') return 'amber'
  if (label === '1–3 days') return 'blue'
  return 'teal'
}

const priorityRows = computed(() =>
  (data.value?.priority_breakdown || []).map(p => ({
    ...p,
    ...priorityMeta(p.priority),
    icon: priorityMeta(p.priority).icon,
    color: priorityMeta(p.priority).color,
    hex: priorityMeta(p.priority).hex,
    label: priorityMeta(p.priority).label,
  })),
)
const priorityMax = computed(() =>
  Math.max(1, ...priorityRows.value.map(p => p.count || 0)),
)

const routeRows = computed(() => data.value?.top_routes || [])
const warehouseRows = computed(() => data.value?.warehouse_throughput || [])
const whMax = computed(() =>
  Math.max(1, ...warehouseRows.value.map(w => Math.max(w.dispatched, w.received))),
)
const itemRows = computed(() => data.value?.top_items || [])
const itemMax = computed(() => Math.max(1, ...itemRows.value.map(i => i.units || 0)))
const partnerRows = computed(() => data.value?.partner_performance || [])
const discrepancies = computed(() => data.value?.discrepancies || [])

const rangeLabel = computed(() => {
  const f = data.value?.filters
  if (!f?.date_from) return ' across all time'
  return ` from ${f.date_from} to ${f.date_to || 'today'}`
})

// ── Data loading ────────────────────────────────────────────────────────
function applyPreset(value) {
  const preset = rangePresets.find(p => p.value === value)
  if (!preset) return
  if (preset.days == null) {
    dateRange.value = { from: null, to: null }
  } else {
    const to = new Date()
    const from = new Date()
    from.setDate(from.getDate() - preset.days)
    dateRange.value = {
      from: from.toISOString().slice(0, 10),
      to: to.toISOString().slice(0, 10),
    }
  }
  load()
}

async function load() {
  loading.value = true
  try {
    const params = { granularity: granularity.value }
    if (dateRange.value.from) params.date_from = dateRange.value.from
    if (dateRange.value.to) params.date_to = dateRange.value.to
    if (branchFilter.value) params.branch = branchFilter.value
    if (branchStore.currentBranchId && !branchFilter.value) {
      params.branch = branchStore.currentBranchId
    }
    const buckets = bucketCount()
    if (buckets) params.buckets = buckets
    const res = await $api.get('/inventory/transfers/analytics/', { params })
    data.value = res.data
  } catch {
    data.value = null
    showSnack('Could not load transfer analytics.', 'error')
  } finally {
    loading.value = false
  }
}

/** Size the trend buckets so the whole selected window is covered. */
function bucketCount() {
  const preset = rangePresets.find(p => p.value === rangePreset.value)
  const days = preset?.days
  if (!days) return null
  const perBucket = granularity.value === 'day' ? 1 : granularity.value === 'week' ? 7 : 30
  return Math.min(52, Math.max(2, Math.round(days / perBucket)))
}

const snack = reactive({ show: false, color: 'success', text: '' })
function showSnack(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

async function exportCsv() {
  exporting.value = true
  try {
    const k = data.value?.kpis || {}
    const lines = [
      ['Metric', 'Value'],
      ['Transfers', k.total ?? 0],
      ['Completed', k.completed ?? 0],
      ['In transit', k.in_transit ?? 0],
      ['Requested', k.requested ?? 0],
      ['Cancelled', k.cancelled ?? 0],
      ['Total value (cost)', k.value ?? 0],
      ['Units moved', k.units ?? 0],
      ['Line items', k.items ?? 0],
      ['Fill rate %', k.fill_rate_pct ?? 0],
      ['Variance units', k.variance_units ?? 0],
      ['Variance value', k.variance_value ?? 0],
      ['Avg cycle hours', k.avg_cycle_hours ?? ''],
      ['Avg approval hours', k.avg_approval_hours ?? ''],
      ['Avg transit hours', k.avg_transit_hours ?? ''],
      ['On-time %', k.on_time_pct ?? ''],
      [],
      ['Trend bucket', 'Created', 'Completed', 'Cancelled', 'Units', 'Value'],
      ...trend.value.map(b => [b.label, b.created, b.completed, b.cancelled, b.units, b.value]),
      [],
      ['Route', 'Transfers', 'Units', 'Value', 'Avg transit hours'],
      ...routeRows.value.map(r => [r.route, r.count, r.units, r.value, r.avg_transit_hours ?? '']),
      [],
      ['Item', 'Units', 'Value', 'Lines', 'Variance'],
      ...itemRows.value.map(i => [i.name, i.units, i.value, i.transfers, i.variance]),
      [],
      ['Partner', 'Moves', 'Units', 'Value', 'Avg transit hours', 'On-time %'],
      ...partnerRows.value.map(p => [p.name, p.shipments, p.units, p.value, p.avg_transit_hours ?? '', p.on_time_pct ?? '']),
    ]
    const csv = lines
      .map(row => row.map(cell => {
        const s = cell == null ? '' : String(cell)
        return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
      }).join(','))
      .join('\n')

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer_analytics_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
    showSnack('Analytics exported', 'success')
  } catch {
    showSnack('Export failed', 'error')
  } finally {
    exporting.value = false
  }
}

/** Server-rendered PDF report for the current filters. */
async function downloadPdf() {
  exportingPdf.value = true
  try {
    const params = { granularity: granularity.value }
    if (dateRange.value.from) params.date_from = dateRange.value.from
    if (dateRange.value.to) params.date_to = dateRange.value.to
    if (branchFilter.value) params.branch = branchFilter.value
    else if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
    const buckets = bucketCount()
    if (buckets) params.buckets = buckets

    const res = await $api.get('/inventory/transfers/analytics-pdf/', {
      params,
      responseType: 'blob',
      timeout: 60000,
    })
    const blob = new Blob([res.data], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer-analytics_${new Date().toISOString().slice(0, 10)}.pdf`
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 2000)
    showSnack('PDF report downloaded', 'success')
  } catch {
    showSnack('Could not generate the PDF report.', 'error')
  } finally {
    exportingPdf.value = false
  }
}

onMounted(() => {
  applyPreset(rangePreset.value === '90d' ? '90d' : rangePreset.value)
})
</script>

<style scoped>
/* ═══════════════════ HERO ═══════════════════ */
.trfa-hero {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  padding: 22px 24px 17px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.trfa-hero-glow {
  position: absolute;
  width: 320px;
  height: 320px;
  border-radius: 50%;
  top: -160px;
  right: -90px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.28), transparent 65%);
  pointer-events: none;
}
.trfa-hero-glow-2 {
  top: auto;
  bottom: -190px;
  right: auto;
  left: -110px;
  width: 280px;
  height: 280px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.18), transparent 68%);
}
.trfa-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 15px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
}
.trfa-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  opacity: 0.86;
}
.trfa-title {
  font-size: 25px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  margin: 2px 0 3px;
}
.trfa-sub {
  font-size: 12.5px;
  opacity: 0.9;
  max-width: 640px;
}
.trfa-hero-iconbtn {
  color: #fff !important;
}
.trfa-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #fff !important;
  border: 1px solid rgba(255, 255, 255, 0.26);
}
.trfa-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.24) !important;
}
.trfa-hero-btn-strong {
  background: #fff !important;
  color: rgb(var(--v-theme-primary)) !important;
  font-weight: 700;
}
.trfa-hero-btn-cta {
  background: #fff !important;
  color: rgb(var(--v-theme-primary)) !important;
  font-weight: 700;
  box-shadow: 0 6px 16px -6px rgba(15, 23, 42, 0.45);
}
.trfa-hero-btn-cta:hover {
  background: #f4f8ff !important;
}
.trfa-hero-facts {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.trfa-hero-fact-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.trfa-hero-fact-label {
  font-size: 10.5px;
  letter-spacing: 0.03em;
  opacity: 0.82;
  margin-top: 1px;
}
.trfa-hero-divider {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.24);
}

/* ═══════════════════ FILTER BAR ═══════════════════ */
.trfa-filterbar {
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.trfa-select {
  max-width: 210px;
  min-width: 200px;
}
.trfa-presets :deep(.v-chip) {
  font-size: 11.5px;
  font-weight: 600;
}

/* ═══════════════════ TREND CHART ═══════════════════ */
.trfa-trend-wrap {
  position: relative;
  height: 234px;
  padding-left: 2px;
}
.trfa-trend-grid {
  position: absolute;
  inset: 0 0 24px 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  pointer-events: none;
}
.trfa-trend-grid span {
  display: block;
  height: 1px;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.trfa-trend-bars {
  position: relative;
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 100%;
  padding-bottom: 24px;
}
.trfa-trend-col {
  position: relative;
  flex: 1 1 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  border-radius: 8px 8px 0 0;
  transition: background 0.15s ease;
}
.trfa-trend-col.is-active {
  background: rgba(var(--v-theme-primary), 0.055);
}
.trfa-trend-stack {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 3px;
  flex: 1;
  min-height: 0;
}
.trfa-trend-bar {
  flex: 1 1 0;
  max-width: 13px;
  border-radius: 4px 4px 0 0;
  min-height: 2px;
  transition: filter 0.15s ease;
}
.trfa-trend-created { background: rgba(var(--v-theme-primary), 0.85); }
.trfa-trend-completed { background: #10b981; }
.trfa-trend-cancelled { background: #ef4444; }
.trfa-trend-col:hover .trfa-trend-bar { filter: brightness(1.12); }
.trfa-trend-label {
  position: absolute;
  bottom: 2px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 9.5px;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.trfa-trend-tip {
  position: absolute;
  bottom: calc(100% + 6px);
  left: 50%;
  transform: translateX(-50%);
  z-index: 5;
  min-width: 132px;
  padding: 8px 10px;
  border-radius: 10px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  box-shadow: 0 10px 24px -10px rgba(15, 23, 42, 0.4);
  font-size: 11px;
}
.trfa-trend-tip-title {
  font-weight: 700;
  font-size: 11.5px;
  margin-bottom: 4px;
}
.trfa-trend-tip div {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  line-height: 1.6;
}
.trfa-trend-tip span {
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.trfa-trend-foot {
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}

/* ═══════════════════ DONUT / LEGEND ═══════════════════ */
.trfa-donut-value {
  font-size: 26px;
  font-weight: 800;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.trfa-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
  display: inline-block;
}
.trfa-legend-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 0;
}
.trfa-legend-pct {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  min-width: 42px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.trfa-mini-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.trfa-mini {
  padding: 9px 11px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trfa-mini-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.15;
  font-variant-numeric: tabular-nums;
}
.trfa-mini-label {
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-top: 1px;
}

/* ═══════════════════ QUALITY TILES ═══════════════════ */
.trfa-quality {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.trfa-quality-tile {
  padding: 11px 12px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.trfa-quality-value {
  font-size: 19px;
  font-weight: 800;
  line-height: 1.15;
  font-variant-numeric: tabular-nums;
}
.trfa-quality-label {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-top: 2px;
}
.trfa-quality-sub {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.48);
  margin-top: 1px;
}
.trfa-q-good { background: rgba(16, 185, 129, 0.08); border-color: rgba(16, 185, 129, 0.22); }
.trfa-q-good .trfa-quality-value { color: #0f9d6f; }
.trfa-q-warn { background: rgba(245, 158, 11, 0.09); border-color: rgba(245, 158, 11, 0.24); }
.trfa-q-warn .trfa-quality-value { color: #b45309; }
.trfa-q-bad { background: rgba(239, 68, 68, 0.08); border-color: rgba(239, 68, 68, 0.22); }
.trfa-q-bad .trfa-quality-value { color: #dc2626; }
.trfa-q-info { background: rgba(var(--v-theme-primary), 0.06); border-color: rgba(var(--v-theme-primary), 0.18); }
.trfa-q-info .trfa-quality-value { color: rgb(var(--v-theme-primary)); }
.trfa-q-muted .trfa-quality-value { color: rgba(var(--v-theme-on-surface), 0.55); }

.trfa-kv {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 12.5px;
  padding: 3px 0;
  color: rgba(var(--v-theme-on-surface), 0.66);
}
.trfa-kv strong {
  color: rgba(var(--v-theme-on-surface), 0.92);
  font-variant-numeric: tabular-nums;
}

/* ═══════════════════ PRIORITY ═══════════════════ */
.trfa-priority-row {
  padding: 9px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.055);
}
.trfa-priority-row:last-child { border-bottom: none; }
.trfa-priority-head {
  display: flex;
  align-items: center;
  gap: 8px;
}
.trfa-priority-meta {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin: 4px 0 6px;
}
.trfa-priority-track {
  height: 7px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: hidden;
}
.trfa-priority-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.35s ease;
}
.trfa-sep { opacity: 0.45; }

/* ═══════════════════ TABLES ═══════════════════ */
.trfa-table {
  width: 100%;
  border-collapse: collapse;
}
.trfa-table thead th {
  padding: 9px 14px;
  text-align: left;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.5);
  background: rgba(var(--v-theme-on-surface), 0.025);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trfa-table tbody td {
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  font-size: 12.5px;
}
.trfa-table tbody tr:last-child td { border-bottom: none; }
.trfa-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.035); }

.trfa-lane {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 5px;
}
.trfa-lane-chip {
  padding: 2px 8px;
  border-radius: 7px;
  font-size: 11px;
  font-weight: 700;
  background: rgba(var(--v-theme-on-surface), 0.06);
  white-space: nowrap;
}
.trfa-lane-chip-dest {
  background: rgba(var(--v-theme-primary), 0.1);
  color: rgb(var(--v-theme-primary));
}
.trfa-lane-arrow { opacity: 0.4; }

/* ═══════════════════ WAREHOUSE ═══════════════════ */
.trfa-wh-row {
  padding: 10px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.055);
}
.trfa-wh-row:last-child { border-bottom: none; }
.trfa-wh-head {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 7px;
}
.trfa-wh-bars {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.trfa-wh-values {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 5px;
}

/* ═══════════════════ ITEMS ═══════════════════ */
.trfa-items { padding: 4px 0; max-height: 366px; overflow-y: auto; }
.trfa-item-row {
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 8px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.trfa-item-row:last-child { border-bottom: none; }
.trfa-item-rank {
  width: 22px;
  height: 22px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 10.5px;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
}
.trfa-item-body { min-width: 0; flex: 1; }
.trfa-item-top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
}
.trfa-item-name {
  font-size: 12.5px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trfa-item-units {
  font-size: 11.5px;
  font-weight: 800;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.trfa-item-track {
  height: 6px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: hidden;
  margin: 5px 0 4px;
}
.trfa-item-fill {
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, rgb(var(--v-theme-primary)), rgba(var(--v-theme-primary), 0.55));
}
.trfa-item-meta {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ═══════════════════ DISCREPANCIES ═══════════════════ */
.trfa-disc-list { padding: 4px 0; }
.trfa-disc-row {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.trfa-disc-row:last-child { border-bottom: none; }
.trfa-disc-icon {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(239, 68, 68, 0.1);
}
.trfa-disc-body { flex: 1; min-width: 0; }
.trfa-disc-units {
  font-size: 14px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.trfa-neg { color: #dc2626; }
.trfa-pos { color: #0f9d6f; }

/* ═══════════════════ EMPTY / FOOT ═══════════════════ */
.trfa-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 26px 16px;
}
.trfa-footnote {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 18px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}

@media (max-width: 960px) {
  .trfa-hero-divider-lg { display: none; }
  .trfa-title { font-size: 21px; }
  .trfa-trend-wrap { height: 196px; }
  .trfa-trend-label { font-size: 8.5px; }
}
@media (max-width: 700px) {
  .trfa-quality,
  .trfa-wh-bars,
  .trfa-mini-grid { grid-template-columns: 1fr; }
  .trfa-trend-label {
    writing-mode: vertical-rl;
    bottom: 0;
    font-size: 8px;
  }
  .trfa-trend-bars { padding-bottom: 40px; }
}
</style>
