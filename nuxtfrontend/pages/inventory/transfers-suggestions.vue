<template>
  <v-container fluid class="pa-3 pa-md-5 tgs-page">
    <!-- ═══════════════════ HERO ═══════════════════ -->
    <div class="tgs-hero mb-4" :style="heroTheme">
      <span class="tgs-hero-glow" />
      <span class="tgs-hero-glow tgs-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="tgs-hero-icon">
            <v-icon size="30">mdi-transfer-right</v-icon>
          </div>
          <div>
            <div class="tgs-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              INVENTORY · LOGISTICS · SUGGESTIONS
            </div>
            <h1 class="tgs-title">Transfer Suggestions</h1>
            <div class="tgs-sub">
              Every branch scanned against its own demand — where to move stock so no
              shelf is empty and no warehouse is buried
              <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="tgs-hero-iconbtn"
            title="Rescan stock"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tgs-hero-btn-glass"
            prepend-icon="mdi-chart-box-outline"
            :to="analyticsPath"
          >Analytics</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tgs-hero-btn-strong"
            prepend-icon="mdi-file-pdf-box"
            :loading="exportingPdf"
            @click="downloadPdf"
          >PDF Report</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tgs-hero-btn-glass"
            prepend-icon="mdi-arrow-left"
            :to="listPath"
          >Transfers</v-btn>
        </div>
      </div>

      <div class="tgs-hero-facts">
        <div class="tgs-hero-fact">
          <div class="tgs-hero-fact-value">
            {{ score.overall ?? '—' }}<span class="tgs-fact-suffix">/100</span>
          </div>
          <div class="tgs-hero-fact-label">
            network balance · grade {{ score.grade ?? '—' }}
          </div>
        </div>
        <span class="tgs-hero-divider" />
        <div class="tgs-hero-fact">
          <div class="tgs-hero-fact-value">{{ summary.suggestions ?? 0 }}</div>
          <div class="tgs-hero-fact-label">transfer suggestions</div>
        </div>
        <span class="tgs-hero-divider" />
        <div class="tgs-hero-fact">
          <div class="tgs-hero-fact-value">{{ formatQty(summary.units) }}</div>
          <div class="tgs-hero-fact-label">units to rebalance</div>
        </div>
        <span class="tgs-hero-divider tgs-hero-divider-lg" />
        <div class="tgs-hero-fact">
          <div class="tgs-hero-fact-value">{{ formatMoney(summary.value) }}</div>
          <div class="tgs-hero-fact-label">stock value in motion</div>
        </div>
      </div>
    </div>

    <!-- ═══════════════════ FILTER BAR ═══════════════════ -->
    <v-card rounded="xl" border class="mb-4 tgs-filterbar">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <div class="d-flex align-center ga-2">
          <v-icon size="17" color="primary">mdi-tune</v-icon>
          <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing:.06em">
            Balance target
          </span>
        </div>

        <v-chip-group v-model="coverPreset" mandatory selected-class="text-primary" class="tgs-presets">
          <v-chip
            v-for="c in coverOptions"
            :key="c.value"
            :value="c.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
            @click="applyCover(c.value)"
          >{{ c.label }}</v-chip>
        </v-chip-group>

        <v-spacer class="d-none d-md-flex" />

        <v-select
          v-model="windowDays"
          :items="windowOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          class="tgs-select"
          prepend-inner-icon="mdi-history"
          @update:model-value="load"
        />
        <v-select
          v-model="urgencyFilter"
          :items="urgencyOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          class="tgs-select"
          prepend-inner-icon="mdi-alert-circle-outline"
        />
        <v-select
          v-model="branchFilter"
          :items="branchOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          class="tgs-select"
          prepend-inner-icon="mdi-warehouse"
          @update:model-value="load"
        />
      </div>
    </v-card>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-4" rounded />

    <!-- ═══════════════════ BALANCE SCORE + BRANCH HEALTH ═══════════════════ -->
    <v-row dense class="mb-1">
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100 tgs-score-card">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Network balance</div>
            <div class="text-caption text-medium-emphasis">
              How evenly stock is spread against where it sells
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="tgs-gauge">
              <svg viewBox="0 0 120 120" class="tgs-gauge-svg">
                <circle cx="60" cy="60" r="52" class="tgs-gauge-track" />
                <circle
                  cx="60" cy="60" r="52"
                  class="tgs-gauge-fill"
                  :stroke="scoreHex"
                  :stroke-dasharray="gaugeDash"
                  stroke-linecap="round"
                />
              </svg>
              <div class="tgs-gauge-center">
                <div class="tgs-gauge-value" :style="{ color: scoreHex }">
                  {{ score.overall ?? '—' }}
                </div>
                <div class="tgs-gauge-grade">GRADE {{ score.grade ?? '—' }}</div>
              </div>
            </div>

            <div class="text-center mt-2">
              <v-chip size="small" variant="tonal" :color="scoreChipColor" class="font-weight-bold">
                {{ score.label ?? '—' }}
              </v-chip>
            </div>

            <v-divider class="my-4" />
            <div class="tgs-kv"><span>Branches scanned</span><strong>{{ summary.branches_scanned ?? 0 }}</strong></div>
            <div class="tgs-kv"><span>Items tracked</span><strong>{{ formatQty(scope.items) }}</strong></div>
            <div class="tgs-kv"><span>Below reorder level</span><strong class="tgs-neg">{{ summary.below_reorder_items ?? 0 }}</strong></div>
            <div class="tgs-kv"><span>Out of stock</span><strong class="tgs-neg">{{ summary.zero_stock_items ?? 0 }}</strong></div>
            <div class="tgs-kv"><span>Expiring ≤ {{ expiryDays }}d</span><strong class="tgs-warn">{{ formatQty(summary.expiring_units) }}</strong></div>
            <div class="tgs-kv"><span>Already expired</span><strong class="tgs-neg">{{ formatQty(summary.expired_units) }}</strong></div>

            <v-alert
              v-if="summary.branches_with_demand < summary.branches_scanned"
              type="info"
              variant="tonal"
              density="compact"
              rounded="lg"
              class="mt-3"
            >
              {{ summary.branches_with_demand }} of {{ summary.branches_scanned }} branches have
              sales history in this window — the rest are topped up to their own reorder levels.
            </v-alert>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Branch health</div>
              <div class="text-caption text-medium-emphasis">
                Coverage, shortfalls and surplus per branch — weakest first
              </div>
            </div>
            <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">
              {{ health.length }} branches
            </v-chip>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!health.length" class="tgs-empty">
              <v-icon size="32" color="grey-lighten-1">mdi-warehouse</v-icon>
              <div class="mt-2 text-body-2 font-weight-medium">No branches to scan</div>
            </div>
            <div
              v-for="h in health"
              :key="h.branch_id"
              class="tgs-health-row"
              :class="'is-' + h.status"
            >
              <div class="tgs-health-ring" :style="ringStyle(h.score)">
                <span>{{ h.score }}</span>
              </div>
              <div class="tgs-health-body">
                <div class="d-flex align-center flex-wrap ga-2">
                  <span class="tgs-health-name">{{ h.branch }}</span>
                  <v-chip
                    size="x-small"
                    variant="flat"
                    :color="statusMeta(h.status).color"
                    class="font-weight-bold"
                  >{{ statusMeta(h.status).label }}</v-chip>
                  <span class="text-caption text-medium-emphasis">
                    {{ formatMoney(h.value) }} on hand
                  </span>
                </div>
                <div class="tgs-health-meta">
                  <span><b>{{ formatQty(h.units) }}</b> units</span>
                  <span class="tgs-sep">·</span>
                  <span><b>{{ h.items }}</b> items</span>
                  <span class="tgs-sep">·</span>
                  <span>coverage <b>{{ coverageLabel(h) }}</b></span>
                  <template v-if="h.demand_units">
                    <span class="tgs-sep">·</span>
                    <span>sold <b>{{ formatQty(h.demand_units) }}</b> in {{ windowDays }}d</span>
                  </template>
                </div>
                <div class="tgs-health-flags">
                  <span v-if="h.below_reorder" class="tgs-flag tgs-flag-warn">
                    <v-icon size="11">mdi-arrow-down-bold</v-icon>
                    {{ h.below_reorder }} below reorder
                  </span>
                  <span v-if="h.zero_stock" class="tgs-flag tgs-flag-bad">
                    <v-icon size="11">mdi-alert-circle-outline</v-icon>
                    {{ h.zero_stock }} out of stock
                  </span>
                  <span v-if="h.overstocked" class="tgs-flag tgs-flag-info">
                    <v-icon size="11">mdi-arrow-up-bold</v-icon>
                    {{ h.overstocked }} overstocked
                  </span>
                  <span v-if="h.expiring_units" class="tgs-flag tgs-flag-warn">
                    <v-icon size="11">mdi-clock-alert-outline</v-icon>
                    {{ formatQty(h.expiring_units) }} expiring
                  </span>
                  <span v-if="h.expired_units" class="tgs-flag tgs-flag-bad">
                    <v-icon size="11">mdi-calendar-remove-outline</v-icon>
                    {{ formatQty(h.expired_units) }} expired
                  </span>
                </div>
              </div>
              <div class="tgs-health-right">
                <div class="tgs-health-stat">
                  <span class="tgs-health-stat-value tgs-neg">{{ formatQty(h.deficit_units) }}</span>
                  <span class="tgs-health-stat-label">needed</span>
                </div>
                <div class="tgs-health-stat">
                  <span class="tgs-health-stat-value tgs-pos">{{ formatQty(h.surplus_units) }}</span>
                  <span class="tgs-health-stat-label">spare</span>
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════════ SUGGESTIONS ═══════════════════ -->
    <div class="tgs-section-head">
      <div>
        <div class="text-subtitle-1 font-weight-bold">Recommended transfers</div>
        <div class="text-caption text-medium-emphasis">
          Ranked by urgency, then by the value it unlocks — tick one or several to build drafts
        </div>
      </div>
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="u in urgencyCounts"
          :key="u.key"
          size="small"
          variant="tonal"
          :color="u.color"
          class="font-weight-bold"
        >{{ u.count }} {{ u.label }}</v-chip>
        <v-divider vertical class="mx-1 d-none d-sm-block" style="height:22px" />
        <v-checkbox-btn
          :model-value="allSelected"
          :indeterminate="someSelected && !allSelected"
          :disabled="!filteredSuggestions.length"
          density="compact"
          hide-details
          color="primary"
          @update:model-value="toggleSelectAll"
        />
        <span class="text-caption text-medium-emphasis">Select all</span>
        <v-btn
          size="small"
          variant="flat"
          rounded="lg"
          class="text-none tgs-btn-create"
          prepend-icon="mdi-plus-box-multiple-outline"
          :disabled="!selectedCount"
          @click="openBulkDialog"
        >Create {{ selectedCount ? selectedCount : '' }} draft{{ selectedCount === 1 ? '' : 's' }}</v-btn>
      </div>
    </div>

    <div v-if="!filteredSuggestions.length" class="tgs-empty-card">
      <v-icon size="34" color="green">mdi-check-decagram-outline</v-icon>
      <div class="mt-2 text-body-1 font-weight-bold">Nothing to move</div>
      <div class="text-caption text-medium-emphasis text-center">
        {{ suggestions.length
          ? 'No suggestions match this urgency filter.'
          : 'Every branch is already holding stock in line with its demand. Try a longer sales window.' }}
      </div>
    </div>

    <v-card v-else rounded="xl" border class="tgs-table-card">
      <div class="tgs-table-scroll">
        <table class="tgs-table">
          <thead>
            <tr>
              <th class="tgs-th-pick" />
              <th class="tgs-th-rank">#</th>
              <th class="tgs-th-item">ITEM</th>
              <th class="tgs-th-route">ROUTE</th>
              <th class="tgs-th-num">SEND / VALUE</th>
              <th class="tgs-th-num">DEMAND / COVERAGE</th>
              <th class="tgs-th-pri">PRIORITY</th>
              <th class="tgs-th-batch">FEFO BATCH</th>
              <th class="tgs-th-act" />
            </tr>
          </thead>
          <tbody>
            <template v-for="(s, i) in filteredSuggestions" :key="s.id">
              <tr
                class="tgs-tr"
                :class="['is-' + s.urgency, { 'is-selected': isSelected(s.id), 'is-open': expandedSug === s.id }]"
                @click="toggleSelect(s.id)"
              >
                <td class="tgs-td-pick" @click.stop>
                  <v-checkbox-btn
                    :model-value="isSelected(s.id)"
                    density="compact"
                    hide-details
                    color="primary"
                    @update:model-value="toggleSelect(s.id)"
                  />
                </td>
                <td class="tgs-td-rank">{{ i + 1 }}</td>
                <td class="tgs-td-item">
                  <div class="tgs-cell-name">{{ s.medication }}</div>
                  <div class="tgs-cell-meta">
                    <span v-if="s.category" class="tgs-cell-tag">{{ s.category }}</span>
                    <span class="tgs-cell-muted">{{ s.unit }} · {{ s.reason }}</span>
                  </div>
                </td>
                <td class="tgs-td-route">
                  <div class="tgs-cell-route">
                    <span class="tgs-cell-branch">{{ s.source_branch }}</span>
                    <v-icon size="13" class="tgs-route-arrow">mdi-arrow-right</v-icon>
                    <span class="tgs-cell-branch is-dest">{{ s.dest_branch }}</span>
                  </div>
                  <div class="tgs-cell-sub">
                    {{ formatQty(s.source_qty) }} on hand
                    <v-icon size="9">mdi-arrow-right</v-icon>
                    {{ formatQty(s.dest_qty) }}<template v-if="s.dest_reorder"> / reorder {{ formatQty(s.dest_reorder) }}</template>
                  </div>
                </td>
                <td class="tgs-td-num tgs-td-send">
                  {{ formatQty(s.units) }}
                  <div class="tgs-td-send-sub">{{ formatMoney(s.value) }}</div>
                </td>
                <td class="tgs-td-num tgs-td-muted">
                  {{ s.demand_share_pct ?? 0 }}%
                  <div v-if="s.coverage_before == null && s.coverage_after == null" class="tgs-td-sub is-empty">
                    no demand
                  </div>
                  <div v-else class="tgs-td-sub">
                    {{ coverLabel(s.coverage_before) }}
                    <v-icon size="9">mdi-arrow-right</v-icon>
                    <b>{{ coverLabel(s.coverage_after) }}</b>
                  </div>
                </td>
                <td class="tgs-td-pri">
                  <v-chip
                    size="x-small"
                    variant="flat"
                    :color="urgencyMeta(s.urgency).color"
                    class="font-weight-bold text-none"
                  >
                    <v-icon size="11" start>{{ urgencyMeta(s.urgency).icon }}</v-icon>
                    {{ urgencyMeta(s.urgency).label }}
                  </v-chip>
                  <v-chip
                    v-if="s.expiring"
                    size="x-small"
                    variant="tonal"
                    color="deep-orange"
                    class="font-weight-bold text-none ml-1"
                  >
                    <v-icon size="10" start>mdi-clock-alert-outline</v-icon>expiring
                  </v-chip>
                </td>
                <td class="tgs-td-batch">
                  <div v-if="s.batch_number" class="tgs-batch-pill">{{ s.batch_number }}</div>
                  <div v-else class="tgs-cell-muted">FEFO</div>
                  <div
                    v-if="s.days_to_expiry != null"
                    class="tgs-cell-sub"
                    :class="{ 'tgs-neg': s.days_to_expiry <= 30 }"
                  >{{ expiryLabel(s.days_to_expiry) }}</div>
                </td>
                <td class="tgs-td-act" @click.stop>
                  <div class="tgs-act-wrap">
                    <v-btn
                      icon
                      size="x-small"
                      variant="text"
                      :aria-label="expandedSug === s.id ? 'Hide details' : 'Show details'"
                      @click="toggleRowDetail(s.id)"
                    >
                      <v-icon size="16">
                        {{ expandedSug === s.id ? 'mdi-chevron-up' : 'mdi-chevron-down' }}
                      </v-icon>
                    </v-btn>
                    <v-btn
                      size="x-small"
                      variant="flat"
                      rounded="lg"
                      class="text-none"
                      :class="isSelected(s.id) ? 'tgs-btn-selected' : 'tgs-btn-select'"
                      :prepend-icon="isSelected(s.id) ? 'mdi-check-circle' : 'mdi-plus'"
                      @click="toggleSelect(s.id)"
                    >{{ isSelected(s.id) ? 'Selected' : 'Select' }}</v-btn>
                  </div>
                </td>
              </tr>

              <tr v-if="expandedSug === s.id" class="tgs-tr-detail">
                <td colspan="9">
                  <div class="tgs-detail-grid">
                    <div class="tgs-detail-main">
                      <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>{{ s.detail }}
                    </div>
                    <div class="tgs-detail-stats">
                      <div>
                        <div class="tgs-detail-label">DEMAND SHARE</div>
                        <div class="tgs-detail-value">{{ s.demand_share_pct ?? 0 }}%</div>
                      </div>
                      <div>
                        <div class="tgs-detail-label">COVERAGE</div>
                        <div class="tgs-detail-value">
                          <template v-if="s.coverage_before == null && s.coverage_after == null">no demand</template>
                          <template v-else>
                            {{ coverLabel(s.coverage_before) }} → {{ coverLabel(s.coverage_after) }}
                          </template>
                        </div>
                      </div>
                      <div>
                        <div class="tgs-detail-label">DAILY VELOCITY</div>
                        <div class="tgs-detail-value">{{ s.velocity_per_day ?? 0 }} / day</div>
                      </div>
                      <div>
                        <div class="tgs-detail-label">SUGGESTED PRIORITY</div>
                        <div class="tgs-detail-value tgs-cap">{{ s.priority }}</div>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <div class="tgs-table-foot">
        <span class="text-caption text-medium-emphasis">
          {{ filteredSuggestions.length }} line{{ filteredSuggestions.length === 1 ? '' : 's' }}
          <template v-if="selectedCount"> · {{ selectedCount }} selected</template>
        </span>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">
          {{ formatQty(filteredTotals.units) }} units · {{ formatMoney(filteredTotals.value) }}
        </span>
      </div>
    </v-card>

    <!-- ═══════════════════ EXPIRY RESCUE + DEAD STOCK ═══════════════════ -->
    <v-row dense class="mt-2">
      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Expiry rescue</div>
              <div class="text-caption text-medium-emphasis">
                Short-dated batches this branch cannot sell before they lapse
              </div>
            </div>
            <v-chip
              size="small"
              variant="tonal"
              :color="expiryRescue.length ? 'deep-orange' : 'green'"
              class="font-weight-bold"
            >{{ expiryRescue.length }}</v-chip>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!expiryRescue.length" class="tgs-empty">
              <v-icon size="28" color="green">mdi-check-decagram-outline</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">
                Nothing short-dated in the pipeline.
              </div>
            </div>
            <div v-for="r in expiryRescue" :key="r.batch_id" class="tgs-mini-row">
              <div class="tgs-mini-icon is-warn">
                <v-icon size="15" color="deep-orange">mdi-clock-alert-outline</v-icon>
              </div>
              <div class="tgs-mini-body">
                <div class="tgs-mini-title">{{ r.medication }}</div>
                <div class="tgs-mini-sub">
                  {{ r.source_branch }} → {{ r.dest_branch }} ·
                  batch {{ r.batch_number }}
                </div>
              </div>
              <div class="tgs-mini-right">
                <div class="tgs-mini-value">{{ formatQty(r.units) }}</div>
                <div class="tgs-mini-sub tgs-neg">{{ r.days_to_expiry }}d left</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="6">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Dead stock</div>
              <div class="text-caption text-medium-emphasis">
                Held here, selling there — stock with no local movement
              </div>
            </div>
            <v-chip
              size="small"
              variant="tonal"
              :color="deadStock.length ? 'amber' : 'green'"
              class="font-weight-bold"
            >{{ deadStock.length }}</v-chip>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!deadStock.length" class="tgs-empty">
              <v-icon size="28" color="green">mdi-check-decagram-outline</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">
                No dormant stock in this window.
              </div>
            </div>
            <div v-for="(d, i) in deadStock" :key="`${d.medication}-${i}`" class="tgs-mini-row">
              <div class="tgs-mini-icon is-info">
                <v-icon size="15" color="amber">mdi-sleep</v-icon>
              </div>
              <div class="tgs-mini-body">
                <div class="tgs-mini-title">{{ d.medication }}</div>
                <div class="tgs-mini-sub">
                  {{ d.source_branch }} → {{ d.dest_branch }} ·
                  {{ formatQty(d.held) }} held, 0 sold locally
                </div>
              </div>
              <div class="tgs-mini-right">
                <div class="tgs-mini-value">{{ formatQty(d.units) }}</div>
                <div class="tgs-mini-sub">{{ formatMoney(d.value) }}</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════════ ITEM IMBALANCE MATRIX ═══════════════════ -->
    <v-card rounded="xl" border class="mt-4">
      <div class="pa-4 pb-2">
        <div class="text-subtitle-1 font-weight-bold">Where the imbalance sits</div>
        <div class="text-caption text-medium-emphasis">
          Per item, how stock is spread across branches versus how it moves
        </div>
      </div>
      <v-divider />
      <v-card-text class="pa-0">
        <div v-if="!imbalances.length" class="tgs-empty">
          <v-icon size="28" color="green">mdi-check-decagram-outline</v-icon>
          <div class="mt-2 text-caption text-medium-emphasis">
            Stock distribution matches demand across every branch.
          </div>
        </div>
        <div v-else class="tgs-matrix">
          <div
            v-for="(im, idx) in imbalances"
            :key="im.medication + idx"
            class="tgs-matrix-row"
          >
            <button class="tgs-matrix-head" @click="toggleImbalance(idx)">
              <v-icon size="16" class="tgs-matrix-caret">
                {{ openImbalance.has(idx) ? 'mdi-chevron-down' : 'mdi-chevron-right' }}
              </v-icon>
              <div class="tgs-matrix-name">
                <span>{{ im.medication }}</span>
                <span v-if="im.category" class="tgs-matrix-cat">{{ im.category }}</span>
              </div>
              <div class="tgs-matrix-total">{{ formatQty(im.total_qty) }} on hand</div>
              <div class="tgs-matrix-spread">
                <div class="tgs-spread-track">
                  <div
                    v-for="(b, bi) in im.branches"
                    :key="b.branch"
                    class="tgs-spread-seg"
                    :style="{ width: b.qty / Math.max(1, im.total_qty) * 100 + '%', background: spreadColor(bi) }"
                    :title="`${b.branch}: ${b.qty}`"
                  />
                </div>
              </div>
            </button>
            <div v-if="openImbalance.has(idx)" class="tgs-matrix-detail">
              <div v-if="im.blocked" class="tgs-matrix-blocked">
                <v-icon size="13">mdi-information-outline</v-icon>
                {{ im.blocked }}
              </div>
              <table class="tgs-matrix-table">
                <thead>
                  <tr>
                    <th>Branch</th>
                    <th class="text-right">On hand</th>
                    <th class="text-right">Fair share</th>
                    <th class="text-right">Needs</th>
                    <th class="text-right">Spare</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(b, bi) in im.branches" :key="b.branch">
                    <td>
                      <span class="tgs-dot" :style="{ background: spreadColor(bi) }" />
                      {{ b.branch }}
                      <span v-if="b.not_stocked" class="tgs-matrix-cat">not stocked</span>
                    </td>
                    <td class="text-right">{{ formatQty(b.qty) }}</td>
                    <td class="text-right">{{ b.share_pct }}%</td>
                    <td class="text-right" :class="b.need ? 'tgs-neg font-weight-bold' : ''">
                      {{ b.need ? formatQty(b.need) : '—' }}
                    </td>
                    <td class="text-right" :class="b.surplus ? 'tgs-pos font-weight-bold' : ''">
                      {{ b.surplus ? formatQty(b.surplus) : '—' }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </v-card-text>
    </v-card>

    <div class="tgs-footnote">
      <v-icon size="13">mdi-information-outline</v-icon>
      Fair share blends each branch's share of demand over the last {{ windowDays }} days with
      {{ coverDays }} days of cover and its own reorder level. Expired batches are excluded from
      every calculation; the scan covers {{ scope.branches?.length ?? 0 }} active branches.
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="3200" rounded="lg">
      {{ snack.text }}
      <template v-if="snack.link">
        <v-btn variant="text" size="small" :to="listPath">Open</v-btn>
      </template>
    </v-snackbar>

    <!-- ═══════════════════ SELECTION BAR ═══════════════════ -->
    <div v-if="selectedCount" class="tgs-selbar">
      <div class="tgs-selbar-count">
        <v-icon size="18">mdi-checkbox-multiple-marked</v-icon>
        <span><b>{{ selectedCount }}</b> selected</span>
      </div>
      <span class="tgs-selbar-sep" />
      <div class="tgs-selbar-stat">
        <span class="tgs-selbar-stat-value">{{ formatQty(selectedTotals.units) }}</span>
        <span class="tgs-selbar-stat-label">units</span>
      </div>
      <div class="tgs-selbar-stat">
        <span class="tgs-selbar-stat-value">{{ formatMoney(selectedTotals.value) }}</span>
        <span class="tgs-selbar-stat-label">at cost</span>
      </div>
      <div class="tgs-selbar-stat tgs-selbar-stat-lane">
        <span class="tgs-selbar-stat-value">{{ selectedTotals.lanes }}</span>
        <span class="tgs-selbar-stat-label">
          draft{{ selectedTotals.lanes === 1 ? '' : 's' }}
        </span>
      </div>
      <span class="tgs-selbar-sep" />
      <v-btn variant="text" size="small" class="text-none tgs-selbar-clear" @click="clearSelection">
        Clear
      </v-btn>
      <v-btn
        variant="flat"
        rounded="lg"
        size="small"
        class="text-none tgs-selbar-go"
        prepend-icon="mdi-plus-box-multiple-outline"
        @click="openBulkDialog"
      >Review &amp; create</v-btn>
    </div>

    <!-- ═══════════════════ BULK CREATE DIALOG ═══════════════════ -->
    <v-dialog v-model="bulkDialog" max-width="1040" persistent scrollable>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="tgs-dlg-head" :style="heroTheme">
          <span class="tgs-hero-glow" />
          <div class="d-flex align-center flex-wrap ga-2 text-white">
            <v-icon size="22">mdi-swap-horizontal-bold</v-icon>
            <span class="text-h6 font-weight-bold">
              {{ groups.length === 1 ? 'New stock transfer' : `New stock transfers` }}
            </span>
            <v-chip size="small" variant="flat" class="tgs-head-chip">
              {{ groups.length }} draft{{ groups.length === 1 ? '' : 's' }}
            </v-chip>
            <v-chip size="small" variant="flat" class="tgs-head-chip">
              pre-filled from suggestions
            </v-chip>
            <v-spacer />
            <v-btn
              icon="mdi-close"
              variant="text"
              size="small"
              class="tgs-hero-iconbtn"
              @click="closeBulkDialog"
            />
          </div>
          <div class="text-caption mt-1" style="opacity:.85">
            Routes, items, quantities and priority are already set. Adjust anything before saving —
            stock only moves after approval.
          </div>
        </div>

        <div class="tgs-dlg-summary">
          <div class="tgs-dlg-sum-item">
            <div class="tgs-dlg-sum-label">TRANSFERS</div>
            <div class="tgs-dlg-sum-value">{{ groups.length }}</div>
          </div>
          <div class="tgs-dlg-sum-item">
            <div class="tgs-dlg-sum-label">LINE ITEMS</div>
            <div class="tgs-dlg-sum-value">{{ bulkTotals.lines }}</div>
          </div>
          <div class="tgs-dlg-sum-item">
            <div class="tgs-dlg-sum-label">UNITS</div>
            <div class="tgs-dlg-sum-value">{{ formatQty(bulkTotals.units) }}</div>
          </div>
          <div class="tgs-dlg-sum-item">
            <div class="tgs-dlg-sum-label">VALUE AT COST</div>
            <div class="tgs-dlg-sum-value">{{ formatMoney(bulkTotals.value) }}</div>
          </div>
        </div>

        <!-- Step rail -->
        <div class="tgs-steps px-4 pt-4">
          <template v-for="(s, i) in bulkSteps" :key="s.key">
            <div
              class="tgs-step"
              :class="{ 'tgs-step-active': bulkStep === i, 'tgs-step-done': bulkStep > i }"
              @click="goToStep(i)"
            >
              <div class="tgs-step-dot">
                <v-icon size="15">{{ bulkStep > i ? 'mdi-check' : s.icon }}</v-icon>
              </div>
              <div class="tgs-step-text">{{ s.label }}</div>
            </div>
            <div
              v-if="i < bulkSteps.length - 1"
              class="tgs-step-line"
              :class="{ 'tgs-step-line-done': bulkStep > i }"
            />
          </template>
        </div>

        <v-card-text class="pt-3">
          <!-- ── STEP 1: ROUTES & ITEMS ── -->
          <div v-if="bulkStep === 0">
            <div class="tgs-section-head tgs-dlg-section-head">
              <span class="tgs-section-index">01</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Route and items</div>
                <div class="text-caption text-medium-emphasis">
                  One transfer per lane — quantities are pre-filled from the scan.
                </div>
              </div>
            </div>

            <div v-for="(g, gi) in groups" :key="g.key" class="tgs-grp mt-3">
              <div class="tgs-grp-head">
                <div class="tgs-grp-index">{{ gi + 1 }}</div>
                <div class="tgs-grp-route">
                  <div class="tgs-grp-route-label">ROUTE</div>
                  <div class="d-flex align-center flex-wrap ga-2">
                    <span class="tgs-wh-chip">{{ g.source_branch }}</span>
                    <v-icon size="15" class="tgs-route-arrow">mdi-arrow-right</v-icon>
                    <span class="tgs-wh-chip tgs-wh-chip-dest">{{ g.dest_branch }}</span>
                  </div>
                </div>
                <v-spacer />
                <div class="tgs-grp-totals">
                  <div class="text-caption text-medium-emphasis">
                    {{ g.lines.length }} item{{ g.lines.length === 1 ? '' : 's' }} ·
                    {{ formatQty(groupUnits(g)) }} units
                  </div>
                  <div class="text-body-2 font-weight-bold">{{ formatMoney(groupValue(g)) }}</div>
                </div>
              </div>

              <v-textarea
                v-model="g.notes"
                label="Reason for the move *"
                rows="2"
                auto-grow
                density="compact"
                variant="outlined"
                rounded="lg"
                class="tgs-grp-notes"
                :hide-details="!!(g.notes || '').trim()"
                :error="!(g.notes || '').trim()"
                :messages="!(g.notes || '').trim() ? ['A reason is required before the draft can be created.'] : []"
              />
              <div class="d-flex flex-wrap ga-1 mt-2">
                <v-chip
                  v-for="r in reasonChips"
                  :key="r"
                  size="x-small"
                  variant="outlined"
                  color="primary"
                  class="text-none"
                  @click="g.notes = r"
                >{{ r }}</v-chip>
              </div>

              <div class="tgs-grp-lines mt-3">
                <div class="tgs-grp-line tgs-grp-line-head">
                  <span>ITEM</span>
                  <span class="text-center">BATCH</span>
                  <span class="text-right">SEND</span>
                  <span class="text-right">ON HAND</span>
                  <span class="text-right">VALUE</span>
                  <span />
                </div>
                <div v-for="(l, li) in g.lines" :key="l.key" class="tgs-grp-line">
                  <div class="tgs-line-item">
                    <v-icon size="15" class="tgs-line-icon">mdi-package-variant-closed</v-icon>
                    <div style="min-width:0">
                      <div class="tgs-line-name">{{ l.name }}</div>
                      <div class="tgs-line-meta">
                        {{ l.category || 'Uncategorised' }} · {{ formatMoney(l.unit_cost) }} / unit
                      </div>
                    </div>
                  </div>
                  <div class="text-center">
                    <div v-if="l.batch_number" class="tgs-batch-pill">
                      {{ l.batch_number }}
                      <span v-if="l.days_to_expiry != null" :class="l.days_to_expiry <= 30 ? 'tgs-neg' : ''">
                        · {{ expiryLabel(l.days_to_expiry) }}
                      </span>
                    </div>
                    <span v-else class="text-caption text-medium-emphasis">FEFO</span>
                  </div>
                  <div class="text-right">
                    <v-text-field
                      v-model.number="l.quantity"
                      type="number"
                      :min="1"
                      :max="l.source_qty"
                      density="compact"
                      variant="outlined"
                      rounded="lg"
                      hide-details
                      class="tgs-qty-field"
                      :error="!qtyValid(l)"
                      @update:model-value="l.userEdited = true"
                    />
                  </div>
                  <div class="text-right tgs-line-num">
                    {{ formatQty(l.source_qty) }}
                  </div>
                  <div class="text-right tgs-line-num font-weight-bold">
                    {{ formatMoney(lineValue(l)) }}
                  </div>
                  <div class="text-right">
                    <v-btn
                      icon="mdi-close"
                      variant="text"
                      size="x-small"
                      :disabled="g.lines.length === 1"
                      title="Remove line"
                      @click="removeLine(g, li)"
                    />
                  </div>
                </div>
              </div>

              <v-alert
                v-if="groupWarnings(g).length"
                type="warning"
                variant="tonal"
                density="compact"
                rounded="lg"
                class="mt-2"
              >
                <div v-for="w in groupWarnings(g)" :key="w">{{ w }}</div>
              </v-alert>
            </div>
          </div>

          <!-- ── STEP 2: CARGO & SCHEDULE ── -->
          <div v-else-if="bulkStep === 1">
            <div class="tgs-section-head tgs-dlg-section-head">
              <span class="tgs-section-index">02</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Cargo and schedule</div>
                <div class="text-caption text-medium-emphasis">
                  Priority, parcels and the delivery window for each transfer.
                </div>
              </div>
              <v-spacer />
              <v-btn
                variant="tonal"
                size="small"
                rounded="lg"
                class="text-none"
                prepend-icon="mdi-content-duplicate"
                @click="applyScheduleToAll"
              >Apply to all</v-btn>
            </div>

            <div class="tgs-cargo-all mt-3">
              <v-text-field
                v-model.number="cargoDefaults.parcel_count"
                type="number"
                min="1"
                label="Boxes / parcels (all)"
                density="compact"
                variant="outlined"
                rounded="lg"
                hide-details
                prepend-inner-icon="mdi-package-variant"
                class="tgs-cargo-default"
              />
              <v-text-field
                v-model.number="cargoDefaults.weight_kg"
                type="number"
                min="0"
                step="0.1"
                label="Total weight kg (all)"
                density="compact"
                variant="outlined"
                rounded="lg"
                hide-details
                prepend-inner-icon="mdi-weight-kilogram"
                class="tgs-cargo-default"
              />
              <v-btn
                variant="outlined"
                rounded="lg"
                size="small"
                class="text-none"
                prepend-icon="mdi-arrow-down-bold"
                @click="applyCargoDefaults"
              >Fill below</v-btn>
            </div>

            <div v-for="(g, gi) in groups" :key="g.key" class="tgs-grp mt-3">
              <div class="tgs-grp-head">
                <div class="tgs-grp-index">{{ gi + 1 }}</div>
                <div class="tgs-grp-route">
                  <div class="tgs-grp-route-label">TRANSFER</div>
                  <div class="d-flex align-center flex-wrap ga-2">
                    <span class="tgs-wh-chip">{{ g.source_branch }}</span>
                    <v-icon size="15" class="tgs-route-arrow">mdi-arrow-right</v-icon>
                    <span class="tgs-wh-chip tgs-wh-chip-dest">{{ g.dest_branch }}</span>
                  </div>
                </div>
                <v-spacer />
                <div class="tgs-grp-totals">
                  <div class="text-caption text-medium-emphasis">
                    {{ formatQty(groupUnits(g)) }} units
                  </div>
                  <div class="text-body-2 font-weight-bold">{{ formatMoney(groupValue(g)) }}</div>
                </div>
              </div>

              <div class="tgs-pick-label">
                <v-icon size="13">mdi-alert-circle-outline</v-icon> PRIORITY
              </div>
              <div class="tgs-priority-grid">
                <button
                  v-for="p in priorityOptions"
                  :key="p.value"
                  type="button"
                  class="tgs-priority-card"
                  :class="{ 'is-active': priorityKeyOf(g.priority) === p.value }"
                  @click="g.priority = p.value"
                >
                  <div class="d-flex align-center ga-2">
                    <v-icon size="17" :color="p.color">{{ p.icon }}</v-icon>
                    <span class="tgs-priority-label">{{ p.label }}</span>
                    <v-icon
                      v-if="priorityKeyOf(g.priority) === p.value"
                      size="15"
                      color="success"
                      class="ml-auto"
                    >mdi-check-circle</v-icon>
                  </div>
                  <div class="tgs-priority-desc">{{ p.desc }}</div>
                </button>
              </div>

              <div class="tgs-field-grid mt-3">
                <v-text-field
                  v-model.number="g.parcel_count"
                  type="number"
                  min="1"
                  label="Boxes / parcels"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                />
                <v-text-field
                  v-model.number="g.weight_kg"
                  type="number"
                  min="0"
                  step="0.1"
                  label="Weight (kg)"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                />
                <v-text-field
                  v-model="g.scheduled_pickup"
                  type="datetime-local"
                  label="Scheduled pickup"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                />
                <v-text-field
                  v-model="g.scheduled_delivery"
                  type="datetime-local"
                  label="Scheduled delivery"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  :hide-details="!deliveryBeforePickup(g)"
                  :error="deliveryBeforePickup(g)"
                  :messages="deliveryBeforePickup(g) ? ['Delivery must be after pickup'] : []"
                />
              </div>

              <div class="d-flex flex-wrap ga-1 mt-2">
                <v-chip
                  size="x-small"
                  variant="outlined"
                  color="primary"
                  class="text-none"
                  @click="setWindow(g, 1)"
                >Tomorrow</v-chip>
                <v-chip
                  size="x-small"
                  variant="outlined"
                  color="primary"
                  class="text-none"
                  @click="setWindow(g, 3)"
                >In 3 days</v-chip>
                <v-chip
                  size="x-small"
                  variant="outlined"
                  color="primary"
                  class="text-none"
                  @click="setWindow(g, 7)"
                >In a week</v-chip>
                <v-chip
                  size="x-small"
                  variant="outlined"
                  color="grey"
                  class="text-none"
                  @click="clearWindow(g)"
                >Clear</v-chip>
              </div>
            </div>
          </div>

          <!-- ── STEP 3: ASSIGNMENT ── -->
          <div v-else-if="bulkStep === 2">
            <div class="tgs-section-head tgs-dlg-section-head">
              <span class="tgs-section-index">03</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Assignment</div>
                <div class="text-caption text-medium-emphasis">
                  <template v-if="groups.length === 1">
                    Who carries this shipment. Optional — it can be assigned before dispatch.
                  </template>
                  <template v-else>
                    Applied to all {{ groups.length }} transfers. Optional — each can be changed
                    later before dispatch.
                  </template>
                </div>
              </div>
            </div>

            <div class="tgs-assign-grid mt-3">
              <button
                type="button"
                class="tgs-assign-card"
                :class="{ 'is-active': assignment.type === 'internal' }"
                @click="assignment.type = 'internal'"
              >
                <div class="tgs-assign-icon"><v-icon size="20">mdi-account-tie-hat</v-icon></div>
                <div class="tgs-assign-title">Internal driver</div>
                <div class="tgs-assign-sub">
                  {{ availableDrivers.length }} available of {{ driverOptions.length }} drivers
                </div>
                <v-icon
                  v-if="assignment.type === 'internal'"
                  size="17"
                  color="success"
                  class="tgs-assign-check"
                >mdi-check-circle</v-icon>
              </button>
              <button
                type="button"
                class="tgs-assign-card"
                :class="{ 'is-active': assignment.type === 'carrier' }"
                @click="assignment.type = 'carrier'"
              >
                <div class="tgs-assign-icon"><v-icon size="20">mdi-truck-fast</v-icon></div>
                <div class="tgs-assign-title">External carrier</div>
                <div class="tgs-assign-sub">{{ carrierOptions.length }} carriers on file</div>
                <v-icon
                  v-if="assignment.type === 'carrier'"
                  size="17"
                  color="success"
                  class="tgs-assign-check"
                >mdi-check-circle</v-icon>
              </button>
              <button
                type="button"
                class="tgs-assign-card"
                :class="{ 'is-active': !assignment.type }"
                @click="clearAssignment"
              >
                <div class="tgs-assign-icon"><v-icon size="20">mdi-clock-outline</v-icon></div>
                <div class="tgs-assign-title">Unassigned</div>
                <div class="tgs-assign-sub">Decide before dispatch</div>
                <v-icon
                  v-if="!assignment.type"
                  size="17"
                  color="success"
                  class="tgs-assign-check"
                >mdi-check-circle</v-icon>
              </button>
            </div>

            <template v-if="assignment.type">
              <div class="tgs-field-grid mt-3">
                <v-select
                  v-if="assignment.type === 'internal'"
                  v-model="assignment.driver_id"
                  :items="driverChoices"
                  item-title="label"
                  item-value="id"
                  label="Driver"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                  clearable
                />
                <v-select
                  v-else
                  v-model="assignment.carrier_id"
                  :items="carrierChoices"
                  item-title="label"
                  item-value="id"
                  label="Carrier"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                  clearable
                />
                <v-select
                  v-model="assignment.vehicle_id"
                  :items="vehicleChoices"
                  item-title="label"
                  item-value="id"
                  label="Fleet vehicle"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                  clearable
                />
              </div>
              <v-text-field
                v-model="assignment.vehicle_manual"
                label="Vehicle plate / description (if not in the fleet)"
                density="compact"
                variant="outlined"
                rounded="lg"
                hide-details
                class="mt-3"
                persistent-placeholder
                :disabled="!!assignment.vehicle_id"
              />
              <v-alert
                v-if="assignmentSummary"
                type="info"
                variant="tonal"
                density="compact"
                rounded="lg"
                class="mt-3"
              >
                {{ assignmentSummary }}
              </v-alert>
            </template>

            <div class="tgs-grp mt-3">
              <div class="tgs-grp-route-label mb-2">WILL BE APPLIED TO</div>
              <div class="d-flex flex-column" style="gap:8px">
                <div
                  v-for="(g, gi) in groups"
                  :key="g.key"
                  class="d-flex align-center flex-wrap ga-2"
                >
                  <span class="tgs-grp-index">{{ gi + 1 }}</span>
                  <span class="tgs-wh-chip">{{ g.source_branch }}</span>
                  <v-icon size="14" class="tgs-route-arrow">mdi-arrow-right</v-icon>
                  <span class="tgs-wh-chip tgs-wh-chip-dest">{{ g.dest_branch }}</span>
                  <span class="text-caption text-medium-emphasis">
                    · {{ priorityLabel(g.priority) }} · {{ formatQty(groupUnits(g)) }} units
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- ── STEP 4: REVIEW ── -->
          <div v-else>
            <div class="tgs-section-head tgs-dlg-section-head">
              <span class="tgs-section-index">04</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Review and save</div>
                <div class="text-caption text-medium-emphasis">
                  Check every draft before creating it — stock only moves after approval.
                </div>
              </div>
            </div>

            <div v-for="(g, gi) in groups" :key="g.key" class="tgs-rev-card mt-3">
              <div class="tgs-rev-top">
                <div class="tgs-grp-index">{{ gi + 1 }}</div>
                <div class="d-flex align-center flex-wrap ga-2">
                  <span class="tgs-wh-chip">{{ g.source_branch }}</span>
                  <v-icon size="15" class="tgs-route-arrow">mdi-arrow-right</v-icon>
                  <span class="tgs-wh-chip tgs-wh-chip-dest">{{ g.dest_branch }}</span>
                </div>
                <v-spacer />
                <v-chip
                  size="x-small"
                  variant="flat"
                  :color="priorityMetaOf(g.priority).color"
                  class="font-weight-bold"
                >
                  <v-icon size="11" start>{{ priorityMetaOf(g.priority).icon }}</v-icon>
                  {{ priorityMetaOf(g.priority).label }}
                </v-chip>
              </div>

              <div class="tgs-rev-stats">
                <div>
                  <div class="tgs-rev-label">Items</div>
                  <div class="tgs-rev-value">{{ g.lines.length }}</div>
                </div>
                <div>
                  <div class="tgs-rev-label">Units</div>
                  <div class="tgs-rev-value">{{ formatQty(groupUnits(g)) }}</div>
                </div>
                <div>
                  <div class="tgs-rev-label">Value</div>
                  <div class="tgs-rev-value">{{ formatMoney(groupValue(g)) }}</div>
                </div>
                <div v-if="g.parcel_count">
                  <div class="tgs-rev-label">Parcels</div>
                  <div class="tgs-rev-value">{{ g.parcel_count }}</div>
                </div>
                <div v-if="g.weight_kg">
                  <div class="tgs-rev-label">Weight</div>
                  <div class="tgs-rev-value">{{ g.weight_kg }} kg</div>
                </div>
              </div>

              <div
                v-if="g.scheduled_pickup || g.scheduled_delivery"
                class="tgs-rev-schedule"
              >
                <v-icon size="13">mdi-calendar-clock-outline</v-icon>
                <span v-if="g.scheduled_pickup">Pickup {{ prettyDateTime(g.scheduled_pickup) }}</span>
                <span v-if="g.scheduled_pickup && g.scheduled_delivery" class="tgs-sep">·</span>
                <span v-if="g.scheduled_delivery">
                  Delivery {{ prettyDateTime(g.scheduled_delivery) }}
                </span>
              </div>

              <div class="tgs-rev-lines">
                <div v-for="l in g.lines" :key="l.key" class="tgs-rev-line">
                  <v-icon size="14" class="tgs-line-icon">mdi-package-variant-closed</v-icon>
                  <span class="tgs-rev-line-name">{{ l.name }}</span>
                  <span v-if="l.batch_number" class="tgs-rev-batch">{{ l.batch_number }}</span>
                  <span class="tgs-rev-line-qty">{{ formatQty(l.quantity) }}</span>
                  <span class="tgs-rev-line-val">{{ formatMoney(lineValue(l)) }}</span>
                </div>
              </div>

              <div class="tgs-rev-notes">
                <v-icon size="13">mdi-text-box-outline</v-icon>
                <span>{{ g.notes || '—' }}</span>
              </div>
            </div>

            <div class="tgs-rev-assign mt-3">
              <v-icon size="17">{{ assignmentIcon }}</v-icon>
              <div>
                <div class="tgs-rev-label">Assignment</div>
                <div class="text-body-2 font-weight-medium">{{ assignmentLabel }}</div>
              </div>
            </div>

            <v-alert
              v-if="!canSaveBulk"
              type="warning"
              variant="tonal"
              density="compact"
              rounded="lg"
              class="mt-3"
            >
              {{ bulkBlockReason }}
            </v-alert>
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3">
          <span class="text-caption text-medium-emphasis">
            <template v-if="bulkStep === bulkSteps.length - 1">
              {{ groups.length }} draft{{ groups.length === 1 ? '' : 's' }} ·
              {{ formatQty(bulkTotals.units) }} units
            </template>
            <template v-else>
              Step {{ bulkStep + 1 }} of {{ bulkSteps.length }}
            </template>
          </span>
          <v-spacer />
          <v-btn
            v-if="bulkStep > 0"
            variant="text"
            class="text-none"
            prepend-icon="mdi-arrow-left"
            :disabled="saving"
            @click="prevBulkStep"
          >Back</v-btn>
          <v-btn variant="text" class="text-none" :disabled="saving" @click="closeBulkDialog">
            Cancel
          </v-btn>
          <v-btn
            v-if="bulkStep < bulkSteps.length - 1"
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            append-icon="mdi-arrow-right"
            :disabled="!bulkStepValid"
            @click="nextBulkStep"
          >Continue</v-btn>
          <template v-else>
            <v-btn
              color="primary"
              variant="tonal"
              rounded="lg"
              class="text-none"
              prepend-icon="mdi-content-save-outline"
              :loading="saving"
              :disabled="!canSaveBulk"
              @click="saveBulk(false)"
            >Save as draft{{ groups.length === 1 ? '' : 's' }}</v-btn>
            <v-btn
              color="success"
              variant="flat"
              rounded="lg"
              class="text-none"
              prepend-icon="mdi-send"
              :loading="saving"
              :disabled="!canSaveBulk"
              @click="saveBulk(true)"
            >Save &amp; submit</v-btn>
          </template>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const brand = useBranding()
const route = useRoute()

const loading = ref(false)
const exportingPdf = ref(false)
const saving = ref(false)
const data = ref(null)
const openImbalance = reactive(new Set())

// ── Selection (one or many recommendations) ─────────────────────────────
const selected = reactive(new Set())
const selectedCount = computed(() => selected.size)

const bulkDialog = ref(false)
const groups = ref([])
const bulkStep = ref(0)

// Mirrors the New stock transfer wizard's step rail.
const bulkSteps = [
  { key: 'route', label: 'Route and items', icon: 'mdi-map-marker-path' },
  { key: 'cargo', label: 'Cargo and schedule', icon: 'mdi-calendar-clock-outline' },
  { key: 'assign', label: 'Assignment', icon: 'mdi-account-group-outline' },
  { key: 'review', label: 'Review', icon: 'mdi-check-decagram-outline' },
]

// Cargo defaults used by the "apply to all" shortcut.
const cargoDefaults = ref({ parcel_count: 1, weight_kg: null })

// One assignment applied to every draft created from this dialog.
const assignment = ref({
  type: null, driver_id: null, carrier_id: null, vehicle_id: null, vehicle_manual: '',
})

// Logistics resources for the assignment step.
const driverOptions = ref([])
const carrierOptions = ref([])
const vehicleOptions = ref([])
const logisticsLoaded = ref(false)

const coverPreset = ref(30)
const windowDays = ref(90)
const urgencyFilter = ref(null)
const branchFilter = ref(null)

const snack = reactive({ show: false, color: 'success', text: '', link: false })
function showSnack(text, color = 'success', link = false) {
  Object.assign(snack, { show: true, color, text, link })
}

const coverOptions = [
  { label: '14 days cover', value: 14 },
  { label: '30 days cover', value: 30 },
  { label: '60 days cover', value: 60 },
  { label: '90 days cover', value: 90 },
]
const windowOptions = [
  { title: 'Last 30 days', value: 30 },
  { title: 'Last 90 days', value: 90 },
  { title: 'Last 180 days', value: 180 },
  { title: 'Last year', value: 365 },
]
const urgencyOptions = [
  { title: 'All urgencies', value: null },
  { title: 'Critical only', value: 'critical' },
  { title: 'High only', value: 'high' },
  { title: 'Medium only', value: 'medium' },
  { title: 'Low only', value: 'low' },
]

// Mirrors the New stock transfer wizard so a pre-filled draft reads the same.
const priorityOptions = [
  { value: 'low', label: 'Low', desc: 'No urgency — schedule within the week.', icon: 'mdi-arrow-down', color: 'grey' },
  { value: 'normal', label: 'Normal', desc: 'Standard timeline — ship within 2–3 days.', icon: 'mdi-circle-medium', color: 'primary' },
  { value: 'high', label: 'High', desc: 'Time-sensitive — dispatch same or next day.', icon: 'mdi-arrow-up', color: 'amber' },
  { value: 'urgent', label: 'Urgent', desc: 'Critical — immediate dispatch required.', icon: 'mdi-alert-decagram', color: 'error' },
]
const PRIORITY_FALLBACK = { value: 'normal', label: 'Normal', desc: '', icon: 'mdi-circle-medium', color: 'primary' }

function priorityMetaOf(value) {
  return priorityOptions.find(o => o.value === priorityKeyOf(value)) || PRIORITY_FALLBACK
}
function priorityLabel(value) {
  return priorityMetaOf(value).label
}
const reasonChips = [
  'Rebalance inventory across warehouses',
  'Stock replenishment — branch running low',
  'Emergency supply — urgent need at destination',
  'Seasonal demand adjustment',
  'Move short-dated stock before it expires',
]

const listPath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers'
    : '/ims/inventory/transfers',
)
const analyticsPath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers/analytics'
    : '/ims/inventory/transfers/analytics',
)

const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-shadow': brand.shadow.value,
}))

const branchOptions = computed(() => [
  { title: 'All branches', value: null },
  ...(branchStore.branches || []).map(b => ({ title: b.name, value: b.id })),
])

const score = computed(() => data.value?.score || {})
const summary = computed(() => data.value?.summary || {})
const scope = computed(() => data.value?.scope || {})
const health = computed(() => data.value?.branch_health || [])
const suggestions = computed(() => data.value?.suggestions || [])
const expiryRescue = computed(() => data.value?.expiry_rescue || [])
const deadStock = computed(() => data.value?.dead_stock || [])
const imbalances = computed(() => data.value?.imbalances || [])
const coverDays = computed(() => data.value?.filters?.cover_days ?? coverPreset.value)
const expiryDays = computed(() => data.value?.filters?.expiry_days ?? 90)

const filteredSuggestions = computed(() =>
  urgencyFilter.value
    ? suggestions.value.filter(s => s.urgency === urgencyFilter.value)
    : suggestions.value,
)

/** Only one row's detail panel is open at a time. */
const expandedSug = ref(null)
function toggleRowDetail(id) {
  expandedSug.value = expandedSug.value === id ? null : id
}

const filteredTotals = computed(() => ({
  units: filteredSuggestions.value.reduce((sum, s) => sum + Number(s.units || 0), 0),
  value: filteredSuggestions.value.reduce((sum, s) => sum + Number(s.value || 0), 0),
}))

// ── Formatting ──────────────────────────────────────────────────────────
function formatMoney(v) {
  const n = Number(v || 0)
  return `KES ${n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
function formatQty(v) {
  return Number(v || 0).toLocaleString()
}
function coverLabel(days) {
  if (days == null) return '—'
  const d = Number(days)
  if (d < 1) return '<1d'
  if (d < 60) return `${d.toFixed(d < 10 ? 1 : 0)}d`
  if (d < 365) return `${Math.round(d / 30)}mo`
  return '>1y'
}
function coverageLabel(h) {
  if (h.coverage_days == null) return 'no sales'
  return h.coverage_capped ? '>10y' : coverLabel(h.coverage_days)
}
/** Days-to-expiry as a compact label (30d / 8mo / 5y). */
function expiryLabel(days) {
  const d = Number(days)
  if (!isFinite(d)) return '—'
  if (d < 0) return 'expired'
  if (d < 60) return `${Math.round(d)}d`
  if (d < 365) return `${Math.round(d / 30)}mo`
  return `${(d / 365).toFixed(d < 3650 ? 1 : 0)}y`
}

// ── Palette / metadata ──────────────────────────────────────────────────
const URGENCY_META = {
  critical: { label: 'Critical', color: 'error', icon: 'mdi-alert-octagon', hex: '#DC2626' },
  high: { label: 'High', color: 'deep-orange', icon: 'mdi-alert-decagram', hex: '#EA580C' },
  medium: { label: 'Medium', color: 'amber', icon: 'mdi-alert-circle-outline', hex: '#F59E0B' },
  low: { label: 'Low', color: 'blue', icon: 'mdi-arrow-down-circle-outline', hex: '#3B82F6' },
}
function urgencyMeta(u) {
  return URGENCY_META[u] || URGENCY_META.low
}

const STATUS_META = {
  healthy: { label: 'Healthy', color: 'success' },
  watch: { label: 'Watch', color: 'warning' },
  at_risk: { label: 'At risk', color: 'error' },
}
function statusMeta(s) {
  return STATUS_META[s] || STATUS_META.watch
}

function ringStyle(score) {
  const v = Math.max(0, Math.min(100, Number(score || 0)))
  const color = v >= 80 ? '#10B981' : v >= 55 ? '#F59E0B' : '#EF4444'
  return {
    background: `conic-gradient(${color} ${v * 3.6}deg, rgba(var(--v-theme-on-surface), 0.08) 0deg)`,
    color,
  }
}

const SPREAD_PALETTE = ['#2F6DFF', '#14B8A6', '#F59E0B', '#8B5CF6', '#EF4444', '#0EA5E9', '#84CC16']
function spreadColor(i) {
  return SPREAD_PALETTE[i % SPREAD_PALETTE.length]
}

const scoreHex = computed(() => {
  const v = Number(score.value.overall ?? 100)
  if (v >= 80) return '#10B981'
  if (v >= 55) return '#F59E0B'
  return '#EF4444'
})
const scoreChipColor = computed(() => {
  const v = Number(score.value.overall ?? 100)
  if (v >= 80) return 'success'
  if (v >= 55) return 'warning'
  return 'error'
})
const gaugeDash = computed(() => {
  const v = Math.max(0, Math.min(100, Number(score.value.overall ?? 0)))
  const circ = 2 * Math.PI * 52
  return `${(circ * v) / 100} ${circ}`
})

const urgencyCounts = computed(() =>
  ['critical', 'high', 'medium'].map(key => ({
    key,
    label: URGENCY_META[key].label,
    color: URGENCY_META[key].color,
    count: suggestions.value.filter(s => s.urgency === key).length,
  })).filter(u => u.count > 0),
)

function toggleImbalance(idx) {
  if (openImbalance.has(idx)) openImbalance.delete(idx)
  else openImbalance.add(idx)
}

// ── Selection ───────────────────────────────────────────────────────────
function isSelected(id) {
  return selected.has(id)
}

function toggleSelect(id) {
  if (selected.has(id)) selected.delete(id)
  else selected.add(id)
}

const allSelected = computed(() =>
  filteredSuggestions.value.length > 0
  && filteredSuggestions.value.every(s => selected.has(s.id)),
)
const someSelected = computed(() => selectedCount.value > 0)

function toggleSelectAll(value) {
  if (value) filteredSuggestions.value.forEach(s => selected.add(s.id))
  else filteredSuggestions.value.forEach(s => selected.delete(s.id))
}

function clearSelection() {
  selected.clear()
}

const selectedSuggestions = computed(() =>
  suggestions.value.filter(s => selected.has(s.id)),
)

const selectedTotals = computed(() => {
  const rows = selectedSuggestions.value
  return {
    units: rows.reduce((sum, s) => sum + Number(s.units || 0), 0),
    value: rows.reduce((sum, s) => sum + Number(s.value || 0), 0),
    lanes: new Set(rows.map(s => `${s.source_branch_id}-${s.dest_branch_id}`)).size,
  }
})

// ── Bulk dialog: one draft per lane, pre-filled from the suggestions ────
const URGENCY_RANK = { critical: 3, high: 2, medium: 1, low: 0 }

function openBulkDialog() {
  if (!selectedCount.value) return
  const buckets = new Map()
  for (const s of selectedSuggestions.value) {
    const key = `${s.source_branch_id}-${s.dest_branch_id}`
    if (!buckets.has(key)) {
      buckets.set(key, {
        key,
        source_branch_id: s.source_branch_id,
        source_branch: s.source_branch,
        dest_branch_id: s.dest_branch_id,
        dest_branch: s.dest_branch,
        priority: s.priority || 'normal',
        parcel_count: 1,
        weight_kg: null,
        scheduled_pickup: null,
        scheduled_delivery: null,
        notes: '',
        reasons: [],
        lines: [],
      })
    }
    const g = buckets.get(key)
    // A lane keeps the highest priority across its suggestions.
    if (URGENCY_RANK[s.urgency] > URGENCY_RANK[priorityKeyOf(g.priority)]) {
      g.priority = s.priority || 'normal'
    }
    if (s.reason && !g.reasons.includes(s.reason)) g.reasons.push(s.reason)
    g.lines.push({
      key: s.id,
      suggestion: s,
      stock: s.source_stock_id,
      name: s.medication,
      category: s.category,
      unit_cost: s.units ? Number(s.value || 0) / Number(s.units) : 0,
      quantity: Number(s.units) || 1,
      source_qty: Number(s.source_qty) || Number(s.units) || 1,
      batch_id: s.batch_id || null,
      batch_number: s.batch_number || null,
      days_to_expiry: s.days_to_expiry ?? null,
      userEdited: false,
    })
  }

  const rows = [...buckets.values()]
  rows.forEach((g) => {
    if (!g.notes) {
      g.notes = g.reasons.length
        ? `${g.reasons[0]}. Suggested rebalance across ${g.lines.length} item${g.lines.length === 1 ? '' : 's'}.`
        : 'Suggested rebalance across warehouses.'
    }
  })
  groups.value = rows
  bulkStep.value = 0
  Object.assign(assignment.value, {
    type: null, driver_id: null, carrier_id: null, vehicle_id: null, vehicle_manual: '',
  })
  cargoDefaults.value = { parcel_count: 1, weight_kg: null }
  loadLogistics()
  bulkDialog.value = true
}

// ── Step navigation ─────────────────────────────────────────────────────
const bulkStepValid = computed(() => {
  if (bulkStep.value === 0) return routeStepValid.value
  if (bulkStep.value === 1) return groups.value.every(g => !deliveryBeforePickup(g))
  // Assignment and review are always reachable — everything there is optional.
  return true
})

const routeStepValid = computed(() =>
  groups.value.every(g =>
    g.lines.length > 0
    && g.source_branch_id
    && g.dest_branch_id
    && g.source_branch_id !== g.dest_branch_id
    && (g.notes || '').trim().length > 0
    && g.lines.every(qtyValid),
  ),
)

function goToStep(index) {
  // Only allow jumping backwards, or forwards when every earlier step is valid.
  if (index <= bulkStep.value) {
    bulkStep.value = index
    return
  }
  if (bulkStepValid.value) bulkStep.value = index
}

function nextBulkStep() {
  if (!bulkStepValid.value) return
  if (bulkStep.value < bulkSteps.length - 1) bulkStep.value++
}

function prevBulkStep() {
  if (bulkStep.value > 0) bulkStep.value--
}

// ── Cargo and schedule helpers ──────────────────────────────────────────
function toLocalInput(date) {
  const pad = n => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
    + `T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function prettyDateTime(value) {
  if (!value) return '—'
  const d = new Date(value)
  if (isNaN(d)) return value
  return d.toLocaleString(undefined, {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
  })
}

/** Pickup tomorrow at 09:00, delivery `days` later at 15:00. */
function setWindow(group, days) {
  const pickup = new Date()
  pickup.setDate(pickup.getDate() + 1)
  pickup.setHours(9, 0, 0, 0)
  const delivery = new Date(pickup)
  delivery.setDate(delivery.getDate() + days)
  delivery.setHours(15, 0, 0, 0)
  group.scheduled_pickup = toLocalInput(pickup)
  group.scheduled_delivery = toLocalInput(delivery)
}

function clearWindow(group) {
  group.scheduled_pickup = null
  group.scheduled_delivery = null
}

function deliveryBeforePickup(group) {
  if (!group.scheduled_pickup || !group.scheduled_delivery) return false
  const p = new Date(group.scheduled_pickup)
  const d = new Date(group.scheduled_delivery)
  if (isNaN(p) || isNaN(d)) return false
  return d < p
}

function applyCargoDefaults() {
  groups.value.forEach((g) => {
    g.parcel_count = cargoDefaults.value.parcel_count ?? 1
    g.weight_kg = cargoDefaults.value.weight_kg ?? null
  })
}

/** Copy the first lane's cargo + schedule onto every other lane. */
function applyScheduleToAll() {
  const first = groups.value[0]
  if (!first) return
  groups.value.forEach((g, i) => {
    if (i === 0) return
    g.priority = first.priority
    g.parcel_count = first.parcel_count
    g.weight_kg = first.weight_kg
    g.scheduled_pickup = first.scheduled_pickup
    g.scheduled_delivery = first.scheduled_delivery
  })
  showSnack('Cargo and schedule copied to all transfers', 'info')
}

// ── Assignment step ─────────────────────────────────────────────────────
async function loadLogistics() {
  if (logisticsLoaded.value) return
  logisticsLoaded.value = true
  $api.get('/logistics/drivers/')
    .then((r) => {
      const list = r.data?.results || r.data || []
      driverOptions.value = (Array.isArray(list) ? list : []).filter(d => d.is_active !== false)
    })
    .catch(() => {})
  $api.get('/logistics/carriers/')
    .then((r) => {
      const list = r.data?.results || r.data || []
      carrierOptions.value = (Array.isArray(list) ? list : []).filter(c => c.is_active !== false)
    })
    .catch(() => {})
  $api.get('/logistics/vehicles/')
    .then((r) => {
      const list = r.data?.results || r.data || []
      vehicleOptions.value = (Array.isArray(list) ? list : []).map(v => ({
        id: v.id,
        label: v.display_name || `${v.plate_number || ''}${v.name ? ' · ' + v.name : ''}`.trim(),
      }))
    })
    .catch(() => {})
}

const availableDrivers = computed(() =>
  driverOptions.value.filter(d => d.status === 'available'),
)
const driverChoices = computed(() =>
  availableDrivers.value.map(d => ({
    id: d.id,
    label: `${d.full_name}${d.assigned_vehicle_label ? ' · ' + d.assigned_vehicle_label : ''}`,
  })),
)
const carrierChoices = computed(() =>
  carrierOptions.value.map(c => ({ id: c.id, label: c.name })),
)
const vehicleChoices = computed(() => vehicleOptions.value)

function clearAssignment() {
  assignment.value.type = null
  assignment.value.driver_id = null
  assignment.value.carrier_id = null
  assignment.value.vehicle_id = null
  assignment.value.vehicle_manual = ''
}

const assignmentIcon = computed(() => {
  if (assignment.value.type === 'internal') return 'mdi-account-tie-hat'
  if (assignment.value.type === 'carrier') return 'mdi-truck-fast'
  return 'mdi-clock-outline'
})

const assignmentLabel = computed(() => {
  const a = assignment.value
  const vehicle = a.vehicle_id
    ? (vehicleOptions.value.find(v => v.id === a.vehicle_id)?.label || `Vehicle #${a.vehicle_id}`)
    : a.vehicle_manual
  if (a.type === 'internal' && a.driver_id) {
    const d = driverOptions.value.find(x => x.id === a.driver_id)
    return `${d?.full_name || 'Driver'}${vehicle ? ' · ' + vehicle : ''}`
  }
  if (a.type === 'carrier' && a.carrier_id) {
    const c = carrierOptions.value.find(x => x.id === a.carrier_id)
    return `${c?.name || 'Carrier'}${vehicle ? ' · ' + vehicle : ''}`
  }
  if (a.type === 'internal') return 'Internal driver — choose one to firm it up'
  if (a.type === 'carrier') return 'External carrier — choose one to firm it up'
  return 'No assignment — unassigned'
})

const assignmentSummary = computed(() => {
  const a = assignment.value
  if (a.type === 'internal' && !a.driver_id) return 'Pick a driver, or leave it for dispatch.'
  if (a.type === 'carrier' && !a.carrier_id) return 'Pick a carrier, or leave it for dispatch.'
  if (groups.value.length > 1) {
    return `This assignment will be applied to all ${groups.value.length} drafts.`
  }
  return ''
})

function priorityKeyOf(value) {
  return ['low', 'normal', 'high', 'urgent'].includes(value) ? value : 'normal'
}

function closeBulkDialog() {
  bulkDialog.value = false
  groups.value = []
  bulkStep.value = 0
}

function removeLine(group, index) {
  if (group.lines.length <= 1) return
  group.lines.splice(index, 1)
}

function groupUnits(group) {
  return group.lines.reduce((sum, l) => sum + (Number(l.quantity) || 0), 0)
}

function groupValue(group) {
  return group.lines.reduce((sum, l) => sum + lineValue(l), 0)
}

function lineValue(line) {
  return (Number(line.quantity) || 0) * (Number(line.unit_cost) || 0)
}

function qtyValid(line) {
  const qty = Number(line.quantity) || 0
  return qty >= 1 && qty <= (Number(line.source_qty) || 0)
}

function groupWarnings(group) {
  const out = []
  group.lines.forEach((l) => {
    const qty = Number(l.quantity) || 0
    if (qty < 1) out.push(`${l.name}: quantity must be at least 1.`)
    else if (qty > Number(l.source_qty || 0)) {
      out.push(`${l.name}: only ${formatQty(l.source_qty)} units are available at ${group.source_branch}.`)
    }
  })
  return out
}

const bulkTotals = computed(() => {
  let lines = 0
  let units = 0
  let value = 0
  groups.value.forEach((g) => {
    lines += g.lines.length
    units += groupUnits(g)
    value += groupValue(g)
  })
  return { lines, units, value }
})

const canSaveBulk = computed(() =>
  groups.value.length > 0
  && groups.value.every(g =>
    g.lines.length > 0
    && g.source_branch_id
    && g.dest_branch_id
    && g.source_branch_id !== g.dest_branch_id
    && (g.notes || '').trim().length > 0
    && g.lines.every(qtyValid),
  ),
)

/** Human-readable explanation of why the drafts cannot be saved yet. */
const bulkBlockReason = computed(() => {
  if (!groups.value.length) return 'Nothing selected — go back and pick at least one recommendation.'
  for (const g of groups.value) {
    const lane = `${g.source_branch} → ${g.dest_branch}`
    if (!g.lines.length) return `${lane}: add at least one item line.`
    if (!g.source_branch_id || !g.dest_branch_id) return `${lane}: source and destination are required.`
    if (g.source_branch_id === g.dest_branch_id) return `${lane}: source and destination must differ.`
    if (!(g.notes || '').trim()) return `${lane}: a reason for the move is required.`
    const bad = g.lines.find(l => !qtyValid(l))
    if (bad) {
      const qty = Number(bad.quantity) || 0
      return qty < 1
        ? `${lane}: ${bad.name} needs a quantity of at least 1.`
        : `${lane}: ${bad.name} exceeds the ${formatQty(bad.source_qty)} units available.`
    }
    if (deliveryBeforePickup(g)) return `${lane}: the delivery time must be after the pickup time.`
  }
  return ''
})

// ── Data ────────────────────────────────────────────────────────────────
function applyCover(value) {
  coverPreset.value = value
  load()
}

async function load() {
  loading.value = true
  try {
    const params = {
      cover_days: coverPreset.value,
      window: windowDays.value,
      limit: 60,
    }
    if (branchFilter.value) params.branch = branchFilter.value
    else if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
    const res = await $api.get('/inventory/transfers/suggestions/', { params })
    data.value = res.data
    // Drop selections that no longer exist in the refreshed plan.
    const live = new Set((res.data?.suggestions || []).map(s => s.id))
    ;[...selected].forEach(id => { if (!live.has(id)) selected.delete(id) })
  } catch {
    data.value = null
    showSnack('Could not scan branch inventory.', 'error')
  } finally {
    loading.value = false
  }
}

function buildPayload(group) {
  const a = assignment.value
  return {
    source_branch: group.source_branch_id,
    dest_branch: group.dest_branch_id,
    priority: priorityKeyOf(group.priority),
    parcel_count: Number(group.parcel_count) || null,
    weight_kg: group.weight_kg === '' || group.weight_kg === null
      ? null
      : Number(group.weight_kg),
    scheduled_pickup: group.scheduled_pickup || null,
    scheduled_delivery: group.scheduled_delivery || null,
    assigned_driver: a.type === 'internal' ? (a.driver_id || null) : null,
    assigned_carrier: a.type === 'carrier' ? (a.carrier_id || null) : null,
    assigned_vehicle: a.vehicle_id || null,
    assigned_vehicle_note: a.vehicle_id ? '' : (a.vehicle_manual || ''),
    notes: (group.notes || '').trim(),
    status: 'draft',
    lines: group.lines.map(l => ({
      stock: l.stock,
      quantity: Number(l.quantity),
      ...(l.batch_id ? { batch: l.batch_id } : {}),
    })),
  }
}

async function saveBulk(submit) {
  if (!canSaveBulk.value || saving.value) return
  saving.value = true
  const created = []
  const failed = []
  try {
    for (const group of groups.value) {
      try {
        const { data: saved } = await $api.post('/inventory/transfers/', buildPayload(group))
        created.push(saved)
        if (submit) {
          try {
            await $api.post(`/inventory/transfers/${saved.id}/submit/`)
          } catch (err) {
            failed.push(
              `${saved.reference}: saved as a draft but could not be submitted — ` +
              (err?.response?.data?.detail || 'submit it from the list.'),
            )
          }
        }
      } catch (err) {
        const detail = err?.response?.data
        const msg = typeof detail === 'string'
          ? detail
          : detail?.detail
            || (Array.isArray(detail?.lines) ? detail.lines[0] : null)
            || detail?.dest_branch
            || detail?.source_branch
            || 'Could not create this transfer.'
        failed.push(`${group.source_branch} → ${group.dest_branch}: ${String(msg).slice(0, 120)}`)
      }
    }
  } finally {
    saving.value = false
  }

  if (created.length) {
    const label = created.length === 1
      ? created[0].reference
      : `${created.length} drafts`
    showSnack(
      failed.length
        ? `${label} created · ${failed.length} failed — ${failed[0]}`
        : submit
          ? `${label} created and submitted`
          : `${label} saved as draft${created.length === 1 ? '' : 's'}`,
      failed.length ? 'warning' : 'success',
      !failed.length,
    )
    closeBulkDialog()
    clearSelection()
    await load()
  } else if (failed.length) {
    showSnack(failed[0], 'error')
  }
}

async function downloadPdf() {
  exportingPdf.value = true
  try {
    const params = { cover_days: coverPreset.value, window: windowDays.value }
    if (branchFilter.value) params.branch = branchFilter.value
    const res = await $api.get('/inventory/transfers/suggestions-pdf/', {
      params,
      responseType: 'blob',
      timeout: 60000,
    })
    const blob = new Blob([res.data], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer-suggestions_${new Date().toISOString().slice(0, 10)}.pdf`
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 2000)
    showSnack('Suggestions report downloaded', 'success')
  } catch {
    showSnack('Could not generate the PDF report.', 'error')
  } finally {
    exportingPdf.value = false
  }
}

// Keep the visible branch filter in sync with the globally selected branch so
// the select never says "All branches" while the request is scoped.
onMounted(() => {
  if (branchStore.currentBranchId) branchFilter.value = branchStore.currentBranchId
  load()
})
</script>

<style scoped>
/* ═══════════════════ HERO ═══════════════════ */
.tgs-hero {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  padding: 22px 24px 17px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #339cff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.tgs-hero-glow {
  position: absolute;
  width: 320px;
  height: 320px;
  border-radius: 50%;
  top: -160px;
  right: -90px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.28), transparent 65%);
  pointer-events: none;
}
.tgs-hero-glow-2 {
  top: auto;
  bottom: -190px;
  right: auto;
  left: -110px;
  width: 280px;
  height: 280px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.18), transparent 68%);
}
.tgs-hero-icon {
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
.tgs-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  opacity: 0.86;
}
.tgs-title {
  font-size: 25px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  margin: 2px 0 3px;
}
.tgs-sub {
  font-size: 12.5px;
  opacity: 0.9;
  max-width: 660px;
}
.tgs-hero-iconbtn { color: #fff !important; }
.tgs-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #fff !important;
  border: 1px solid rgba(255, 255, 255, 0.26);
}
.tgs-hero-btn-glass:hover { background: rgba(255, 255, 255, 0.24) !important; }
.tgs-hero-btn-strong {
  background: #fff !important;
  color: rgb(var(--v-theme-primary)) !important;
  font-weight: 700;
  box-shadow: 0 6px 16px -6px rgba(15, 23, 42, 0.45);
}
.tgs-hero-facts {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.tgs-hero-fact-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.tgs-fact-suffix { font-size: 11px; opacity: 0.7; font-weight: 600; }
.tgs-hero-fact-label {
  font-size: 10.5px;
  letter-spacing: 0.03em;
  opacity: 0.82;
  margin-top: 1px;
}
.tgs-hero-divider {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.24);
}

/* ═══════════════════ FILTER BAR ═══════════════════ */
.tgs-filterbar { background: rgba(var(--v-theme-on-surface), 0.015); }
.tgs-select { max-width: 172px; min-width: 158px; }
.tgs-presets :deep(.v-chip) { font-size: 11px; font-weight: 600; letter-spacing: 0; }

/* ═══════════════════ SCORE GAUGE ═══════════════════ */
.tgs-score-card { overflow: hidden; }
.tgs-gauge {
  position: relative;
  width: 150px;
  height: 150px;
  margin: 0 auto;
}
.tgs-gauge-svg { width: 100%; height: 100%; transform: rotate(-90deg); }
.tgs-gauge-track {
  fill: none;
  stroke: rgba(var(--v-theme-on-surface), 0.08);
  stroke-width: 10;
}
.tgs-gauge-fill {
  fill: none;
  stroke-width: 10;
  transition: stroke-dasharray 0.5s ease;
}
.tgs-gauge-center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
.tgs-gauge-value {
  font-size: 34px;
  font-weight: 800;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.tgs-gauge-grade {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.09em;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-top: 3px;
}
.tgs-kv {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 12.5px;
  padding: 3px 0;
  color: rgba(var(--v-theme-on-surface), 0.66);
}
.tgs-kv strong {
  color: rgba(var(--v-theme-on-surface), 0.92);
  font-variant-numeric: tabular-nums;
}
.tgs-neg { color: #DC2626 !important; }
.tgs-pos { color: #0F9D6F !important; }
.tgs-warn { color: #B45309 !important; }

/* ═══════════════════ BRANCH HEALTH ═══════════════════ */
.tgs-health-row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tgs-health-row:last-child { border-bottom: none; }
.tgs-health-row:hover { background: rgba(var(--v-theme-primary), 0.025); }
.tgs-health-ring {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  font-size: 12px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.tgs-health-ring::before {
  content: '';
  position: absolute;
  inset: 4px;
  border-radius: 50%;
  background: rgb(var(--v-theme-surface));
}
.tgs-health-ring span { position: relative; z-index: 1; }
.tgs-health-body { flex: 1; min-width: 0; }
.tgs-health-name {
  font-size: 13px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.92);
}
.tgs-health-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 5px;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-top: 3px;
}
.tgs-health-meta b {
  color: rgba(var(--v-theme-on-surface), 0.85);
  font-variant-numeric: tabular-nums;
}
.tgs-health-flags {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-top: 6px;
}
.tgs-flag {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1.5px 6px;
  border-radius: 6px;
  font-size: 10px;
  font-weight: 700;
}
.tgs-flag-warn { background: rgba(245, 158, 11, 0.13); color: #B45309; }
.tgs-flag-bad { background: rgba(220, 38, 38, 0.11); color: #B91C1C; }
.tgs-flag-info { background: rgba(59, 130, 246, 0.11); color: #1D4ED8; }
.tgs-health-right {
  display: flex;
  gap: 14px;
  flex-shrink: 0;
  text-align: right;
}
.tgs-health-stat { display: flex; flex-direction: column; }
.tgs-health-stat-value {
  font-size: 13px;
  font-weight: 800;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.tgs-health-stat-label {
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tgs-sep { opacity: 0.45; }

/* ═══════════════════ SECTION HEAD ═══════════════════ */
.tgs-section-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 22px 0 12px;
}

/* ═══════════════════ SUGGESTIONS TABLE ═══════════════════ */
.tgs-table-card { overflow: hidden; }
.tgs-table-scroll {
  overflow-x: auto;
  overflow-y: visible;
  max-height: 68vh;
}
.tgs-table {
  width: 100%;
  min-width: 980px;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 12px;
}
.tgs-table thead th {
  position: sticky;
  top: 0;
  z-index: 3;
  padding: 8px 10px;
  text-align: left;
  white-space: nowrap;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.07em;
  color: rgba(var(--v-theme-on-surface), 0.5);
  background: rgb(var(--v-theme-surface));
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.1);
}
.tgs-th-pick { width: 42px; }
.tgs-th-rank { width: 38px; }
.tgs-th-num,
.tgs-th-cov { text-align: right !important; }
.tgs-th-num { min-width: 104px; }
.tgs-th-pri { min-width: 140px; }
.tgs-th-batch { min-width: 122px; }
.tgs-th-act { width: 148px; }

.tgs-tr {
  cursor: pointer;
  transition: background 0.12s ease;
}
.tgs-tr > td {
  padding: 8px 10px;
  vertical-align: middle;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.tgs-tr:hover > td { background: rgba(var(--v-theme-primary), 0.03); }
.tgs-tr.is-selected > td { background: rgba(var(--v-theme-primary), 0.06); }
.tgs-tr.is-open > td { background: rgba(var(--v-theme-primary), 0.045); }
.tgs-tr.is-critical > td:first-child { box-shadow: inset 3px 0 0 #DC2626; }
.tgs-tr.is-high > td:first-child { box-shadow: inset 3px 0 0 #EA580C; }
.tgs-tr.is-medium > td:first-child { box-shadow: inset 3px 0 0 #F59E0B; }
.tgs-tr.is-low > td:first-child { box-shadow: inset 3px 0 0 #3B82F6; }

.tgs-td-pick { width: 42px; padding-right: 0 !important; }
.tgs-td-rank {
  font-size: 10.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.35);
  font-variant-numeric: tabular-nums;
}
.tgs-td-item { min-width: 205px; max-width: 300px; }
.tgs-cell-name {
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.94);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-cell-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 2px;
  min-width: 0;
}
.tgs-cell-tag {
  flex-shrink: 0;
  padding: 1px 6px;
  border-radius: 5px;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.tgs-cell-muted {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-cell-sub {
  display: flex;
  align-items: center;
  gap: 3px;
  margin-top: 2px;
  font-size: 9.5px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.tgs-td-route { min-width: 168px; }
.tgs-cell-route {
  display: flex;
  align-items: center;
  gap: 5px;
  white-space: nowrap;
}
.tgs-cell-branch {
  font-size: 11px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 6px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  max-width: 130px;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tgs-cell-branch.is-dest {
  background: rgba(var(--v-theme-primary), 0.11);
  color: rgb(var(--v-theme-primary));
}
.tgs-td-num {
  text-align: right;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.tgs-td-send {
  font-size: 14px;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
}
.tgs-td-send-sub {
  font-size: 9.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-top: 1px;
}
.tgs-td-muted { color: rgba(var(--v-theme-on-surface), 0.6); }
.tgs-td-sub {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
  font-size: 9.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-top: 1px;
  white-space: nowrap;
}
.tgs-td-sub b { color: rgba(var(--v-theme-on-surface), 0.75); }
.tgs-td-sub.is-empty { font-style: italic; opacity: 0.75; }
.tgs-td-pri { white-space: nowrap; }
.tgs-td-batch { white-space: nowrap; max-width: 150px; }
.tgs-td-act { width: 150px; }
.tgs-act-wrap {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 2px;
}

.tgs-tr-detail > td {
  padding: 0 10px 10px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  background: rgba(var(--v-theme-primary), 0.03);
}
.tgs-detail-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 10px 20px;
  align-items: center;
  padding: 10px 12px;
  border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.tgs-detail-main {
  flex: 1 1 320px;
  min-width: 220px;
  font-size: 11.5px;
  line-height: 1.55;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.tgs-detail-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 22px;
}
.tgs-detail-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tgs-detail-value {
  font-size: 12px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  margin-top: 1px;
}

.tgs-table-foot {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 14px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.02);
}

.tgs-cap { text-transform: capitalize; }

.tgs-btn-create {
  background: rgb(var(--v-theme-primary)) !important;
  color: #fff !important;
  font-weight: 700;
  font-size: 11.5px;
  letter-spacing: 0.01em;
}
.tgs-btn-select {
  background: rgba(var(--v-theme-primary), 0.1) !important;
  color: rgb(var(--v-theme-primary)) !important;
  font-weight: 700;
  font-size: 11.5px;
}
.tgs-btn-select:hover { background: rgba(var(--v-theme-primary), 0.18) !important; }
.tgs-btn-selected {
  background: rgba(16, 185, 129, 0.14) !important;
  color: #0F9D6F !important;
  font-weight: 700;
  font-size: 11.5px;
}

/* ═══════════════════ SELECTION BAR ═══════════════════ */
.tgs-selbar {
  position: fixed;
  left: 50%;
  bottom: 22px;
  transform: translateX(-50%);
  z-index: 6;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  box-shadow: 0 18px 40px -16px rgba(15, 23, 42, 0.5);
  white-space: nowrap;
  animation: tgs-selbar-in 0.18s ease-out;
}
@keyframes tgs-selbar-in {
  from { opacity: 0; transform: translate(-50%, 10px); }
  to   { opacity: 1; transform: translate(-50%, 0); }
}
.tgs-selbar-count {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12.5px;
  color: rgb(var(--v-theme-primary));
  white-space: nowrap;
}
.tgs-selbar-count b { font-size: 14px; }
.tgs-selbar-sep {
  width: 1px;
  height: 22px;
  background: rgba(var(--v-theme-on-surface), 0.12);
}
.tgs-selbar-stat {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
  white-space: nowrap;
}
.tgs-selbar-stat-value {
  font-size: 12.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.tgs-selbar-stat-label {
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tgs-selbar-clear { color: rgba(var(--v-theme-on-surface), 0.6) !important; }
.tgs-selbar-go {
  background: rgb(var(--v-theme-primary)) !important;
  color: #fff !important;
  font-weight: 700;
}
@media (max-width: 780px) {
  .tgs-selbar { gap: 9px; padding: 7px 9px; }
  .tgs-selbar-sep,
  .tgs-selbar-stat-lane { display: none; }
}

/* ═══════════════════ BULK DIALOG ═══════════════════ */
.tgs-dlg-head {
  position: relative;
  overflow: hidden;
  padding: 16px 20px 14px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #339cff) 100%
  );
}
.tgs-head-chip {
  background: rgba(255, 255, 255, 0.22) !important;
  color: #fff !important;
  font-weight: 700;
}
.tgs-dlg-summary {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tgs-dlg-sum-item {
  padding: 9px 14px;
  background: rgb(var(--v-theme-surface));
}
.tgs-dlg-sum-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tgs-dlg-sum-value {
  font-size: 14px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  margin-top: 1px;
}

.tgs-grp {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 14px;
  padding: 12px 14px 14px;
  margin-bottom: 14px;
  background: rgba(var(--v-theme-on-surface), 0.012);
}

/* ── Step rail (mirrors the New stock transfer wizard) ── */
.tgs-steps {
  display: flex;
  align-items: center;
  overflow-x: auto;
}
.tgs-step {
  display: flex;
  align-items: center;
  gap: 7px;
  cursor: pointer;
  flex-shrink: 0;
  opacity: 0.55;
  transition: opacity 0.15s ease;
}
.tgs-step:hover { opacity: 0.85; }
.tgs-step-active { opacity: 1; }
.tgs-step-done { opacity: 0.9; }
.tgs-step-dot {
  width: 26px;
  height: 26px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.6);
  transition: background 0.15s ease, color 0.15s ease;
}
.tgs-step-active .tgs-step-dot {
  background: rgb(var(--v-theme-primary));
  color: #fff;
}
.tgs-step-done .tgs-step-dot {
  background: rgba(16, 185, 129, 0.16);
  color: #0F9D6F;
}
.tgs-step-text {
  font-size: 11.5px;
  font-weight: 700;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.tgs-step-active .tgs-step-text { color: rgba(var(--v-theme-on-surface), 0.95); }
.tgs-step-line {
  flex: 1 1 12px;
  min-width: 12px;
  height: 2px;
  margin: 0 8px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.1);
}
.tgs-step-line-done { background: rgba(16, 185, 129, 0.4); }

.tgs-dlg-section-head { margin: 0 0 4px; }

/* ── Cargo step ── */
.tgs-cargo-all {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 12px;
  background: rgba(var(--v-theme-primary), 0.045);
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
}
.tgs-cargo-default { max-width: 190px; min-width: 160px; }

.tgs-pick-label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.07em;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-bottom: 5px;
}
.tgs-priority-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 8px;
}
.tgs-priority-card {
  text-align: left;
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.tgs-priority-card:hover { border-color: rgba(var(--v-theme-primary), 0.4); }
.tgs-priority-card.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.055);
}
.tgs-priority-label {
  font-size: 12px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.9);
}
.tgs-priority-desc {
  font-size: 9.5px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 3px;
}
.tgs-field-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 10px;
}

/* ── Assignment step ── */
.tgs-assign-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 10px;
}
.tgs-assign-card {
  position: relative;
  text-align: left;
  padding: 12px 13px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.tgs-assign-card:hover { border-color: rgba(var(--v-theme-primary), 0.4); }
.tgs-assign-card.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.055);
}
.tgs-assign-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(var(--v-theme-primary), 0.1);
  color: rgb(var(--v-theme-primary));
  margin-bottom: 7px;
}
.tgs-assign-title {
  font-size: 12.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.92);
}
.tgs-assign-sub {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 1px;
}
.tgs-assign-check {
  position: absolute;
  top: 10px;
  right: 10px;
}

/* ── Review step ── */
.tgs-rev-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 14px;
  padding: 12px 14px 13px;
  background: rgba(var(--v-theme-on-surface), 0.012);
}
.tgs-rev-top {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.tgs-rev-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 22px;
  margin: 10px 0 8px;
}
.tgs-rev-label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tgs-rev-value {
  font-size: 13px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.tgs-rev-schedule {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-bottom: 8px;
}
.tgs-rev-lines {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  border-radius: 10px;
  overflow: hidden;
}
.tgs-rev-line {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 9px;
  font-size: 11.5px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.045);
}
.tgs-rev-line:last-child { border-bottom: none; }
.tgs-rev-line-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.tgs-rev-batch {
  font-size: 9.5px;
  font-weight: 700;
  padding: 1px 6px;
  border-radius: 5px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  white-space: nowrap;
}
.tgs-rev-line-qty {
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  min-width: 52px;
  text-align: right;
}
.tgs-rev-line-val {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  min-width: 64px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.tgs-rev-notes {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin-top: 9px;
  font-size: 10.5px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.tgs-rev-assign {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tgs-grp-head {
  display: flex;
  align-items: center;
  gap: 11px;
  flex-wrap: wrap;
  margin-bottom: 11px;
}
.tgs-grp-index {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
}
.tgs-grp-route-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-bottom: 2px;
}
.tgs-wh-chip {
  display: inline-block;
  padding: 3px 9px;
  border-radius: 8px;
  font-size: 11.5px;
  font-weight: 700;
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.tgs-wh-chip-dest {
  background: rgba(var(--v-theme-primary), 0.11);
  color: rgb(var(--v-theme-primary));
}
.tgs-route-arrow { opacity: 0.45; }
.tgs-grp-totals { text-align: right; }

.tgs-grp-fields {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
.tgs-grp-priority { max-width: 190px; min-width: 170px; }
.tgs-grp-parcels { max-width: 150px; min-width: 130px; }
.tgs-grp-notes { margin-top: 10px; }

.tgs-grp-lines {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 11px;
  overflow: hidden;
}
.tgs-grp-line {
  display: grid;
  grid-template-columns: minmax(0, 2.2fr) 96px 92px 76px 90px 32px;
  align-items: center;
  gap: 8px;
  padding: 7px 10px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tgs-grp-line:last-child { border-bottom: none; }
.tgs-grp-line-head {
  background: rgba(var(--v-theme-on-surface), 0.03);
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.45);
  padding-top: 5px;
  padding-bottom: 5px;
}
.tgs-line-item {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.tgs-line-icon { color: rgba(var(--v-theme-primary), 0.75); flex-shrink: 0; }
.tgs-line-name {
  font-size: 11.5px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-line-meta {
  font-size: 9.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-line-num {
  font-size: 11.5px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.tgs-batch-pill {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 6px;
  font-size: 9.5px;
  font-weight: 700;
  background: rgba(var(--v-theme-on-surface), 0.06);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}
.tgs-qty-field :deep(input) {
  text-align: right;
  font-weight: 700;
  font-size: 11.5px;
}
.tgs-qty-field :deep(.v-field) { min-height: 32px; }
.tgs-qty-field :deep(.v-field__input) { padding-top: 4px; padding-bottom: 4px; }

/* ═══════════════════ EMPTY ═══════════════════ */
.tgs-mini-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tgs-mini-row:last-child { border-bottom: none; }
.tgs-mini-icon {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.tgs-mini-icon.is-warn { background: rgba(234, 88, 12, 0.1); }
.tgs-mini-icon.is-info { background: rgba(245, 158, 11, 0.1); }
.tgs-mini-body { flex: 1; min-width: 0; }
.tgs-mini-title {
  font-size: 12px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-mini-sub {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-mini-right { text-align: right; flex-shrink: 0; }
.tgs-mini-value {
  font-size: 13px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

/* ═══════════════════ IMBALANCE MATRIX ═══════════════════ */
.tgs-matrix-row { border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05); }
.tgs-matrix-row:last-child { border-bottom: none; }
.tgs-matrix-head {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 10px 14px;
  background: transparent;
  border: none;
  text-align: left;
  cursor: pointer;
  color: inherit;
  font: inherit;
}
.tgs-matrix-head:hover { background: rgba(var(--v-theme-primary), 0.03); }
.tgs-matrix-caret { color: rgba(var(--v-theme-on-surface), 0.4); flex-shrink: 0; }
.tgs-matrix-name {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12.5px;
  font-weight: 600;
}
.tgs-matrix-name > span:first-child {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tgs-matrix-cat {
  font-size: 9.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.05);
  padding: 1px 5px;
  border-radius: 5px;
  flex-shrink: 0;
}
.tgs-matrix-total {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}
.tgs-matrix-spread { width: 120px; flex-shrink: 0; }
.tgs-spread-track {
  display: flex;
  height: 7px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.tgs-spread-seg { height: 100%; }
.tgs-matrix-detail {
  padding: 4px 14px 12px 40px;
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.tgs-matrix-blocked {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10.5px;
  color: #B45309;
  margin-bottom: 6px;
}
.tgs-matrix-table {
  width: 100%;
  border-collapse: collapse;
}
.tgs-matrix-table th {
  padding: 5px 6px;
  text-align: left;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.tgs-matrix-table td {
  padding: 5px 6px;
  font-size: 11.5px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.04);
  font-variant-numeric: tabular-nums;
}
.tgs-matrix-table tr:last-child td { border-bottom: none; }
.tgs-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  margin-right: 5px;
  vertical-align: middle;
}

/* ═══════════════════ EMPTY ═══════════════════ */
.tgs-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 26px 16px;
}
.tgs-empty-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 34px 20px;
  border-radius: 16px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.tgs-footnote {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin-top: 18px;
  font-size: 11.5px;
  line-height: 1.6;
  color: rgba(var(--v-theme-on-surface), 0.5);
}

@media (max-width: 960px) {
  .tgs-hero-divider-lg { display: none; }
  .tgs-title { font-size: 21px; }
  .tgs-matrix-spread { display: none; }
}
@media (max-width: 700px) {
  .tgs-table-scroll { max-height: none; }
  .tgs-health-right { display: none; }
}
</style>
