<template>
  <v-container fluid class="pa-3 pa-md-5 tro-page">
    <!-- ═══════════════════ HERO ═══════════════════ -->
    <div class="tro-hero mb-4" :style="heroTheme">
      <span class="tro-hero-glow" />
      <span class="tro-hero-glow tro-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="tro-hero-icon">
            <v-icon size="30">mdi-tune-variant</v-icon>
          </div>
          <div>
            <div class="tro-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              INVENTORY · LOGISTICS · OPTIMIZATION
            </div>
            <h1 class="tro-title">Transfer Optimization</h1>
            <div class="tro-sub">
              A ranked plan to cut cycle time, tighten receipts and stop paying for
              empty return trips
              <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="tro-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tro-hero-btn-glass"
            prepend-icon="mdi-chart-box-outline"
            :to="analyticsPath"
          >Analytics</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tro-hero-btn-green"
            prepend-icon="mdi-file-pdf-box"
            :loading="exportingPdf"
            @click="downloadPdf"
          >PDF Plan</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none tro-hero-btn-glass"
            prepend-icon="mdi-arrow-left"
            :to="listPath"
          >Transfers</v-btn>
        </div>
      </div>

      <div class="tro-hero-facts">
        <div class="tro-hero-fact">
          <div class="tro-hero-fact-value">{{ score.overall ?? '—' }}<span class="tro-fact-suffix">/100</span></div>
          <div class="tro-hero-fact-label">network health · grade {{ score.grade ?? '—' }}</div>
        </div>
        <span class="tro-hero-divider" />
        <div class="tro-hero-fact">
          <div class="tro-hero-fact-value">{{ summary.recommendations ?? 0 }}</div>
          <div class="tro-hero-fact-label">recommendations</div>
        </div>
        <span class="tro-hero-divider" />
        <div class="tro-hero-fact">
          <div class="tro-hero-fact-value">{{ summary.quick_wins ?? 0 }}</div>
          <div class="tro-hero-fact-label">quick wins</div>
        </div>
        <span class="tro-hero-divider tro-hero-divider-lg" />
        <div class="tro-hero-fact">
          <div class="tro-hero-fact-value">{{ formatMoney(summary.value_at_risk) }}</div>
          <div class="tro-hero-fact-label">value stuck in open transfers</div>
        </div>
      </div>
    </div>

    <!-- ═══════════════════ FILTER BAR ═══════════════════ -->
    <v-card rounded="xl" border class="mb-4 tro-filterbar">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <div class="d-flex align-center ga-2">
          <v-icon size="17" color="primary">mdi-filter-variant</v-icon>
          <span class="text-caption font-weight-bold text-uppercase" style="letter-spacing:.06em">
            Scope
          </span>
        </div>

        <v-chip-group v-model="rangePreset" mandatory selected-class="text-primary" class="tro-presets">
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
          v-model="severityFilter"
          :items="severityOptions"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          class="tro-select"
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
          class="tro-select"
          prepend-inner-icon="mdi-warehouse"
          @update:model-value="load"
        />
      </div>
    </v-card>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-4" rounded />

    <!-- ═══════════════════ SCORE + PILLARS ═══════════════════ -->
    <v-row dense>
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100 tro-scorecard">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Network health</div>
            <div class="text-caption text-medium-emphasis">
              Weighted across five operational pillars
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="d-flex justify-center">
              <div class="tro-gauge">
                <svg viewBox="0 0 140 140" class="tro-gauge-svg">
                  <circle
                    cx="70"
                    cy="70"
                    r="58"
                    fill="none"
                    stroke="currentColor"
                    class="tro-gauge-track"
                    stroke-width="11"
                  />
                  <circle
                    cx="70"
                    cy="70"
                    r="58"
                    fill="none"
                    :stroke="scoreColor"
                    stroke-width="11"
                    stroke-linecap="round"
                    :stroke-dasharray="gaugeDash"
                    transform="rotate(-90 70 70)"
                    class="tro-gauge-arc"
                  />
                </svg>
                <div class="tro-gauge-center">
                  <div class="tro-gauge-value" :style="{ color: scoreColor }">
                    {{ score.overall ?? '—' }}
                  </div>
                  <div class="tro-gauge-grade" :style="{ background: scoreWash }">
                    Grade {{ score.grade ?? '—' }}
                  </div>
                  <div class="tro-gauge-label">{{ score.label ?? 'No data' }}</div>
                </div>
              </div>
            </div>

            <div class="tro-pillars mt-4">
              <div v-for="p in pillars" :key="p.key" class="tro-pillar">
                <div class="tro-pillar-head">
                  <span class="tro-pillar-label">{{ p.label }}</span>
                  <span class="tro-pillar-weight">{{ Math.round(p.weight * 100) }}%</span>
                  <span class="tro-pillar-score" :style="{ color: pillarColor(p.score) }">
                    {{ p.score }}
                  </span>
                </div>
                <div class="tro-pillar-track">
                  <div
                    class="tro-pillar-fill"
                    :style="{ width: p.score + '%', background: pillarColor(p.score) }"
                  />
                  <span
                    class="tro-pillar-target"
                    :style="{ left: pillarTarget(p) + '%' }"
                    title="Target"
                  />
                </div>
                <div class="tro-pillar-note">{{ p.note }}</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="8">
        <v-row dense>
          <v-col v-for="t in summaryTiles" :key="t.title" cols="6" sm="4" lg="3">
            <div class="tro-tile" :style="{ '--tile-accent': t.hex }">
              <div class="tro-tile-icon">
                <v-icon size="17" :color="t.color">{{ t.icon }}</v-icon>
              </div>
              <div class="tro-tile-value">{{ t.value }}</div>
              <div class="tro-tile-title">{{ t.title }}</div>
              <div class="tro-tile-sub">{{ t.sub }}</div>
            </div>
          </v-col>

          <v-col cols="12">
            <v-card rounded="xl" border class="mt-1">
              <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
                <div>
                  <div class="text-subtitle-1 font-weight-bold">Executive read-out</div>
                  <div class="text-caption text-medium-emphasis">
                    What the numbers say about this network
                  </div>
                </div>
                <v-chip
                  size="small"
                  variant="tonal"
                  :color="scoreChipColor"
                  class="font-weight-bold"
                >{{ score.grade ?? '—' }} · {{ score.label ?? 'No data' }}</v-chip>
              </div>
              <v-divider />
              <v-card-text>
                <div class="tro-readout">
                  <div v-for="(line, i) in readout" :key="i" class="tro-readout-line">
                    <span class="tro-readout-bullet" :style="{ background: line.hex }" />
                    <span v-html="line.html" />
                  </div>
                </div>

                <v-divider class="my-4" />

                <div class="tro-stage-grid">
                  <div v-for="s in funnel" :key="s.key" class="tro-stage">
                    <div class="tro-stage-top">
                      <span class="tro-stage-label">{{ s.label }}</span>
                      <span class="tro-stage-count">{{ s.count }}</span>
                    </div>
                    <div class="tro-stage-track">
                      <div
                        class="tro-stage-fill"
                        :style="{ width: stageWidth(s) + '%', background: stageColor(s) }"
                      />
                    </div>
                    <div class="tro-stage-meta">
                      <span v-if="s.avg_hours != null">{{ fmtHours(s.avg_hours) }}</span>
                      <span v-else>—</span>
                      <span v-if="s.target_hours" class="tro-stage-target">
                        target {{ fmtHours(s.target_hours) }}
                      </span>
                    </div>
                  </div>
                </div>
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>
      </v-col>
    </v-row>

    <!-- ═══════════════════ RECOMMENDATIONS ═══════════════════ -->
    <div class="tro-section-head mt-6 mb-2">
      <div>
        <div class="text-subtitle-1 font-weight-bold">Priority action plan</div>
        <div class="text-caption text-medium-emphasis">
          Ranked by severity, impact and how easy each fix is to land
        </div>
      </div>
      <div class="d-flex align-center flex-wrap ga-2">
        <v-chip
          v-for="c in categoryChips"
          :key="c.value"
          :value="c.value"
          size="small"
          rounded="lg"
          :variant="categoryFilter === c.value ? 'flat' : 'tonal'"
          :color="categoryFilter === c.value ? 'primary' : undefined"
          class="text-none"
          @click="categoryFilter = categoryFilter === c.value ? null : c.value"
        >
          <v-icon size="13" start>{{ c.icon }}</v-icon>{{ c.label }}
        </v-chip>
      </div>
    </div>

    <div v-if="!filteredRecs.length" class="tro-empty-card">
      <v-icon size="42" color="green">mdi-check-decagram-outline</v-icon>
      <div class="text-subtitle-1 font-weight-bold mt-2">Nothing to fix here</div>
      <div class="text-caption text-medium-emphasis">
        No recommendations match the current scope and filters.
      </div>
    </div>

    <v-row v-else dense>
      <v-col v-for="rec in filteredRecs" :key="rec.id" cols="12" lg="6">
        <v-card
          rounded="xl"
          border
          class="h-100 tro-rec"
          :class="{ 'is-open': expanded.has(rec.id) }"
          :style="{ '--rec-accent': severityMeta(rec.severity).hex }"
        >
          <div class="tro-rec-top">
            <div class="tro-rec-rank">{{ rec.rank }}</div>
            <div class="tro-rec-head">
              <div class="d-flex align-center flex-wrap ga-2 mb-1">
                <v-chip
                  size="x-small"
                  variant="flat"
                  :color="severityMeta(rec.severity).color"
                  class="font-weight-bold text-uppercase"
                >
                  <v-icon size="11" start>{{ severityMeta(rec.severity).icon }}</v-icon>
                  {{ rec.severity }}
                </v-chip>
                <v-chip size="x-small" variant="tonal" class="font-weight-medium">
                  <v-icon size="11" start>{{ rec.category_icon }}</v-icon>{{ rec.category_label }}
                </v-chip>
                <v-chip
                  v-if="rec.quick_win"
                  size="x-small"
                  variant="flat"
                  color="green"
                  class="font-weight-bold"
                >QUICK WIN</v-chip>
              </div>
              <div class="tro-rec-title">{{ rec.title }}</div>
            </div>
            <div class="tro-rec-score">
              <div class="tro-rec-score-value">{{ rec.score }}</div>
              <div class="tro-rec-score-label">score</div>
            </div>
          </div>

          <div class="tro-rec-summary">{{ rec.summary }}</div>

          <div class="tro-rec-metrics">
            <div v-for="m in rec.metrics" :key="m.label" class="tro-rec-metric">
              <div class="tro-rec-metric-value">{{ m.value }}</div>
              <div class="tro-rec-metric-label">{{ m.label }}</div>
            </div>
          </div>

          <div class="tro-rec-effort">
            <div class="tro-effort-item">
              <span class="tro-effort-label">Impact</span>
              <span class="tro-effort-dots">
                <span
                  v-for="n in 3"
                  :key="n"
                  class="tro-effort-dot"
                  :class="{ on: n <= impactLevel(rec.impact) }"
                />
              </span>
            </div>
            <div class="tro-effort-item">
              <span class="tro-effort-label">Effort</span>
              <span class="tro-effort-dots">
                <span
                  v-for="n in 3"
                  :key="n"
                  class="tro-effort-dot tro-effort-dot-effort"
                  :class="{ on: n <= impactLevel(rec.effort) }"
                />
              </span>
            </div>
            <v-spacer />
            <v-btn
              size="x-small"
              variant="text"
              class="text-none font-weight-bold"
              :append-icon="expanded.has(rec.id) ? 'mdi-chevron-up' : 'mdi-chevron-down'"
              @click="toggle(rec.id)"
            >{{ expanded.has(rec.id) ? 'Hide plan' : 'View plan' }}</v-btn>
          </div>

          <v-expand-transition>
            <div v-show="expanded.has(rec.id)" class="tro-rec-detail">
              <div class="tro-rec-detail-text">{{ rec.detail }}</div>

              <div class="tro-rec-subhead">
                <v-icon size="13" color="primary">mdi-checkbox-marked-circle-outline</v-icon>
                Recommended actions
              </div>
              <div class="tro-rec-actions">
                <div v-for="(a, i) in rec.actions" :key="i" class="tro-rec-action">
                  <span class="tro-rec-action-index">{{ i + 1 }}</span>
                  <span>{{ a }}</span>
                </div>
              </div>

              <template v-if="rec.affected.length">
                <div class="tro-rec-subhead mt-3">
                  <v-icon size="13" color="primary">mdi-format-list-bulleted</v-icon>
                  {{ rec.affected.length }} affected
                </div>
                <div class="tro-rec-affected">
                  <div v-for="a in rec.affected" :key="a.reference" class="tro-rec-affected-row">
                    <span class="tro-rec-affected-ref">{{ a.reference }}</span>
                    <span class="tro-rec-affected-label">{{ a.label }}</span>
                    <span class="tro-rec-affected-detail">{{ a.detail }}</span>
                    <span class="tro-rec-affected-value">{{ a.value }}</span>
                  </div>
                </div>
              </template>

              <div
                v-if="rec.save_hours || rec.save_value || rec.save_units"
                class="tro-rec-savings"
              >
                <v-icon size="14" color="green">mdi-trending-up</v-icon>
                <span v-if="rec.save_hours">Recovers <strong>{{ fmtHours(rec.save_hours) }}</strong></span>
                <span v-if="rec.save_hours && (rec.save_value || rec.save_units)"> · </span>
                <span v-if="rec.save_value">unlocks <strong>{{ formatMoney(rec.save_value) }}</strong></span>
                <span v-if="rec.save_value && rec.save_units"> · </span>
                <span v-if="rec.save_units"><strong>{{ formatQty(rec.save_units) }}</strong> units</span>
              </div>
            </div>
          </v-expand-transition>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════════ LANES + CONSOLIDATION ═══════════════════ -->
    <v-row dense class="mt-2">
      <v-col cols="12" lg="7">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Lane balance</div>
            <div class="text-caption text-medium-emphasis">
              How evenly freight flows in both directions
            </div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!lanes.length" class="tro-empty">
              <v-icon size="30" color="grey-lighten-1">mdi-map-marker-path</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No lanes in this scope.</div>
            </div>
            <div v-else class="tro-lanes">
              <div v-for="l in lanes" :key="l.lane" class="tro-lane">
                <div class="tro-lane-top">
                  <span class="tro-lane-name">{{ l.lane }}</span>
                  <v-chip
                    size="x-small"
                    variant="tonal"
                    :color="laneColor(l.balance_pct)"
                    class="font-weight-bold"
                  >{{ l.balance_pct }}% balanced</v-chip>
                </div>
                <div class="tro-lane-bars">
                  <div class="tro-lane-bar-row">
                    <span class="tro-lane-dir">out</span>
                    <div class="tro-lane-track">
                      <div
                        class="tro-lane-fill"
                        :style="{ width: pctOf(l.forward, laneMax) + '%', background: brand.primary.value }"
                      />
                    </div>
                    <span class="tro-lane-count">{{ l.forward }}</span>
                  </div>
                  <div class="tro-lane-bar-row">
                    <span class="tro-lane-dir">back</span>
                    <div class="tro-lane-track">
                      <div
                        class="tro-lane-fill tro-lane-fill-back"
                        :style="{ width: pctOf(l.reverse, laneMax) + '%' }"
                      />
                    </div>
                    <span class="tro-lane-count">{{ l.reverse }}</span>
                  </div>
                </div>
                <div class="tro-lane-meta">
                  <span>{{ formatQty(l.units) }} units</span>
                  <span class="tro-sep">·</span>
                  <span>{{ formatMoney(l.value) }}</span>
                  <span class="tro-sep">·</span>
                  <span>transit {{ fmtHours(l.avg_transit_hours) }}</span>
                </div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="5">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2 d-flex align-center justify-space-between flex-wrap ga-2">
            <div>
              <div class="text-subtitle-1 font-weight-bold">Consolidation opportunities</div>
              <div class="text-caption text-medium-emphasis">
                Open transfers that could share a single run
              </div>
            </div>
            <v-chip v-if="consolidation.length" size="small" variant="tonal" color="primary"
                    class="font-weight-bold">{{ consolidation.length }}</v-chip>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!consolidation.length" class="tro-empty pa-6">
              <v-icon size="30" color="green">mdi-check-decagram-outline</v-icon>
              <div class="mt-2 text-body-2 font-weight-medium">No merge candidates</div>
              <div class="text-caption text-medium-emphasis">
                Every open transfer is on its own lane or timeline.
              </div>
            </div>
            <div v-else class="tro-consol">
              <div v-for="c in consolidation" :key="c.lane" class="tro-consol-row">
                <div class="tro-consol-icon">
                  <v-icon size="16" :color="brand.primary.value">mdi-call-merge</v-icon>
                </div>
                <div class="tro-consol-body">
                  <div class="tro-consol-lane">{{ c.lane }}</div>
                  <div class="tro-consol-refs">{{ c.references.join(' · ') }}</div>
                  <div class="tro-consol-meta">
                    {{ c.count }} transfers · {{ formatQty(c.units) }} units ·
                    {{ formatMoney(c.value) }}
                  </div>
                </div>
                <v-chip size="x-small" variant="flat" color="green" class="font-weight-bold">
                  −{{ c.count - 1 }} trip{{ c.count - 1 === 1 ? '' : 's' }}
                </v-chip>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════════ EXPIRY + CARRIERS + BRANCHES ═══════════════════ -->
    <v-row dense class="mt-2">
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Expiry risk in flight</div>
            <div class="text-caption text-medium-emphasis">
              Batches on open transfers expiring within 90 days
            </div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!expiryRisk.length" class="tro-empty pa-6">
              <v-icon size="30" color="green">mdi-shield-check-outline</v-icon>
              <div class="mt-2 text-body-2 font-weight-medium">No short-dated stock</div>
              <div class="text-caption text-medium-emphasis">
                Nothing in the pipeline expires within 90 days.
              </div>
            </div>
            <div v-else class="tro-expiry">
              <div v-for="e in expiryRisk" :key="e.reference + e.batch" class="tro-expiry-row">
                <div
                  class="tro-expiry-days"
                  :style="{ color: e.days_left <= 30 ? '#dc2626' : e.days_left <= 60 ? '#b45309' : '#64748b' }"
                >{{ e.days_left }}<span>d</span></div>
                <div class="tro-expiry-body">
                  <div class="tro-expiry-name">{{ e.stock }}</div>
                  <div class="tro-expiry-meta">
                    Batch {{ e.batch }} · expires {{ e.expiry }} · {{ e.reference }}
                  </div>
                </div>
                <div class="tro-expiry-qty">{{ formatQty(e.quantity) }}</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Carrier performance</div>
            <div class="text-caption text-medium-emphasis">
              Measured transit time per carrier
            </div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!carriers.length" class="tro-empty pa-6">
              <v-icon size="30" color="grey-lighten-1">mdi-truck-fast-outline</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">
                No carrier assignments recorded.
              </div>
            </div>
            <div v-else class="tro-carriers">
              <div v-for="c in carriers" :key="c.name" class="tro-carrier-row">
                <div class="tro-carrier-avatar">{{ initials(c.name) }}</div>
                <div class="tro-carrier-body">
                  <div class="tro-carrier-name">{{ c.name }}</div>
                  <div class="tro-carrier-meta">
                    {{ c.shipments }} shipment{{ c.shipments === 1 ? '' : 's' }} ·
                    {{ fmtHours(c.avg_transit_hours) }} transit
                  </div>
                </div>
                <v-chip
                  v-if="c.on_time_pct != null"
                  size="x-small"
                  variant="tonal"
                  :color="c.on_time_pct >= 90 ? 'green' : c.on_time_pct >= 70 ? 'amber' : 'red'"
                  class="font-weight-bold"
                >{{ c.on_time_pct.toFixed(0) }}%</v-chip>
                <span v-else class="tro-carrier-na">no ETA</span>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="pa-4 pb-2">
            <div class="text-subtitle-1 font-weight-bold">Branch scorecard</div>
            <div class="text-caption text-medium-emphasis">
              Speed, accuracy and reliability per site
            </div>
          </div>
          <v-divider />
          <v-card-text class="pa-0">
            <div v-if="!scorecard.length" class="tro-empty pa-6">
              <v-icon size="30" color="grey-lighten-1">mdi-warehouse</v-icon>
              <div class="mt-2 text-caption text-medium-emphasis">No branch activity yet.</div>
            </div>
            <div v-else class="tro-score-list">
              <div v-for="b in scorecard" :key="b.branch" class="tro-branch-row">
                <div class="tro-branch-grade" :style="{ background: gradeWash(b.grade), color: gradeColor(b.grade) }">
                  {{ b.grade }}
                </div>
                <div class="tro-branch-body">
                  <div class="tro-branch-name">{{ b.branch }}</div>
                  <div class="tro-branch-meta">
                    {{ b.dispatched }} out · {{ b.received }} in ·
                    cycle {{ fmtHours(b.avg_cycle_hours) }}
                  </div>
                  <div class="tro-branch-track">
                    <div
                      class="tro-branch-fill"
                      :style="{ width: b.score + '%', background: gradeColor(b.grade) }"
                    />
                  </div>
                </div>
                <div class="tro-branch-score">{{ b.score }}</div>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <div class="tro-footnote">
      <v-icon size="13">mdi-information-outline</v-icon>
      Optimizations are derived from {{ data?.scope.transfers ?? 0 }} transfers{{ rangeLabel }}.
      Scores weight severity (45%), impact (35%) and ease of implementation (20%).
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

const loading = ref(false)
const exportingPdf = ref(false)
const data = ref(null)
const expanded = reactive(new Set())

const severityFilter = ref(null)
const categoryFilter = ref(null)
const branchFilter = ref(null)
const rangePreset = ref('90d')

const snack = reactive({ show: false, color: 'success', text: '' })
function showSnack(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const rangePresets = [
  { label: '30 days', value: '30d', days: 30 },
  { label: '90 days', value: '90d', days: 90 },
  { label: '6 months', value: '180d', days: 180 },
  { label: '1 year', value: '365d', days: 365 },
  { label: 'All time', value: 'all', days: null },
]

const severityOptions = [
  { title: 'All severities', value: null },
  { title: 'Critical', value: 'critical' },
  { title: 'High', value: 'high' },
  { title: 'Medium', value: 'medium' },
  { title: 'Low', value: 'low' },
]

const categoryChips = [
  { label: 'Speed', value: 'speed', icon: 'mdi-timer-sand' },
  { label: 'Accuracy', value: 'accuracy', icon: 'mdi-shield-check-outline' },
  { label: 'Cost', value: 'cost', icon: 'mdi-cash-multiple' },
  { label: 'Risk', value: 'risk', icon: 'mdi-alert-decagram-outline' },
  { label: 'Balance', value: 'balance', icon: 'mdi-scale-balance' },
  { label: 'Process', value: 'process', icon: 'mdi-clipboard-check-outline' },
]

const dateRange = ref({ from: null, to: null })

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

const branchOptions = computed(() =>
  (branchStore.branches || []).map(b => ({ title: b.name, value: b.id })),
)

// ── Safe accessors ──────────────────────────────────────────────────────
const score = computed(() => data.value?.score || {})
const summary = computed(() => data.value?.summary || {})
const pillars = computed(() => data.value?.score?.pillars || [])
const funnel = computed(() => data.value?.funnel || [])
const lanes = computed(() => data.value?.lanes || [])
const consolidation = computed(() => data.value?.consolidation || [])
const expiryRisk = computed(() => data.value?.expiry_risk || [])
const carriers = computed(() => data.value?.carriers || [])
const scorecard = computed(() => data.value?.scorecard || [])

// ── Formatting ──────────────────────────────────────────────────────────
function formatMoney(v) {
  const n = Number(v || 0)
  return `KES ${n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
function formatQty(v) {
  return Number(v || 0).toLocaleString()
}
function fmtHours(v) {
  if (v == null) return '—'
  const h = Number(v)
  if (h < 1) return `${Math.round(h * 60)}m`
  if (h < 48) return `${h.toFixed(1)}h`
  return `${(h / 24).toFixed(1)}d`
}
function initials(name) {
  return (name || '?').split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase()
}
function pctOf(value, max) {
  const m = Math.max(1, max || 1)
  return Math.min(100, (Number(value || 0) / m) * 100)
}

// ── Score presentation ──────────────────────────────────────────────────
function pillarColor(v) {
  if (v >= 84) return '#16a34a'
  if (v >= 70) return '#0d9488'
  if (v >= 58) return '#f59e0b'
  return '#dc2626'
}
function pillarTarget(p) {
  const t = Number(p.target || 100)
  return Math.max(0, Math.min(100, (t / 100) * 100))
}
const scoreColor = computed(() => pillarColor(Number(score.value.overall ?? 0)))
const scoreWash = computed(() => {
  const c = scoreColor.value
  return `color-mix(in srgb, ${c} 16%, transparent)`
})
const scoreChipColor = computed(() => {
  const v = Number(score.value.overall ?? 0)
  if (v >= 84) return 'green'
  if (v >= 74) return 'teal'
  if (v >= 62) return 'amber'
  return 'red'
})
const gaugeDash = computed(() => {
  const C = 2 * Math.PI * 58
  const pct = Math.max(0, Math.min(100, Number(score.value.overall ?? 0))) / 100
  return `${(C * pct).toFixed(2)} ${C.toFixed(2)}`
})

// ── Severity / impact meta ──────────────────────────────────────────────
const SEVERITY_META = {
  critical: { color: 'red', hex: '#dc2626', icon: 'mdi-alert-octagon' },
  high: { color: 'deep-orange', hex: '#ea580c', icon: 'mdi-alert' },
  medium: { color: 'amber', hex: '#f59e0b', icon: 'mdi-alert-circle-outline' },
  low: { color: 'blue-grey', hex: '#64748b', icon: 'mdi-information-outline' },
}
function severityMeta(s) {
  return SEVERITY_META[s] || SEVERITY_META.low
}
function impactLevel(v) {
  return v === 'high' ? 3 : v === 'medium' ? 2 : 1
}

function laneColor(pct) {
  if (pct >= 70) return 'green'
  if (pct >= 40) return 'amber'
  return 'red'
}
function gradeColor(grade) {
  if (grade === 'A') return '#16a34a'
  if (grade === 'B') return '#0d9488'
  if (grade === 'C') return '#f59e0b'
  return '#dc2626'
}
function gradeWash(grade) {
  return `color-mix(in srgb, ${gradeColor(grade)} 15%, transparent)`
}

// ── Summary tiles ───────────────────────────────────────────────────────
const summaryTiles = computed(() => {
  const s = summary.value
  return [
    {
      title: 'Recommendations',
      value: s.recommendations ?? 0,
      sub: `${s.critical ?? 0} critical · ${s.high ?? 0} high`,
      icon: 'mdi-lightbulb-on-outline',
      color: 'primary',
      hex: brand.primary.value,
    },
    {
      title: 'Quick wins',
      value: s.quick_wins ?? 0,
      sub: 'low effort, measurable',
      icon: 'mdi-rocket-launch-outline',
      color: 'green',
      hex: '#16a34a',
    },
    {
      title: 'Value held',
      value: formatMoney(s.value_at_risk),
      sub: `${formatQty(s.units_at_risk)} units in open transfers`,
      icon: 'mdi-cash-lock',
      color: 'amber',
      hex: '#f59e0b',
    },
    {
      title: 'Potential unlock',
      value: formatMoney(s.potential_value),
      sub: s.potential_hours ? `+ ${fmtHours(s.potential_hours)} recovered` : 'from flagged fixes',
      icon: 'mdi-trending-up',
      color: 'teal',
      hex: '#0d9488',
    },
  ]
})

// ── Read-out lines ──────────────────────────────────────────────────────
const readout = computed(() => {
  const s = data.value?.scope || {}
  const lines = []
  const accent = brand.primary.value

  if (s.transfers) {
    lines.push({
      hex: accent,
      html: `<b>${formatQty(s.transfers)}</b> transfers moved <b>${formatQty(s.units)}</b> units ` +
            `worth <b>${formatMoney(s.value)}</b> across <b>${s.lanes}</b> ` +
            `lane${s.lanes === 1 ? '' : 's'}, with ${s.open} still in the pipeline.`,
    })
  }

  const speed = pillars.value.find(p => p.key === 'speed')
  const acc = pillars.value.find(p => p.key === 'accuracy')
  const disc = pillars.value.find(p => p.key === 'discipline')

  if (speed) {
    lines.push({
      hex: pillarColor(speed.score),
      html: `Average cycle time is <b>${fmtHours(s.avg_cycle_hours)}</b> against a ` +
            `${fmtHours(speed.target)} target — the <b>${speed.label.toLowerCase()}</b> pillar ` +
            `scores <b>${speed.score}</b>.`,
    })
  }
  if (acc) {
    lines.push({
      hex: pillarColor(acc.score),
      html: `Receipt accuracy scores <b>${acc.score}</b> (${acc.note}) — ${
        acc.score >= 98 ? 'the strongest part of the operation.' : 'short receipts are still eroding trust in stock levels.'
      }`,
    })
  }
  if (disc) {
    lines.push({
      hex: pillarColor(disc.score),
      html: `Process discipline scores <b>${disc.score}</b>: carrier assignment, delivery ` +
            `ETAs and signatures are the cheapest points to gain here.`,
    })
  }

  const worst = [...pillars.value].sort((a, b) => a.score - b.score)[0]
  if (worst) {
    lines.push({
      hex: pillarColor(worst.score),
      html: `Biggest single gain: lift <b>${worst.label.toLowerCase()}</b> from ` +
            `<b>${worst.score}</b> toward ${Math.round(worst.target)}.`,
    })
  }

  return lines
})

// ── Funnel visuals ──────────────────────────────────────────────────────
const funnelMax = computed(() =>
  Math.max(1, ...funnel.value.map(s => s.count || 0)),
)
function stageWidth(s) {
  return Math.max(4, pctOf(s.count, funnelMax.value))
}
function stageColor(s) {
  if (s.target_hours && s.avg_hours != null && s.avg_hours > s.target_hours) return '#f59e0b'
  const palette = { draft: '#94a3b8', requested: brand.primary.value, in_transit: '#6366f1', completed: '#16a34a' }
  return palette[s.key] || brand.primary.value
}

const laneMax = computed(() =>
  Math.max(1, ...lanes.value.map(l => Math.max(l.forward, l.reverse))),
)

// ── Filters ─────────────────────────────────────────────────────────────
const filteredRecs = computed(() => {
  let rows = data.value?.recommendations || []
  if (severityFilter.value) rows = rows.filter(r => r.severity === severityFilter.value)
  if (categoryFilter.value) rows = rows.filter(r => r.category === categoryFilter.value)
  return rows
})

function toggle(id) {
  if (expanded.has(id)) expanded.delete(id)
  else expanded.add(id)
}

const rangeLabel = computed(() => {
  const f = data.value?.filters
  if (!f?.date_from) return ' across all time'
  return ` from ${f.date_from} to ${f.date_to || 'today'}`
})

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

function buildParams() {
  const params = {}
  if (dateRange.value.from) params.date_from = dateRange.value.from
  if (dateRange.value.to) params.date_to = dateRange.value.to
  if (branchFilter.value) params.branch = branchFilter.value
  else if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
  return params
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/inventory/transfers/optimization/', { params: buildParams() })
    data.value = res.data
    // Auto-expand the two highest-ranked recommendations so the page opens useful.
    expanded.clear()
    ;(res.data?.recommendations || []).slice(0, 2).forEach(r => expanded.add(r.id))
  } catch {
    data.value = null
    showSnack('Could not load the optimization plan.', 'error')
  } finally {
    loading.value = false
  }
}

async function downloadPdf() {
  exportingPdf.value = true
  try {
    const res = await $api.get('/inventory/transfers/optimization-pdf/', {
      params: buildParams(),
      responseType: 'blob',
      timeout: 60000,
    })
    const blob = new Blob([res.data], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer-optimization_${new Date().toISOString().slice(0, 10)}.pdf`
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 2000)
    showSnack('Optimization plan downloaded', 'success')
  } catch {
    showSnack('Could not generate the PDF plan.', 'error')
  } finally {
    exportingPdf.value = false
  }
}

onMounted(() => applyPreset(rangePreset.value))
</script>

<style scoped>
/* ═══════════════════ HERO ═══════════════════ */
.tro-hero {
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
.tro-hero-glow {
  position: absolute;
  width: 320px;
  height: 320px;
  border-radius: 50%;
  top: -160px;
  right: -90px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.28), transparent 65%);
  pointer-events: none;
}
.tro-hero-glow-2 {
  top: auto;
  bottom: -190px;
  right: auto;
  left: -110px;
  width: 280px;
  height: 280px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.18), transparent 68%);
}
.tro-hero-icon {
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
.tro-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  opacity: 0.86;
}
.tro-title {
  font-size: 25px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  margin: 2px 0 3px;
}
.tro-sub {
  font-size: 12.5px;
  opacity: 0.9;
  max-width: 660px;
}
.tro-hero-iconbtn { color: #fff !important; }
.tro-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #fff !important;
  border: 1px solid rgba(255, 255, 255, 0.26);
}
.tro-hero-btn-glass:hover { background: rgba(255, 255, 255, 0.24) !important; }
.tro-hero-btn-green {
  background: #fff !important;
  color: #0f766e !important;
  font-weight: 700;
  box-shadow: 0 6px 16px -6px rgba(15, 23, 42, 0.45);
}
.tro-hero-facts {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.tro-hero-fact-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}
.tro-fact-suffix {
  font-size: 11px;
  font-weight: 600;
  opacity: 0.7;
  margin-left: 1px;
}
.tro-hero-fact-label {
  font-size: 10.5px;
  letter-spacing: 0.03em;
  opacity: 0.82;
  margin-top: 1px;
}
.tro-hero-divider {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.24);
}

/* ═══════════════════ FILTER BAR ═══════════════════ */
.tro-filterbar { background: rgba(var(--v-theme-on-surface), 0.015); }
.tro-select { max-width: 210px; min-width: 176px; }
.tro-presets :deep(.v-chip) { font-size: 11.5px; font-weight: 600; }

/* ═══════════════════ GAUGE ═══════════════════ */
.tro-gauge {
  position: relative;
  width: 172px;
  height: 172px;
}
.tro-gauge-svg {
  width: 100%;
  height: 100%;
  color: rgba(var(--v-theme-on-surface), 0.08);
}
.tro-gauge-track { stroke: currentColor; }
.tro-gauge-arc { transition: stroke-dasharray 0.6s ease; }
.tro-gauge-center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
}
.tro-gauge-value {
  font-size: 38px;
  font-weight: 800;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.tro-gauge-grade {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  padding: 2px 8px;
  border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), 0.85);
}
.tro-gauge-label {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-top: 2px;
}

/* ═══════════════════ PILLARS ═══════════════════ */
.tro-pillar { margin-bottom: 11px; }
.tro-pillar:last-child { margin-bottom: 0; }
.tro-pillar-head {
  display: flex;
  align-items: baseline;
  gap: 6px;
  margin-bottom: 4px;
}
.tro-pillar-label {
  font-size: 12px;
  font-weight: 600;
  flex: 1;
}
.tro-pillar-weight {
  font-size: 9.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.tro-pillar-score {
  font-size: 12.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  min-width: 26px;
  text-align: right;
}
.tro-pillar-track {
  position: relative;
  height: 7px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: visible;
}
.tro-pillar-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.45s ease;
}
.tro-pillar-target {
  position: absolute;
  top: -2px;
  width: 2px;
  height: 11px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.3);
}
.tro-pillar-note {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 3px;
}

/* ═══════════════════ TILES ═══════════════════ */
.tro-tile {
  position: relative;
  height: 100%;
  padding: 12px 13px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.02);
  overflow: hidden;
}
.tro-tile::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  background: var(--tile-accent, #2f6dff);
}
.tro-tile-icon {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(var(--v-theme-on-surface), 0.05);
  margin-bottom: 7px;
}
.tro-tile-value {
  font-size: 17px;
  font-weight: 800;
  line-height: 1.12;
  font-variant-numeric: tabular-nums;
}
.tro-tile-title {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-top: 2px;
}
.tro-tile-sub {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-top: 1px;
}

/* ═══════════════════ READ-OUT ═══════════════════ */
.tro-readout { display: flex; flex-direction: column; gap: 9px; }
.tro-readout-line {
  display: flex;
  gap: 9px;
  font-size: 12.5px;
  line-height: 1.55;
  color: rgba(var(--v-theme-on-surface), 0.8);
}
.tro-readout-bullet {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-top: 6px;
  flex-shrink: 0;
}

/* ═══════════════════ STAGES ═══════════════════ */
.tro-stage-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
}
.tro-stage-top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
}
.tro-stage-label {
  font-size: 11px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.tro-stage-count {
  font-size: 13px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.tro-stage-track {
  height: 6px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: hidden;
  margin: 5px 0 4px;
}
.tro-stage-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.4s ease;
}
.tro-stage-meta {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tro-stage-target { opacity: 0.75; }

/* ═══════════════════ SECTION HEAD ═══════════════════ */
.tro-section-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
}

/* ═══════════════════ RECOMMENDATIONS ═══════════════════ */
.tro-rec {
  position: relative;
  overflow: hidden;
  padding: 14px 15px 12px;
  transition: box-shadow 0.18s ease, transform 0.18s ease;
}
.tro-rec::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--rec-accent, #64748b);
}
.tro-rec:hover {
  box-shadow: 0 12px 30px -18px rgba(15, 23, 42, 0.45) !important;
  transform: translateY(-1px);
}
.tro-rec-top {
  display: flex;
  align-items: flex-start;
  gap: 11px;
}
.tro-rec-rank {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 11.5px;
  font-weight: 800;
  color: var(--rec-accent, #64748b);
  background: color-mix(in srgb, var(--rec-accent, #64748b) 14%, transparent);
}
.tro-rec-head { flex: 1; min-width: 0; }
.tro-rec-title {
  font-size: 14px;
  font-weight: 800;
  line-height: 1.3;
  letter-spacing: -0.01em;
}
.tro-rec-score {
  text-align: right;
  flex-shrink: 0;
  line-height: 1;
}
.tro-rec-score-value {
  font-size: 20px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: var(--rec-accent, #64748b);
}
.tro-rec-score-label {
  font-size: 8.5px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.tro-rec-summary {
  font-size: 12.5px;
  line-height: 1.55;
  color: rgba(var(--v-theme-on-surface), 0.78);
  margin: 9px 0 10px;
}
.tro-rec-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(78px, 1fr));
  gap: 7px;
  padding: 9px 0;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tro-rec-metric-value {
  font-size: 13.5px;
  font-weight: 800;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tro-rec-metric-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
  margin-top: 1px;
}
.tro-rec-effort {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 9px;
}
.tro-effort-item {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tro-effort-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tro-effort-dots { display: inline-flex; gap: 3px; }
.tro-effort-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgba(var(--v-theme-on-surface), 0.13);
}
.tro-effort-dot.on { background: #0d9488; }
.tro-effort-dot-effort.on { background: #f59e0b; }

.tro-rec-detail {
  margin-top: 12px;
  padding-top: 11px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
}
.tro-rec-detail-text {
  font-size: 12px;
  line-height: 1.6;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.tro-rec-subhead {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin: 12px 0 6px;
}
.tro-rec-actions { display: flex; flex-direction: column; gap: 6px; }
.tro-rec-action {
  display: flex;
  gap: 8px;
  font-size: 12px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
.tro-rec-action-index {
  width: 17px;
  height: 17px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 9.5px;
  font-weight: 800;
  margin-top: 1px;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}
.tro-rec-affected {
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.tro-rec-affected-row {
  display: grid;
  grid-template-columns: 82px 1fr auto;
  gap: 8px;
  align-items: baseline;
  padding: 5px 9px;
  font-size: 11px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-rec-affected-row:last-child { border-bottom: none; }
.tro-rec-affected-ref { font-weight: 800; }
.tro-rec-affected-label {
  color: rgba(var(--v-theme-on-surface), 0.7);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-rec-affected-detail {
  grid-column: 1 / -1;
  color: rgba(var(--v-theme-on-surface), 0.45);
  font-size: 10px;
}
.tro-rec-affected-value {
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  text-align: right;
}
.tro-rec-savings {
  display: flex;
  align-items: center;
  gap: 5px;
  flex-wrap: wrap;
  margin-top: 10px;
  padding: 7px 10px;
  border-radius: 10px;
  font-size: 11.5px;
  background: color-mix(in srgb, #16a34a 10%, transparent);
  color: #0f766e;
}

/* ═══════════════════ LANES ═══════════════════ */
.tro-lanes { padding: 4px 0; }
.tro-lane {
  padding: 10px 15px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-lane:last-child { border-bottom: none; }
.tro-lane-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 7px;
}
.tro-lane-name {
  font-size: 12.5px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-lane-bars { display: flex; flex-direction: column; gap: 5px; }
.tro-lane-bar-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.tro-lane-dir {
  width: 30px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.tro-lane-track {
  flex: 1;
  height: 7px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  overflow: hidden;
}
.tro-lane-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.4s ease;
}
.tro-lane-fill-back { background: #14b8a6; }
.tro-lane-count {
  width: 26px;
  text-align: right;
  font-size: 11.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.tro-lane-meta {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 6px;
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}

/* ═══════════════════ CONSOLIDATION ═══════════════════ */
.tro-consol { padding: 4px 0; }
.tro-consol-row {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 10px 15px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-consol-row:last-child { border-bottom: none; }
.tro-consol-icon {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(var(--v-theme-primary), 0.1);
}
.tro-consol-body { flex: 1; min-width: 0; }
.tro-consol-lane {
  font-size: 12.5px;
  font-weight: 700;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-consol-refs {
  font-size: 10.5px;
  color: rgb(var(--v-theme-primary));
  font-weight: 600;
  margin-top: 1px;
}
.tro-consol-meta {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 1px;
}

/* ═══════════════════ EXPIRY ═══════════════════ */
.tro-expiry { padding: 4px 0; }
.tro-expiry-row {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 9px 15px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-expiry-row:last-child { border-bottom: none; }
.tro-expiry-days {
  width: 34px;
  text-align: center;
  font-size: 15px;
  font-weight: 800;
  line-height: 1;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}
.tro-expiry-days span { font-size: 9px; font-weight: 700; }
.tro-expiry-body { flex: 1; min-width: 0; }
.tro-expiry-name {
  font-size: 12.5px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-expiry-meta {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-top: 1px;
}
.tro-expiry-qty {
  font-size: 12px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

/* ═══════════════════ CARRIERS ═══════════════════ */
.tro-carriers { padding: 4px 0; }
.tro-carrier-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 15px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-carrier-row:last-child { border-bottom: none; }
.tro-carrier-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}
.tro-carrier-body { flex: 1; min-width: 0; }
.tro-carrier-name {
  font-size: 12.5px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-carrier-meta {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tro-carrier-na {
  font-size: 10px;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

/* ═══════════════════ BRANCH SCORECARD ═══════════════════ */
.tro-score-list { padding: 4px 0; }
.tro-branch-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 15px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
}
.tro-branch-row:last-child { border-bottom: none; }
.tro-branch-grade {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 800;
}
.tro-branch-body { flex: 1; min-width: 0; }
.tro-branch-name {
  font-size: 12.5px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tro-branch-meta {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tro-branch-track {
  height: 5px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: hidden;
  margin-top: 4px;
}
.tro-branch-fill {
  height: 100%;
  border-radius: 999px;
}
.tro-branch-score {
  font-size: 12px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

/* ═══════════════════ EMPTY / FOOT ═══════════════════ */
.tro-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 26px 16px;
}
.tro-empty-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 40px 20px;
  border-radius: 18px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
}
.tro-footnote {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 18px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tro-sep { opacity: 0.45; }

@media (max-width: 960px) {
  .tro-hero-divider-lg { display: none; }
  .tro-title { font-size: 21px; }
}
@media (max-width: 700px) {
  .tro-rec-affected-row { grid-template-columns: 1fr auto; }
  .tro-rec-affected-detail { display: none; }
  .tro-stage-grid { grid-template-columns: 1fr 1fr; }
}
</style>
