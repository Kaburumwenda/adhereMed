<template>
  <div class="hc-dose pa-4 pa-md-6">
    <!-- ═══════ HERO BANNER ═══════ -->
    <div class="hc-dose-hero pa-6 pa-md-8 mb-5">
      <div class="hc-dose-hero-bg-pattern" />
      <div class="hc-dose-hero-content">
        <div class="d-flex align-flex-start flex-wrap ga-4">
          <div class="flex-grow-1" style="min-width:240px;">
            <div class="d-flex align-center ga-3 mb-1">
              <v-avatar size="48" class="hc-dose-hero-avatar">
                <v-icon icon="mdi-clipboard-pulse" size="26" />
              </v-avatar>
              <div>
                <div class="text-overline font-weight-bold hc-dose-hero-eyebrow">ADHERENCE · SCHEDULED DOSES</div>
                <h1 class="text-h4 text-md-h3 font-weight-bold ma-0 hc-dose-hero-title">Doses</h1>
              </div>
            </div>
            <p class="text-body-1 mb-4 hc-dose-hero-sub">Scheduled medication doses across all patients. Track adherence in real time.</p>
            <div class="d-flex flex-wrap ga-2">
              <v-chip
                v-for="c in heroChips" :key="c.label"
                size="small" variant="flat"
                class="hc-dose-hero-chip font-weight-medium"
              >
                <v-icon :icon="c.icon" size="14" class="mr-1" />
                {{ c.label }}
              </v-chip>
            </div>
          </div>
          <div class="d-flex flex-column ga-2 align-end" style="min-width:180px;">
            <div class="d-flex ga-2 flex-wrap justify-end">
              <v-btn variant="flat" rounded="pill" class="hc-dose-hero-btn text-none px-4"
                     :loading="loading" @click="load">
                <v-icon start icon="mdi-refresh" size="16" />
                <span class="font-weight-medium">Refresh</span>
              </v-btn>
              <v-btn variant="flat" rounded="pill" class="hc-dose-hero-btn text-none px-4"
                     to="/homecare/doses/analysis">
                <v-icon start icon="mdi-chart-line" size="16" />
                <span class="font-weight-medium">Analysis</span>
              </v-btn>
              <v-btn variant="flat" rounded="pill" class="hc-dose-hero-btn-primary text-none px-4"
                     to="/homecare/medications">
                <v-icon start icon="mdi-pill" size="16" />
                <span class="font-weight-bold">Schedules</span>
              </v-btn>
            </div>
            <div class="hc-dose-hero-clock">
              <v-icon icon="mdi-clock-outline" size="12" class="mr-1" />
              {{ clock }}
            </div>
          </div>
        </div>
      </div>
      <div class="hc-dose-hero-glow hc-dose-hero-glow--1" />
      <div class="hc-dose-hero-glow hc-dose-hero-glow--2" />
    </div>

    <!-- ═══════ KPI STRIP ═══════ -->
    <v-row dense class="mb-4">
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-dose-kpi pa-4 h-100" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3">
            <div class="hc-dose-kpi-icon" :style="{ background: s.grad }">
              <v-icon :icon="s.icon" size="20" />
            </div>
            <div class="flex-grow-1" style="min-width:0;">
              <div class="text-caption font-weight-bold text-uppercase hc-dose-kpi-label">{{ s.label }}</div>
              <div class="d-flex align-baseline ga-1">
                <div class="text-h5 font-weight-bold hc-dose-kpi-value">{{ s.value }}</div>
                <span v-if="s.trend" class="text-caption font-weight-bold" :class="s.trend > 0 ? 'text-success' : 'text-error'">
                  <v-icon :icon="s.trend > 0 ? 'mdi-trending-up' : 'mdi-trending-down'" size="14" />
                  {{ Math.abs(s.trend) }}%
                </span>
              </div>
            </div>
          </div>
          <div class="hc-dose-kpi-spark mt-2">
            <v-progress-linear v-if="s.bar !== undefined" :model-value="s.bar" :color="s.barColor" height="4" rounded />
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════ MAIN CONTENT ═══════ -->
    <v-row dense>
      <!-- ── Doses timeline ── -->
      <v-col cols="12">
        <v-card class="hc-dose-panel pa-5 pa-md-6" rounded="xl" elevation="0">
          <div class="d-flex align-center flex-wrap ga-3 mb-4">
            <div class="d-flex align-center ga-3 flex-grow-1">
              <div class="hc-dose-panel-icon">
                <v-icon icon="mdi-timeline-clock" size="18" />
              </div>
              <div>
                <h3 class="text-subtitle-1 font-weight-bold ma-0">Doses timeline</h3>
                <div class="text-caption hc-dose-panel-subtitle">Grouped by hour · real-time adherence tracking</div>
              </div>
            </div>
          </div>

          <!-- Filters -->
          <div class="hc-dose-filters mb-4">
            <v-row dense align="center">
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="search" prepend-inner-icon="mdi-magnify"
                  placeholder="Search patient or drug…" density="compact"
                  variant="outlined" hide-details rounded="lg"
                  class="hc-dose-field"
                  clearable
                />
              </v-col>
              <v-col cols="6" md="2">
                <v-select
                  v-model="filterStatus" :items="statusOptions"
                  label="Status" density="compact" variant="outlined"
                  hide-details clearable rounded="lg"
                  class="hc-dose-field"
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-select
                  v-model="filterDate" :items="dateRangeOptions"
                  label="Date range" density="compact" variant="outlined"
                  hide-details rounded="lg"
                  prepend-inner-icon="mdi-calendar-range"
                  class="hc-dose-field"
                />
              </v-col>
              <v-col cols="12" md="3" class="d-flex align-center ga-2">
                <v-btn-toggle v-model="viewMode" mandatory color="teal-darken-2"
                              density="compact" variant="outlined" rounded="lg" divided>
                  <v-btn value="timeline" size="small" class="text-none" icon="mdi-timeline" />
                  <v-btn value="compact" size="small" class="text-none" icon="mdi-format-list-bulleted" />
                </v-btn-toggle>
                <v-spacer />
                <span class="text-caption text-medium-emphasis">{{ filtered.length }} dose{{ filtered.length !== 1 ? 's' : '' }}</span>
              </v-col>
              <v-col v-if="filterDate === 'custom'" cols="12" md="6">
                <v-row dense>
                  <v-col cols="6">
                    <v-text-field v-model="customFrom" type="date" label="From"
                                  density="compact" variant="outlined" hide-details rounded="lg" class="hc-dose-field" />
                  </v-col>
                  <v-col cols="6">
                    <v-text-field v-model="customTo" type="date" label="To"
                                  density="compact" variant="outlined" hide-details rounded="lg" class="hc-dose-field" />
                  </v-col>
                </v-row>
              </v-col>
            </v-row>
          </div>

          <!-- Loading -->
          <v-fade-transition mode="out-in">
            <v-progress-linear v-if="loading" indeterminate color="teal" height="4" rounded class="mb-4" />
          </v-fade-transition>

          <!-- Dose list -->
          <div v-if="grouped.length">
            <div v-for="g in grouped" :key="g.key" class="mb-4">
              <!-- Time group label -->
              <div class="hc-dose-timegroup d-flex align-center ga-3 mb-2">
                <div class="hc-dose-timegroup-dot" />
                <div class="hc-dose-timegroup-bar" />
                <v-chip class="hc-dose-timegroup-chip font-weight-bold" variant="tonal" size="small">
                  <v-icon start icon="mdi-clock-outline" size="14" />
                  {{ g.label }}
                </v-chip>
                <v-divider class="flex-grow-1" />
                <span class="text-caption font-weight-medium hc-dose-timegroup-count">{{ g.list.length }} dose{{ g.list.length !== 1 ? 's' : '' }}</span>
              </div>

              <!-- Dose cards -->
              <div v-if="viewMode === 'timeline'" class="hc-dose-cards">
                <v-card
                  v-for="d in g.list" :key="d.id"
                  class="hc-dose-card mb-3" rounded="xl"
                  elevation="0"
                  @mouseenter="hoveredId = d.id"
                  @mouseleave="hoveredId = null"
                >
                  <div class="hc-dose-card-band" :style="{ background: statusColor(d.status).hex }" />
                  <div class="pa-4 pl-5">
                    <div class="d-flex align-center ga-3 flex-wrap">
                      <!-- Status avatar -->
                      <v-avatar size="42" class="hc-dose-card-avatar" :class="'hc-dose-card-avatar--' + d.status">
                        <v-icon :icon="statusIcon(d.status)" size="20" />
                      </v-avatar>

                      <!-- Info -->
                      <div class="flex-grow-1 min-w-0" style="flex:1 1 200px;">
                        <div class="d-flex align-center ga-2 flex-wrap mb-1">
                          <div class="text-subtitle-2 font-weight-bold hc-dose-card-title">
                            {{ d.medication_name || d.schedule_medication || 'Medication' }}
                          </div>
                          <v-chip size="x-small" class="hc-dose-card-status font-weight-bold"
                                  :class="'hc-dose-card-status--' + d.status" variant="flat">
                            <v-icon :icon="statusIcon(d.status)" size="12" start />
                            {{ statusDisplay(d.status) }}
                          </v-chip>
                          <v-chip v-if="d.auto_missed" size="x-small" class="hc-dose-card-auto" variant="tonal">
                            <v-icon icon="mdi-robot" size="12" start />Auto
                          </v-chip>
                          <v-chip v-if="d.dose" size="x-small" variant="text" class="hc-dose-card-dose">
                            <v-icon icon="mdi-pill" size="12" start /> {{ d.dose }} {{ d.dose_unit }}
                          </v-chip>
                        </div>

                        <div class="d-flex flex-wrap ga-x-4 ga-y-1 hc-dose-card-meta">
                          <span class="hc-dose-card-meta-item">
                            <v-icon icon="mdi-account" size="13" />
                            {{ d.patient_name || '—' }}
                          </span>
                          <span class="hc-dose-card-meta-item">
                            <v-icon icon="mdi-calendar" size="13" />
                            Scheduled {{ formatFullDateTime(d.scheduled_at) }}
                          </span>
                          <span v-if="d.administered_at" class="hc-dose-card-meta-item hc-dose-card-meta-item--taken">
                            <v-icon icon="mdi-check" size="13" />
                            Given {{ formatFullDateTime(d.administered_at) }}
                          </span>
                          <span v-if="d.administered_by_name" class="hc-dose-card-meta-item">
                            <v-icon icon="mdi-account-check" size="13" />
                            by <strong>{{ d.administered_by_name }}</strong>
                            <span v-if="d.administered_by_role" class="text-medium-emphasis"> ({{ d.administered_by_role }})</span>
                          </span>
                        </div>

                        <v-expand-transition>
                          <div v-if="d.reason" class="mt-1">
                            <div class="hc-dose-card-reason">
                              <v-icon icon="mdi-message-alert" size="12" />
                              <span>Reason: {{ d.reason }}</span>
                            </div>
                          </div>
                        </v-expand-transition>
                      </div>

                      <!-- Actions -->
                      <div class="d-flex ga-1 flex-wrap justify-end hc-dose-card-actions" style="min-width:160px;">
                        <template v-if="d.status === 'pending' || d.status === 'overdue'">
                          <v-btn size="small" class="hc-dose-action-btn text-none" color="success" variant="flat" rounded="lg"
                                 prepend-icon="mdi-clipboard-check"
                                 @click="openAction(d, 'document')">Document</v-btn>
                          <v-btn size="small" class="hc-dose-action-btn text-none" color="warning" variant="tonal" rounded="lg"
                                 prepend-icon="mdi-skip-next"
                                 @click="openAction(d, 'skip')">Skip</v-btn>
                          <v-btn size="small" class="hc-dose-action-btn text-none" color="error" variant="tonal" rounded="lg"
                                 prepend-icon="mdi-cancel"
                                 @click="openAction(d, 'not_given')">Not given</v-btn>
                          <v-btn size="small" class="hc-dose-action-btn text-none" color="primary" variant="tonal" rounded="lg"
                                 prepend-icon="mdi-pencil-box"
                                 @click="openAction(d, 'edit')">Edit</v-btn>
                        </template>
                        <template v-else>
                          <v-btn size="small" class="hc-dose-action-btn text-none" color="primary" variant="tonal" rounded="lg"
                                 prepend-icon="mdi-pencil-box"
                                 @click="openAction(d, 'edit')">Edit assessment</v-btn>
                        </template>
                        <v-btn size="small" variant="text" rounded="lg" class="hc-dose-action-btn text-none"
                               :icon="expanded[d.id] ? 'mdi-chevron-up' : 'mdi-history'"
                               @click="expanded[d.id] = !expanded[d.id]" />
                      </div>
                    </div>

                    <!-- Audit trail -->
                    <v-expand-transition>
                      <div v-if="expanded[d.id]" class="mt-3">
                        <v-divider class="mb-3" />
                        <div class="text-overline font-weight-bold hc-dose-audit-title mb-2">
                          <v-icon icon="mdi-history" size="12" class="mr-1" />AUDIT TRAIL
                        </div>
                        <div v-if="(d.audit_log || []).length" class="hc-dose-audit-list">
                          <div v-for="(log, i) in d.audit_log" :key="i" class="hc-dose-audit-item">
                            <div class="hc-dose-audit-timeline">
                              <div class="hc-dose-audit-dot" :style="{ background: auditColor(log.action) }" />
                              <div v-if="i < d.audit_log.length - 1" class="hc-dose-audit-line" />
                            </div>
                            <div class="flex-grow-1 pb-3">
                              <div class="d-flex align-center ga-2">
                                <span class="text-body-2 font-weight-medium">{{ log.by_name || 'system' }}</span>
                                <v-chip size="x-small" variant="tonal" class="hc-dose-audit-chip">
                                  {{ log.action }}
                                </v-chip>
                                <span v-if="log.status_to" class="text-caption">
                                  → <span :style="{ color: statusColor(log.status_to).hex }" class="font-weight-medium">{{ statusDisplay(log.status_to) }}</span>
                                </span>
                              </div>
                              <div class="text-caption text-medium-emphasis mt-1 d-flex flex-wrap ga-2">
                                <span>{{ formatFullDateTime(log.at) }}</span>
                                <span v-if="log.dose_to !== undefined">
                                  · dose <strong>{{ log.dose_from || '—' }}</strong> → <strong>{{ log.dose_to }}</strong>
                                </span>
                                <span v-if="log.reason"> · {{ log.reason }}</span>
                              </div>
                            </div>
                          </div>
                        </div>
                        <div v-else class="text-caption text-medium-emphasis pa-2">No history yet.</div>
                      </div>
                    </v-expand-transition>
                  </div>
                </v-card>
              </div>

              <!-- Compact view -->
              <div v-else>
                <div
                  v-for="d in g.list" :key="d.id"
                  class="hc-dose-compact-row"
                  @click="expanded[d.id] = !expanded[d.id]"
                >
                  <div class="hc-dose-compact-band" :style="{ background: statusColor(d.status).hex }" />
                  <div class="d-flex align-center ga-3 pa-3 flex-wrap">
                    <v-avatar size="32" class="hc-dose-card-avatar" :class="'hc-dose-card-avatar--' + d.status">
                      <v-icon :icon="statusIcon(d.status)" size="16" />
                    </v-avatar>
                    <div class="flex-grow-1 min-w-0">
                      <div class="d-flex align-center ga-2">
                        <span class="text-body-2 font-weight-medium text-truncate">{{ d.medication_name || d.schedule_medication }}</span>
                        <v-chip size="x-small" class="font-weight-bold" :class="'hc-dose-card-status--' + d.status" variant="flat">
                          {{ statusDisplay(d.status) }}
                        </v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis">{{ d.patient_name }} · {{ formatFullDateTime(d.scheduled_at) }}</div>
                    </div>
                    <v-btn size="small" variant="text" rounded="lg" :icon="expanded[d.id] ? 'mdi-chevron-up' : 'mdi-chevron-down'" @click.stop />
                  </div>
                  <v-expand-transition>
                    <div v-if="expanded[d.id]" class="pa-3 pt-0">
                      <v-divider class="mb-2" />
                      <div class="text-caption d-flex flex-wrap ga-3">
                        <span v-if="d.dose">Dose: <strong>{{ d.dose }} {{ d.dose_unit }}</strong></span>
                        <span v-if="d.administered_by_name">By: <strong>{{ d.administered_by_name }}</strong></span>
                        <span v-if="d.reason">Reason: {{ d.reason }}</span>
                      </div>
                      <div class="d-flex ga-1 mt-2">
                        <v-btn size="x-small" color="success" variant="flat" rounded="lg" class="text-none"
                               prepend-icon="mdi-clipboard-check"
                               @click.stop="openAction(d, 'document')">Document</v-btn>
                        <v-btn size="x-small" color="primary" variant="tonal" rounded="lg" class="text-none"
                               prepend-icon="mdi-pencil-box"
                               @click.stop="openAction(d, 'edit')">Edit</v-btn>
                      </div>
                    </div>
                  </v-expand-transition>
                </div>
              </div>
            </div>

            <!-- Pagination -->
            <div class="d-flex align-center justify-space-between flex-wrap ga-3 mt-4 pt-3 hc-dose-pagination">
              <span class="text-caption text-medium-emphasis">
                Showing <strong>{{ pagedFrom }}</strong>–<strong>{{ pagedTo }}</strong> of <strong>{{ filtered.length }}</strong>
              </span>
              <v-pagination v-model="page" :length="totalPages" :total-visible="5"
                            density="comfortable" rounded="circle" class="hc-dose-paginator" />
            </div>
          </div>

          <EmptyState v-else :icon="loading ? 'mdi-loading' : 'mdi-clipboard-pulse'" title="No doses found" message="Try a different filter or date range." />
        </v-card>
      </v-col>

      <!-- ═══════ RIGHT SIDEBAR ═══════ -->
      <v-col cols="12" md="6" lg="5">
        <v-row dense>
          <v-col cols="12">
            <v-card class="hc-dose-panel pa-5" rounded="xl" elevation="0">
              <div class="d-flex align-center ga-3 mb-4">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#7c3aed,#6d28d9);">
                  <v-icon icon="mdi-chart-donut" size="18" />
                </div>
                <div>
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Status breakdown</h3>
                  <div class="text-caption hc-dose-panel-subtitle">Distribution by current status</div>
                </div>
              </div>
              <div class="text-center mb-4">
                <DonutRing :segments="segments" :size="200" :thickness="20">
                  <div>
                    <div class="text-h3 font-weight-bold hc-dose-donut-value">{{ stats.adherence }}%</div>
                    <div class="text-caption text-medium-emphasis font-weight-medium">adherence</div>
                  </div>
                </DonutRing>
              </div>
              <v-divider class="mb-3" />
              <v-slide-y-reverse-transition group>
                <div v-for="r in rows" :key="r.label" class="hc-dose-status-row d-flex align-center pa-3 rounded-lg mb-1">
                  <div class="hc-dose-status-dot" :style="{ background: r.color }" />
                  <div class="flex-grow-1">
                    <div class="d-flex align-center">
                      <span class="text-body-2 font-weight-medium">{{ r.label }}</span>
                      <v-spacer />
                      <span class="text-body-2 font-weight-bold">{{ r.count }}</span>
                      <span class="text-caption text-medium-emphasis ml-1" style="min-width:40px;text-align:right;">{{ pctDisplay(r.count, stats.total) }}</span>
                    </div>
                    <v-progress-linear :model-value="pctDisplay(r.count, stats.total)" height="4" rounded
                                       :color="r.color" class="mt-1" />
                  </div>
                </div>
              </v-slide-y-reverse-transition>
            </v-card>
          </v-col>

          <v-col cols="12">
            <v-card class="hc-dose-panel pa-5" rounded="xl" elevation="0">
              <div class="d-flex align-center ga-3 mb-4">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#0284c7,#0369a1);">
                  <v-icon icon="mdi-account-group" size="18" />
                </div>
                <div class="flex-grow-1">
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Adherence by patient</h3>
                  <div class="text-caption hc-dose-panel-subtitle">Bottom performers highlighted</div>
                </div>
              </div>
              <v-list density="compact" class="bg-transparent pa-0">
                <v-list-item v-for="p in sortedPatientAdherence" :key="p.name" rounded="lg" class="mb-2 hc-dose-pat-row">
                  <template #prepend>
                    <v-avatar size="34" :color="adherenceColor(p.pct)" variant="tonal" class="font-weight-bold">
                      <span class="text-caption font-weight-bold">{{ initials(p.name) }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="d-flex align-center font-weight-medium text-body-2">
                    <span class="flex-grow-1 text-truncate">{{ p.name }}</span>
                    <v-chip size="x-small" :color="adherenceColor(p.pct)" variant="flat" class="font-weight-bold text-white">
                      {{ p.pct }}%
                    </v-chip>
                  </v-list-item-title>
                  <template #subtitle>
                    <v-progress-linear :model-value="p.pct" :color="adherenceColor(p.pct)"
                                       height="5" rounded class="mt-1" />
                  </template>
                </v-list-item>
                <EmptyState v-if="!patientAdherence.length" icon="mdi-account-off" title="No data" dense />
              </v-list>
            </v-card>
          </v-col>
        </v-row>
      </v-col>
    </v-row>

    <!-- ═══════ SNACKBAR ═══════ -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="xl">
      <div class="d-flex align-center ga-2">
        <v-icon :icon="snack.icon" size="20" />
        <span class="font-weight-medium">{{ snack.text }}</span>
      </div>
    </v-snackbar>

    <!-- ═══════ ACTION DIALOG ═══════ -->
    <v-dialog v-model="actionDialog" max-width="560" persistent scrollable>
      <v-card v-if="actionTarget" rounded="xl" class="hc-dose-action-dialog" elevation="8">
        <!-- Dialog hero -->
        <div class="hc-dose-action-hero pa-5 d-flex align-center ga-4"
             :style="{ background: `linear-gradient(135deg, ${actionMeta.bg} 0%, ${actionMeta.bg2} 100%)` }">
          <div class="hc-dose-action-hero-icon">
            <v-icon :icon="actionMeta.icon" size="30" />
          </div>
          <div class="text-white flex-grow-1">
            <div class="text-caption font-weight-bold text-uppercase" style="opacity:.75;letter-spacing:1px;">{{ actionMeta.eyebrow }}</div>
            <div class="text-h6 font-weight-bold">{{ actionMeta.title }}</div>
            <div class="text-body-2 mt-1" style="opacity:.9;">
              {{ actionTarget.medication_name }}
              <span v-if="actionTarget.dose"> · {{ actionTarget.dose }}</span>
              <span v-if="actionTarget.patient_name"> · {{ actionTarget.patient_name }}</span>
            </div>
          </div>
        </div>

        <v-card-text class="pa-5">
          <!-- Info alert -->
          <div class="hc-dose-action-info d-flex align-center ga-2 pa-3 rounded-lg mb-4">
            <v-icon icon="mdi-information" size="18" color="teal" />
            <div class="text-caption">
              Scheduled: <strong>{{ formatFullDateTime(actionTarget.scheduled_at) }}</strong>
              <span class="mx-1">·</span>
              Acting as <strong>{{ auth.fullName || auth.user?.email }}</strong>
            </div>
          </div>

          <!-- Edit-only: status switcher -->
          <div v-if="actionType === 'edit'" class="mb-4">
            <div class="text-overline font-weight-bold text-medium-emphasis mb-2">CHANGE STATUS</div>
            <div class="d-flex flex-wrap ga-1">
              <v-chip
                v-for="opt in editStatusOptions" :key="opt.value"
                :color="actionStatus === opt.value ? statusColor(opt.value).vuetify : undefined"
                :variant="actionStatus === opt.value ? 'flat' : 'tonal'"
                size="small" class="text-none"
                @click="actionStatus = opt.value">
                <v-icon start :icon="statusIcon(opt.value)" size="12" />
                {{ opt.title }}
              </v-chip>
            </div>
          </div>

          <!-- Edit-only: dose change -->
          <div v-if="actionType === 'edit'" class="mb-4">
            <div class="text-overline font-weight-bold text-medium-emphasis mb-2">DOSE ADJUSTMENT</div>
            <div class="d-flex flex-wrap ga-1 mb-2">
              <v-chip
                v-for="opt in doseOptions" :key="opt.value"
                :color="actionDose === opt.value ? 'primary' : undefined"
                :variant="actionDose === opt.value ? 'flat' : 'tonal'"
                size="small" class="text-none"
                @click="actionDose = opt.value">
                <v-icon v-if="opt.current" start icon="mdi-star" size="12" />
                {{ opt.label }}
              </v-chip>
            </div>
            <v-text-field v-model="actionDose"
                          label="Custom dose" density="comfortable"
                          variant="outlined" rounded="lg"
                          prepend-inner-icon="mdi-pill"
                          :placeholder="actionTarget.dose || 'e.g. 500 mg'"
                          hide-details class="hc-dose-field" />
          </div>

          <!-- Time of administration -->
          <v-text-field
            v-if="actionType === 'document' || (actionType === 'edit' && actionStatus === 'taken')"
            v-model="actionTime" type="datetime-local"
            label="Time given" density="comfortable" variant="outlined"
            rounded="lg" prepend-inner-icon="mdi-clock-outline"
            hide-details class="mb-4 hc-dose-field" />

          <!-- Reason -->
          <v-textarea
            v-if="needsReason" v-model="actionReason"
            label="Reason" rows="2" auto-grow
            density="comfortable" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-message-alert"
            :rules="[v => !!v?.trim() || 'Reason is required']"
            class="mb-4 hc-dose-field" />

          <!-- Notes -->
          <v-textarea v-model="actionNotes" label="Notes (optional)" rows="2" auto-grow
                      density="comfortable" variant="outlined" rounded="lg"
                      prepend-inner-icon="mdi-note-text" hide-details
                      class="mb-4 hc-dose-field" />

          <!-- PIN verify -->
          <v-divider class="mb-4" />
          <div class="text-overline font-weight-bold text-medium-emphasis mb-2">VERIFY IDENTITY</div>
          <v-text-field v-model="actionPin" label="Your staff PIN"
                        type="password" inputmode="numeric" maxlength="12"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-key"
                        @keyup.enter="submitAction" hide-details class="hc-dose-field" />
          <div class="text-caption text-medium-emphasis mt-1">
            <a href="#" class="hc-dose-pin-link" @click.prevent="showMyPin = !showMyPin">
              <v-icon icon="mdi-help-circle" size="12" class="mr-1" />
              {{ showMyPin ? 'Hide my PIN' : "Don't know your PIN? Reveal mine" }}
            </a>
            <span v-if="showMyPin && auth.user?.pin" class="ml-1 font-weight-medium text-teal-darken-2">
              — <code class="hc-dose-pin-code">{{ auth.user.pin }}</code>
            </span>
          </div>
        </v-card-text>

        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none font-weight-medium hc-dose-action-cancel"
                 :disabled="actionBusy" @click="actionDialog = false">
            Cancel
          </v-btn>
          <v-btn :color="actionMeta.color" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                 :prepend-icon="actionMeta.icon" :loading="actionBusy"
                 @click="submitAction">
            {{ actionMeta.cta }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()

const items = ref([])
const loading = ref(false)
const search = ref('')
const filterStatus = ref(null)
const filterDate = ref('today')
const customFrom = ref('')
const customTo = ref('')
const page = ref(1)
const pageSize = 25
const expanded = reactive({})
const hoveredId = ref(null)
const viewMode = ref('timeline')
const clock = ref('')
const snack = reactive({ show: false, text: '', color: 'info', icon: 'mdi-check-circle' })

// Action dialog state
const actionDialog = ref(false)
const actionTarget = ref(null)
const actionType = ref('document')
const actionStatus = ref('taken')
const actionTime = ref('')
const actionDose = ref('')
const actionReason = ref('')
const actionNotes = ref('')
const actionPin = ref('')
const actionBusy = ref(false)
const showMyPin = ref(false)

let clockTimer = null

const statusOptions = [
  { value: 'pending',   title: 'Pending' },
  { value: 'taken',     title: 'Documented' },
  { value: 'missed',    title: 'Missed' },
  { value: 'skipped',   title: 'Skipped' },
  { value: 'not_given', title: 'Not given' },
  { value: 'overdue',   title: 'Overdue' }
]

const editStatusOptions = [
  { value: 'pending',   title: 'Pending' },
  { value: 'taken',     title: 'Documented' },
  { value: 'missed',    title: 'Missed' },
  { value: 'skipped',   title: 'Skipped' },
  { value: 'not_given', title: 'Not given' }
]

const dateRangeOptions = [
  { value: 'today',     title: 'Today' },
  { value: 'yesterday', title: 'Yesterday' },
  { value: 'last7',     title: 'Last 7 days' },
  { value: 'last30',    title: 'Last 30 days' },
  { value: 'thisMonth', title: 'This month' },
  { value: 'upcoming',  title: 'Upcoming' },
  { value: 'overdue',   title: 'Overdue' },
  { value: 'all',       title: 'All' },
  { value: 'custom',    title: 'Custom range…' }
]

const heroChips = computed(() => [
  { icon: 'mdi-clock-outline',  label: `${stats.value.pending} pending` },
  { icon: 'mdi-check-decagram', label: `${stats.value.taken} taken today` },
  { icon: 'mdi-percent',        label: `${stats.value.adherence}% adherence` }
])

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function endOfDay(d) { const x = new Date(d); x.setHours(23, 59, 59, 999); return x }

function rangeFor(filter) {
  const now = new Date()
  switch (filter) {
    case 'today':     return { from: startOfDay(now), to: endOfDay(now) }
    case 'yesterday': {
      const y = new Date(now); y.setDate(y.getDate() - 1)
      return { from: startOfDay(y), to: endOfDay(y) }
    }
    case 'last7': {
      const f = new Date(now); f.setDate(f.getDate() - 6)
      return { from: startOfDay(f), to: endOfDay(now) }
    }
    case 'last30': {
      const f = new Date(now); f.setDate(f.getDate() - 29)
      return { from: startOfDay(f), to: endOfDay(now) }
    }
    case 'thisMonth': {
      const f = new Date(now.getFullYear(), now.getMonth(), 1)
      const t = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999)
      return { from: f, to: t }
    }
    case 'upcoming': return { from: now, to: null }
    case 'overdue':  return { from: null, to: now }
    case 'custom': {
      return {
        from: customFrom.value ? startOfDay(customFrom.value) : null,
        to: customTo.value ? endOfDay(customTo.value) : null
      }
    }
    default: return { from: null, to: null }
  }
}

function tickClock() {
  clock.value = new Date().toLocaleString([], {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

async function load() {
  loading.value = true
  try {
    try { await $api.post('/homecare/doses/auto_expire/') } catch { /* non-fatal */ }
    const params = { page_size: 1000 }
    if (filterDate.value === 'today') {
      const { data } = await $api.get('/homecare/doses/today/', { params })
      items.value = data?.results || data || []
    } else {
      const r = rangeFor(filterDate.value)
      if (r.from) params.from = r.from.toISOString()
      if (r.to)   params.to   = r.to.toISOString()
      const { data } = await $api.get('/homecare/doses/', { params })
      items.value = data?.results || data || []
    }
  } catch {
    snack.text = 'Failed to load doses'; snack.color = 'error'; snack.show = true; snack.icon = 'mdi-alert-circle'
  } finally { loading.value = false }
}

onMounted(() => { tickClock(); clockTimer = setInterval(tickClock, 30000); load() })
onBeforeUnmount(() => { if (clockTimer) clearInterval(clockTimer) })
watch(filterDate, () => { page.value = 1; load() })
watch([customFrom, customTo], () => { if (filterDate.value === 'custom') { page.value = 1; load() } })
watch([search, filterStatus], () => { page.value = 1 })

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  const r = rangeFor(filterDate.value)
  return items.value.filter(d => {
    if (filterStatus.value && d.status !== filterStatus.value) return false
    const ts = new Date(d.scheduled_at).getTime()
    if (r.from && ts < r.from.getTime()) return false
    if (r.to && ts > r.to.getTime()) return false
    if (filterDate.value === 'overdue' && d.status !== 'pending') return false
    if (!q) return true
    return [d.medication_name, d.schedule_medication, d.patient_name]
      .filter(Boolean).some(s => s.toLowerCase().includes(q))
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize)))
const paged = computed(() => {
  const start = (page.value - 1) * pageSize
  return filtered.value.slice(start, start + pageSize)
})
const pagedFrom = computed(() => filtered.value.length ? (page.value - 1) * pageSize + 1 : 0)
const pagedTo = computed(() => Math.min(page.value * pageSize, filtered.value.length))

const grouped = computed(() => {
  const map = new Map()
  for (const d of paged.value) {
    const dt = new Date(d.scheduled_at)
    const key = `${dt.toDateString()}-${dt.getHours()}`
    const label = dt.toLocaleString(undefined, {
      weekday: 'short', day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit'
    })
    if (!map.has(key)) map.set(key, { key, label, list: [], ts: dt.getTime() })
    map.get(key).list.push(d)
  }
  return Array.from(map.values()).sort((a, b) => a.ts - b.ts)
})

const stats = computed(() => {
  const list = items.value
  const taken = list.filter(d => d.status === 'taken').length
  const missed = list.filter(d => d.status === 'missed').length
  const pending = list.filter(d => d.status === 'pending').length
  const skipped = list.filter(d => d.status === 'skipped').length
  const notGiven = list.filter(d => d.status === 'not_given').length
  const total = list.length
  const finalized = taken + missed
  const adherence = finalized ? Math.round((taken / finalized) * 100) : 0
  return { total, taken, missed, pending, skipped, notGiven, adherence }
})

const summary = computed(() => [
  {
    label: 'Total doses', value: stats.value.total,
    icon: 'mdi-clipboard-pulse', grad: 'linear-gradient(135deg,#0d9488,#0f766e)',
    barColor: 'teal', bar: 100
  },
  {
    label: 'Pending', value: stats.value.pending,
    icon: 'mdi-clock-outline', grad: 'linear-gradient(135deg,#f59e0b,#d97706)',
    barColor: 'warning', bar: stats.value.total ? Math.round((stats.value.pending / stats.value.total) * 100) : 0,
    trend: stats.value.total ? Math.round(((stats.value.pending - (stats.value.taken + stats.value.missed)) / stats.value.total) * 100) : 0
  },
  {
    label: 'Taken today', value: stats.value.taken,
    icon: 'mdi-check-decagram', grad: 'linear-gradient(135deg,#10b981,#059669)',
    barColor: 'success', bar: stats.value.total ? Math.round((stats.value.taken / stats.value.total) * 100) : 0
  },
  {
    label: 'Missed', value: stats.value.missed,
    icon: 'mdi-close-circle', grad: 'linear-gradient(135deg,#ef4444,#dc2626)',
    barColor: 'error', bar: stats.value.total ? Math.round((stats.value.missed / stats.value.total) * 100) : 0,
    trend: -Math.round(stats.value.missed / (stats.value.taken + stats.value.missed || 1) * 100)
  }
])

const rows = computed(() => statusOptions.map(o => ({
  label: o.title,
  count: items.value.filter(d => d.status === o.value).length,
  color: statusColor(o.value).hex,
  bg: `${statusColor(o.value).hex}14`,
  icon: statusIcon(o.value)
})))

const segments = computed(() => statusOptions.map(o => ({
  label: o.title,
  value: items.value.filter(d => d.status === o.value).length,
  color: statusColor(o.value).vuetify
})))

const patientAdherence = computed(() => {
  const map = {}
  for (const d of items.value) {
    const k = d.patient_name || '—'
    if (!map[k]) map[k] = { taken: 0, total: 0 }
    if (d.status === 'taken' || d.status === 'missed') {
      map[k].total += 1
      if (d.status === 'taken') map[k].taken += 1
    }
  }
  return Object.entries(map).map(([name, v]) => ({
    name, pct: v.total ? Math.round((v.taken / v.total) * 100) : 0
  })).sort((a, b) => a.pct - b.pct)
})

const sortedPatientAdherence = computed(() => [...patientAdherence.value].slice(0, 6))

function statusColor(s) {
  return ({
    pending:   { hex: '#f59e0b', vuetify: 'warning' },
    taken:     { hex: '#10b981', vuetify: 'success' },
    missed:    { hex: '#ef4444', vuetify: 'error' },
    skipped:   { hex: '#94a3b8', vuetify: 'grey' },
    not_given: { hex: '#dc2626', vuetify: 'error' },
    overdue:   { hex: '#dc2626', vuetify: 'error' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}

function statusIcon(s) {
  return ({ pending: 'mdi-clock', taken: 'mdi-clipboard-check',
            missed: 'mdi-alert', skipped: 'mdi-skip-next',
            not_given: 'mdi-cancel', overdue: 'mdi-alert' })[s] || 'mdi-circle'
}

function statusDisplay(s) {
  return ({ pending: 'Pending', taken: 'Documented', missed: 'Missed',
            skipped: 'Skipped', not_given: 'Not given',
            overdue: 'Overdue' })[s] || s
}

function auditColor(action) {
  return ({ document: '#10b981', skip: '#f59e0b', not_given: '#ef4444',
            mark_missed: '#ef4444', auto_missed: '#f59e0b',
            edit_assessment: '#0d9488' })[action] || '#94a3b8'
}

function auditIcon(action) {
  return ({ document: 'mdi-clipboard-check', skip: 'mdi-skip-next',
            not_given: 'mdi-cancel', mark_missed: 'mdi-alert',
            auto_missed: 'mdi-robot', edit_assessment: 'mdi-pencil-box'
          })[action] || 'mdi-circle-small'
}

function adherenceColor(p) {
  if (p >= 85) return 'success'
  if (p >= 60) return 'warning'
  return 'error'
}

function formatFullDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

function pctDisplay(n, d) { return d ? Math.round((n / d) * 100) : 0 }

function initials(name) {
  if (!name) return '?'
  return name.trim().split(/\s+/).map(p => p[0]).join('').slice(0, 2).toUpperCase()
}

// ─── Action dialog ───────────────────────────────────────
const actionMeta = computed(() => {
  const map = {
    document:  { eyebrow: 'DOCUMENT DOSE', title: 'Document administration',
                 cta: 'Save & document', icon: 'mdi-clipboard-check',
                 color: 'success', bg: '#10b981', bg2: '#059669' },
    skip:      { eyebrow: 'SKIP DOSE', title: 'Skip this dose',
                 cta: 'Confirm skip', icon: 'mdi-skip-next',
                 color: 'warning', bg: '#f59e0b', bg2: '#d97706' },
    not_given: { eyebrow: 'NOT GIVEN', title: 'Mark as not given',
                 cta: 'Confirm not given', icon: 'mdi-cancel',
                 color: 'error', bg: '#ef4444', bg2: '#dc2626' },
    edit:      { eyebrow: 'EDIT ASSESSMENT', title: 'Edit dose assessment',
                 cta: 'Save changes', icon: 'mdi-pencil-box',
                 color: 'primary', bg: '#0d9488', bg2: '#7c3aed' }
  }
  return map[actionType.value] || map.document
})

const needsReason = computed(() => {
  if (actionType.value === 'skip' || actionType.value === 'not_given') return true
  if (actionType.value === 'edit') return true
  return false
})

const doseOptions = computed(() => {
  const cur = (actionTarget.value?.dose || '').trim()
  if (!cur) return []
  const m = cur.match(/^([0-9]*\.?[0-9]+)\s*(.*)$/)
  if (!m) return [{ value: cur, label: cur, current: true }]
  const n = parseFloat(m[1])
  const unit = (m[2] || '').trim()
  const fmt = (v) => {
    const s = Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/\.?0+$/, '')
    return unit ? `${s} ${unit}` : s
  }
  const seen = new Set()
  const out = []
  for (const [mult, suffix] of [[0.5, 'half'], [1, 'current'], [1.5, '1.5×'], [2, 'double']]) {
    const v = +(n * mult).toFixed(4)
    if (v <= 0) continue
    const label = fmt(v)
    if (seen.has(label)) continue
    seen.add(label)
    out.push({ value: label, label: `${label}${suffix === 'current' ? '' : ' · ' + suffix}`, current: mult === 1 })
  }
  return out
})

function toLocalInput(d) {
  if (!d) return ''
  const dt = new Date(d)
  const tz = dt.getTimezoneOffset() * 60000
  return new Date(dt.getTime() - tz).toISOString().slice(0, 16)
}

function openAction(dose, type) {
  actionTarget.value = dose
  actionType.value = type
  actionStatus.value = type === 'edit'
    ? (dose.status === 'missed' ? 'taken' : dose.status)
    : 'taken'
  actionTime.value = toLocalInput(dose.administered_at || new Date())
  actionDose.value = dose.dose || ''
  actionReason.value = type === 'edit' ? (dose.reason || '') : ''
  actionNotes.value = ''
  actionPin.value = ''
  showMyPin.value = false
  actionDialog.value = true
}

async function submitAction() {
  if (!actionTarget.value) return
  const pin = actionPin.value.trim()
  if (!pin) {
    snack.text = 'Please enter your staff PIN'; snack.color = 'warning'; snack.show = true; snack.icon = 'mdi-alert'
    return
  }
  if (auth.user?.pin && pin !== auth.user.pin) {
    snack.text = 'PIN does not match the logged-in user'
    snack.color = 'error'; snack.show = true; snack.icon = 'mdi-alert-circle'
    return
  }
  if (needsReason.value && !actionReason.value.trim()) {
    snack.text = 'A reason is required'; snack.color = 'warning'; snack.show = true; snack.icon = 'mdi-alert'
    return
  }
  actionBusy.value = true
  const payload = { pin }
  if (actionNotes.value) payload.notes = actionNotes.value
  if (actionReason.value) payload.reason = actionReason.value
  let url = ''
  if (actionType.value === 'document') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_taken/`
    if (actionTime.value) payload.administered_at = new Date(actionTime.value).toISOString()
  } else if (actionType.value === 'skip') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_skipped/`
  } else if (actionType.value === 'not_given') {
    url = `/homecare/doses/${actionTarget.value.id}/mark_not_given/`
  } else if (actionType.value === 'edit') {
    url = `/homecare/doses/${actionTarget.value.id}/edit_assessment/`
    payload.status = actionStatus.value
    if (actionDose.value && actionDose.value !== actionTarget.value.dose) {
      payload.dose = actionDose.value
    }
    if (actionStatus.value === 'taken' && actionTime.value) {
      payload.administered_at = new Date(actionTime.value).toISOString()
    }
  }
  try {
    const { data } = await $api.post(url, payload)
    const i = items.value.findIndex(x => x.id === data.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = `${actionMeta.value.title} – saved`; snack.color = 'success'; snack.show = true; snack.icon = 'mdi-check-circle'
    actionDialog.value = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Action failed'
    snack.color = 'error'; snack.show = true; snack.icon = 'mdi-alert-circle'
  } finally {
    actionBusy.value = false
  }
}
</script>

<style scoped>
/* ═══════════════════════════════════════════════════════
   GLOBAL
   ═══════════════════════════════════════════════════════ */
.hc-dose { min-height: calc(100vh - 64px); }

/* ═══════════════════════════════════════════════════════
   HERO BANNER
   ═══════════════════════════════════════════════════════ */
.hc-dose-hero {
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background:
    radial-gradient(ellipse at 0% 40%, rgba(13,148,136,0.20) 0%, transparent 55%),
    radial-gradient(ellipse at 100% 0%, rgba(124,58,237,0.10) 0%, transparent 50%),
    linear-gradient(165deg, #0c3d3a 0%, #0d9488 35%, #0ea5a4 55%, #0284c7 85%, #1e3a5f 100%);
  box-shadow: 0 20px 60px -16px rgba(13,148,136,0.50), inset 0 0 0 1px rgba(255,255,255,0.08);
}
.hc-dose-hero-bg-pattern {
  position: absolute; inset: 0;
  background-image: radial-gradient(rgba(255,255,255,0.06) 1px, transparent 1px);
  background-size: 24px 24px;
  pointer-events: none;
}
.hc-dose-hero-content { position: relative; z-index: 2; }
.hc-dose-hero-avatar {
  background: rgba(255,255,255,0.18) !important;
  backdrop-filter: blur(12px);
  border: 1.5px solid rgba(255,255,255,0.25);
}
.hc-dose-hero-avatar .v-icon { color: white !important; }
.hc-dose-hero-eyebrow {
  color: rgba(255,255,255,0.75) !important;
  letter-spacing: 1.5px;
  font-size: 11px;
}
.hc-dose-hero-title { color: white; letter-spacing: -0.5px; }
.hc-dose-hero-sub { color: rgba(255,255,255,0.78) !important; max-width: 540px; }
.hc-dose-hero-chip {
  background: rgba(255,255,255,0.14) !important;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.15);
  color: white !important;
  font-weight: 500;
}
.hc-dose-hero-btn {
  background: rgba(255,255,255,0.14) !important;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.18);
  color: white !important;
  font-weight: 500;
  transition: background 0.2s ease;
}
.hc-dose-hero-btn:hover { background: rgba(255,255,255,0.22) !important; }
.hc-dose-hero-btn-primary {
  background: white !important;
  border: none;
  color: #0d9488 !important;
  font-weight: 600;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.hc-dose-hero-btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 24px -6px rgba(0,0,0,0.20);
}
.hc-dose-hero-clock {
  display: inline-flex; align-items: center;
  padding: 5px 14px; border-radius: 999px;
  background: rgba(0,0,0,0.20);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.12);
  color: rgba(255,255,255,0.85);
  font-size: 12px;
}
.hc-dose-hero-glow {
  position: absolute; border-radius: 50%; pointer-events: none;
}
.hc-dose-hero-glow--1 {
  right: -100px; top: -100px;
  width: 400px; height: 400px;
  background: radial-gradient(circle, rgba(255,255,255,0.08) 0%, transparent 65%);
}
.hc-dose-hero-glow--2 {
  left: 40%; bottom: -120px;
  width: 300px; height: 300px;
  background: radial-gradient(circle, rgba(13,148,136,0.12) 0%, transparent 65%);
}

/* ═══════════════════════════════════════════════════════
   KPI CARDS
   ═══════════════════════════════════════════════════════ */
.hc-dose-kpi {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  overflow: hidden;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.hc-dose-kpi:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 28px -8px rgba(13,148,136,0.12);
}
.hc-dose-kpi-icon {
  width: 44px; height: 44px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  color: white;
  flex-shrink: 0;
}
.hc-dose-kpi-label {
  color: rgba(15,23,42,0.45);
  letter-spacing: 0.8px;
  font-size: 11px;
  margin-bottom: 2px;
}
.hc-dose-kpi-value { color: #0f172a; }
.hc-dose-kpi-spark { opacity: 0.6; }

/* ═══════════════════════════════════════════════════════
   PANEL
   ═══════════════════════════════════════════════════════ */
.hc-dose-panel {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  height: 100%;
}
.hc-dose-panel-icon {
  width: 36px; height: 36px;
  border-radius: 10px;
  background: linear-gradient(135deg, #0d9488, #0f766e);
  display: flex; align-items: center; justify-content: center;
  color: white;
  flex-shrink: 0;
}
.hc-dose-panel-subtitle { color: rgba(15,23,42,0.45); }

/* ═══════════════════════════════════════════════════════
   FILTERS
   ═══════════════════════════════════════════════════════ */
.hc-dose-filters {
  padding: 12px;
  background: rgba(13,148,136,0.03);
  border-radius: 16px;
  border: 1px solid rgba(13,148,136,0.06);
}
.hc-dose-field :deep(.v-field__outline) {
  --v-field-border-opacity: 0.2;
}
.hc-dose-field:hover :deep(.v-field__outline) {
  --v-field-border-opacity: 0.4;
}
.hc-dose-field :deep(.v-field--focused .v-field__outline) {
  --v-field-border-opacity: 0.6;
}

/* ═══════════════════════════════════════════════════════
   TIME GROUP HEADER
   ═══════════════════════════════════════════════════════ */
.hc-dose-timegroup { position: relative; }
.hc-dose-timegroup-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  background: #0d9488;
  border: 2px solid rgba(13,148,136,0.25);
  flex-shrink: 0;
}
.hc-dose-timegroup-bar {
  position: absolute;
  left: 4px; top: 16px; bottom: -16px;
  width: 2px;
  background: linear-gradient(to bottom, rgba(13,148,136,0.15), transparent);
  pointer-events: none;
}
.hc-dose-timegroup-chip {
  background: rgba(13,148,136,0.08) !important;
  border: 1px solid rgba(13,148,136,0.12);
  color: #0d9488 !important;
  letter-spacing: 0.02em;
}
.hc-dose-timegroup-count { color: rgba(15,23,42,0.4); }

/* ═══════════════════════════════════════════════════════
   DOSE CARDS (Timeline view)
   ═══════════════════════════════════════════════════════ */
.hc-dose-cards { padding-left: 22px; }
.hc-dose-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  overflow: hidden;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.hc-dose-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 28px -8px rgba(13,148,136,0.08);
}
.hc-dose-card-band {
  position: absolute; left: 0; top: 0; bottom: 0; width: 4px;
}
.hc-dose-card-avatar { border: 1px solid rgba(15,23,42,0.06); }
.hc-dose-card-avatar--pending { background: rgba(245,158,11,0.10) !important; color: #f59e0b !important; }
.hc-dose-card-avatar--taken { background: rgba(16,185,129,0.10) !important; color: #10b981 !important; }
.hc-dose-card-avatar--missed { background: rgba(239,68,68,0.10) !important; color: #ef4444 !important; }
.hc-dose-card-avatar--skipped { background: rgba(148,163,184,0.10) !important; color: #94a3b8 !important; }
.hc-dose-card-avatar--not_given { background: rgba(220,38,38,0.10) !important; color: #dc2626 !important; }
.hc-dose-card-avatar--overdue { background: rgba(220,38,38,0.10) !important; color: #dc2626 !important; }
.hc-dose-card-title { color: #0f172a; }
.hc-dose-card-status { font-size: 10px; }
.hc-dose-card-status--pending { background: #f59e0b !important; color: white !important; }
.hc-dose-card-status--taken { background: #10b981 !important; color: white !important; }
.hc-dose-card-status--missed { background: #ef4444 !important; color: white !important; }
.hc-dose-card-status--skipped { background: #94a3b8 !important; color: white !important; }
.hc-dose-card-status--not_given { background: #dc2626 !important; color: white !important; }
.hc-dose-card-status--overdue { background: #dc2626 !important; color: white !important; }
.hc-dose-card-auto { background: rgba(245,158,11,0.08) !important; color: #d97706 !important; }
.hc-dose-card-dose { color: rgba(15,23,42,0.55) !important; }
.hc-dose-card-meta {
  gap: 4px 16px;
  margin-top: 2px;
}
.hc-dose-card-meta-item {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 12px; color: rgba(15,23,42,0.55);
  white-space: nowrap;
}
.hc-dose-card-meta-item .v-icon { font-size: 13px; }
.hc-dose-card-meta-item--taken .v-icon { color: #10b981; }
.hc-dose-card-reason {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 12px;
  background: rgba(239,68,68,0.06);
  border-left: 3px solid rgba(239,68,68,0.5);
  padding: 5px 10px;
  border-radius: 8px;
  color: rgba(239,68,68,0.85);
}
.hc-dose-action-btn {
  font-size: 11px;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.hc-dose-action-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px -4px rgba(0,0,0,0.12);
}

/* ═══════════════════════════════════════════════════════
   COMPACT VIEW ROWS
   ═══════════════════════════════════════════════════════ */
.hc-dose-compact-row {
  position: relative;
  display: flex; flex-direction: column;
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  border-radius: 12px;
  margin-bottom: 4px;
  cursor: pointer; overflow: hidden;
  transition: background 0.15s ease;
}
.hc-dose-compact-row:hover { background: rgba(13,148,136,0.04); }
.hc-dose-compact-band { position: absolute; left: 0; top: 0; bottom: 0; width: 3px; }

/* ═══════════════════════════════════════════════════════
   AUDIT TRAIL
   ═══════════════════════════════════════════════════════ */
.hc-dose-audit-title { color: rgba(15,23,42,0.35); letter-spacing: 1px; font-size: 10px; }
.hc-dose-audit-item { display: flex; gap: 12px; }
.hc-dose-audit-timeline { display: flex; flex-direction: column; align-items: center; width: 12px; flex-shrink: 0; }
.hc-dose-audit-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: 4px; }
.hc-dose-audit-line { width: 2px; flex: 1; background: rgba(15,23,42,0.06); }
.hc-dose-audit-chip { font-size: 9px !important; height: 18px !important; }

/* ═══════════════════════════════════════════════════════
   PAGINATION
   ═══════════════════════════════════════════════════════ */
.hc-dose-pagination { border-top: 1px solid rgba(15,23,42,0.06); }
.hc-dose-paginator :deep(.v-pagination__item--is-active .v-btn) {
  background: #0d9488 !important;
  color: white !important;
}

/* ═══════════════════════════════════════════════════════
   SIDEBAR — STATUS ROWS
   ═══════════════════════════════════════════════════════ */
.hc-dose-donut-value { color: #0f172a; }
.hc-dose-status-row {
  background: rgba(15,23,42,0.02);
  transition: background 0.15s ease;
  cursor: default;
}
.hc-dose-status-row:hover { background: rgba(13,148,136,0.04); }
.hc-dose-status-dot { width: 10px; height: 10px; border-radius: 50%; margin-right: 12px; flex-shrink: 0; }

/* ═══════════════════════════════════════════════════════
   SIDEBAR — PATIENT ADHERENCE
   ═══════════════════════════════════════════════════════ */
.hc-dose-pat-row {
  border-bottom: 1px dashed rgba(15,23,42,0.06);
  transition: background 0.15s ease;
}
.hc-dose-pat-row:hover { background: rgba(13,148,136,0.04); border-radius: 12px; }
.hc-dose-pat-row:last-child { border-bottom: none; }

/* ═══════════════════════════════════════════════════════
   ACTION DIALOG
   ═══════════════════════════════════════════════════════ */
.hc-dose-action-dialog { overflow: hidden; }
.hc-dose-action-hero { position: relative; overflow: hidden; }
.hc-dose-action-hero::after {
  content: ''; position: absolute; right: -40px; top: -40px;
  width: 160px; height: 160px; border-radius: 50%;
  background: rgba(255,255,255,0.06);
  pointer-events: none;
}
.hc-dose-action-hero-icon {
  width: 56px; height: 56px; border-radius: 16px;
  background: rgba(255,255,255,0.20);
  backdrop-filter: blur(8px);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.hc-dose-action-hero-icon .v-icon { color: white !important; }
.hc-dose-action-info {
  background: rgba(13,148,136,0.06);
  border: 1px solid rgba(13,148,136,0.10);
}
.hc-dose-action-cancel { color: rgba(15,23,42,0.55) !important; }
.hc-dose-pin-link {
  color: rgba(13,148,136,0.8);
  text-decoration: none;
  font-weight: 500;
}
.hc-dose-pin-link:hover { color: #0d9488; text-decoration: underline; }
.hc-dose-pin-code {
  background: rgba(13,148,136,0.08);
  padding: 1px 6px;
  border-radius: 4px;
  font-size: 13px;
}

/* ═══════════════════════════════════════════════════════
   DARK MODE OVERRIDES
   ═══════════════════════════════════════════════════════ */
:global(.v-theme--dark .hc-dose) { background: transparent; }
:global(.v-theme--dark .hc-dose-kpi) {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark .hc-dose-kpi-value) { color: rgba(255,255,255,0.92); }
:global(.v-theme--dark .hc-dose-kpi-label) { color: rgba(255,255,255,0.45); }
:global(.v-theme--dark .hc-dose-panel) {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark .hc-dose-panel-subtitle) { color: rgba(255,255,255,0.45); }
:global(.v-theme--dark .hc-dose-card),
:global(.v-theme--dark .hc-dose-compact-row) {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.06);
}
:global(.v-theme--dark .hc-dose-card-title),
:global(.v-theme--dark .hc-dose-donut-value) { color: rgba(255,255,255,0.92); }
:global(.v-theme--dark .hc-dose-card-meta-item) { color: rgba(255,255,255,0.55); }
:global(.v-theme--dark .hc-dose-card-dose) { color: rgba(255,255,255,0.45) !important; }
:global(.v-theme--dark .hc-dose-filters) { background: rgba(255,255,255,0.03); border-color: rgba(255,255,255,0.06); }
:global(.v-theme--dark .hc-dose-timegroup-chip) { background: rgba(13,148,136,0.15) !important; border-color: rgba(13,148,136,0.20); color: #5eead4 !important; }
:global(.v-theme--dark .hc-dose-timegroup-count) { color: rgba(255,255,255,0.35); }
:global(.v-theme--dark .hc-dose-status-row) { background: rgba(255,255,255,0.02); }
:global(.v-theme--dark .hc-dose-status-row:hover),
:global(.v-theme--dark .hc-dose-pat-row:hover) { background: rgba(13,148,136,0.10); }
:global(.v-theme--dark .hc-dose-pat-row) { border-color: rgba(255,255,255,0.06); }
:global(.v-theme--dark .hc-dose-audit-title) { color: rgba(255,255,255,0.35); }
:global(.v-theme--dark .hc-dose-audit-line) { background: rgba(255,255,255,0.08); }
:global(.v-theme--dark .hc-dose-pagination) { border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .hc-dose-action-cancel) { color: rgba(255,255,255,0.55) !important; }
:global(.v-theme--dark .hc-dose-action-info) { background: rgba(13,148,136,0.10); border-color: rgba(13,148,136,0.15); }
:global(.v-theme--dark .hc-dose-card-avatar) { border-color: rgba(255,255,255,0.08); }
</style>
