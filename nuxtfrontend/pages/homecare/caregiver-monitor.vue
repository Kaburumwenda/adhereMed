<template>
  <div class="cm-bg pa-4 pa-md-6">
    <HomecareHero
      title="Caregiver Monitor"
      subtitle="Real-time command centre for caregiver schedules, check-ins and field locations."
      eyebrow="ADMIN & MANAGEMENT · MONITOR"
      icon="mdi-monitor-eye"
      :chips="[
        { icon: 'mdi-calendar-clock', label: `${kpis.total} schedules` },
        { icon: 'mdi-progress-clock', label: `${kpis.inProgress} in progress` },
        { icon: 'mdi-check-decagram', label: `${kpis.completed} completed` },
        { icon: 'mdi-map-marker-radius', label: `${kpis.checkedInOnMap} on map` },
        { icon: 'mdi-alert-octagon', label: `${kpis.missed} missed` }
      ]"
    >
      <template #actions>
        <v-chip v-if="liveConnected" size="small" color="success" variant="flat" class="font-weight-bold">
          <v-icon icon="mdi-circle-medium" start size="12" class="cm-live-dot" />
          LIVE
        </v-chip>
        <v-btn variant="tonal" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="loadAll">
          <span class="font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Filter bar -->
    <v-card rounded="xl" elevation="0" class="cm-card pa-3 mt-1">
      <div class="d-flex flex-wrap align-center ga-2">
        <AnalyticsDateFilter v-model="range" v-model:from="customFrom" v-model:to="customTo"
                             @change="onRangeChange" />
        <v-select v-model="statusFilter" :items="statusOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Status" style="max-width:170px;" />
        <v-select v-model="caregiverFilter" :items="caregiverOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Caregiver" style="max-width:220px;" />
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                      placeholder="Search caregiver, patient…"
                      density="comfortable" variant="outlined" hide-details rounded="lg"
                      style="max-width:280px;" clearable />
        <v-spacer />
        <v-btn-toggle v-model="density" mandatory color="teal" variant="outlined"
                      rounded="lg" density="comfortable">
          <v-btn value="compact" size="small" class="text-none"><v-icon icon="mdi-view-headline" /></v-btn>
          <v-btn value="comfortable" size="small" class="text-none"><v-icon icon="mdi-format-line-spacing" /></v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- KPI strip -->
    <v-row dense class="mt-3">
      <v-col cols="6" md="2"><HomecareKpiCard label="Schedules" :value="kpis.total" icon="mdi-calendar-clock" color="#6366f1" /></v-col>
      <v-col cols="6" md="2"><HomecareKpiCard label="In Progress" :value="kpis.inProgress" icon="mdi-progress-clock" color="#0ea5e9" :hint="`${kpis.activeCaregivers} active caregivers`" /></v-col>
      <v-col cols="6" md="2"><HomecareKpiCard label="Completed" :value="kpis.completed" icon="mdi-check-decagram" color="#10b981" :hint="`${kpis.completionRate}% rate`" /></v-col>
      <v-col cols="6" md="2"><HomecareKpiCard label="Missed" :value="kpis.missed" icon="mdi-alert-octagon" color="#f59e0b" :hint="`${kpis.missedRate}% rate`" /></v-col>
      <v-col cols="6" md="2"><HomecareKpiCard label="On Map" :value="kpis.checkedInOnMap" icon="mdi-map-marker-radius" color="#8b5cf6" hint="checked-in locations" /></v-col>
      <v-col cols="6" md="2"><HomecareKpiCard label="Avg Visit" :value="kpis.avgDuration" suffix="h" icon="mdi-timer-sand" color="#ec4899" hint="completed duration" /></v-col>
    </v-row>

    <!-- Main grid -->
    <v-row class="mt-3">
      <!-- Schedule list -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Caregiver schedules" subtitle="All assignments with live status"
                       icon="mdi-format-list-checks" color="#6366f1">
          <template #actions>
            <v-chip size="small" variant="tonal" color="indigo">{{ filteredSchedules.length }}</v-chip>
          </template>
          <v-data-table v-if="filteredSchedules.length" :items="filteredSchedules"
                        :headers="tableHeaders" item-value="id" :loading="loading"
                        :density="density" class="cm-table" :items-per-page="12">
            <template #[`item.caregiver_name`]="{ item }">
              <div class="d-flex align-center ga-2">
                <v-avatar size="30" :color="catColor(item.caregiver_category)" variant="flat">
                  <span class="text-caption font-weight-bold text-white">{{ initials(item.caregiver_name) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.caregiver_name || '—' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.patient_name || '—' }}</div>
                </div>
              </div>
            </template>
            <template #[`item.when`]="{ item }">
              <div class="font-weight-medium">{{ formatDateTime(item.start_at) }}</div>
              <div class="text-caption text-medium-emphasis">→ {{ formatTime(item.end_at) }} · {{ shiftLabel(item.shift_type) }}</div>
            </template>
            <template #[`item.status`]="{ item }">
              <v-chip size="small" :color="STATUS_META[item.status]?.color" variant="tonal">
                <v-icon :icon="STATUS_META[item.status]?.icon" start size="14" />
                {{ STATUS_META[item.status]?.label }}
              </v-chip>
            </template>
            <template #[`item.check_in`]="{ item }">
              <div v-if="item.check_in_at" class="d-flex align-center ga-1">
                <v-icon icon="mdi-map-marker-check" :color="item.gps_check_in?.lat ? 'teal' : 'grey'" size="16" />
                <span class="text-caption">{{ formatTime(item.check_in_at) }}</span>
              </div>
              <span v-else class="text-caption text-medium-emphasis">—</span>
            </template>
            <template #[`item.actions`]="{ item }">
              <v-btn icon="mdi-eye" size="small" variant="text" @click="openDetail(item)" />
              <v-btn v-if="item.gps_check_in?.lat" icon="mdi-map-marker" size="small" variant="text"
                     color="teal" @click="focusMarker(item)" />
            </template>
          </v-data-table>
          <EmptyState v-else icon="mdi-calendar-remove" title="No schedules found"
                      message="Adjust the date range or filters." />
        </HomecarePanel>
      </v-col>

      <!-- Right column: individual analysis + check-ins -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Individual analysis" subtitle="Pick a caregiver to drill down"
                       icon="mdi-account-search" color="#0ea5e9">
          <v-autocomplete v-model="selectedCaregiver" :items="caregiverOptions"
                          prepend-inner-icon="mdi-account-heart" placeholder="Select caregiver"
                          density="comfortable" variant="outlined" rounded="lg" hide-details clearable
                          class="mb-3" />
          <div v-if="selectedCaregiver && caregiverStats">
            <div class="d-flex align-center ga-3 mb-3">
              <v-avatar size="48" :color="catColor(caregiverStats.category)" variant="flat">
                <span class="text-h6 font-weight-bold text-white">{{ initials(caregiverStats.name) }}</span>
              </v-avatar>
              <div>
                <div class="text-subtitle-1 font-weight-bold">{{ caregiverStats.name }}</div>
                <v-chip size="x-small" :color="catColor(caregiverStats.category)" variant="tonal">
                  {{ catLabel(caregiverStats.category) }}
                </v-chip>
              </div>
            </div>
            <v-row dense>
              <v-col cols="6"><div class="cm-stat"><div class="cm-stat-v text-indigo">{{ caregiverStats.total }}</div><div class="cm-stat-l">Schedules</div></div></v-col>
              <v-col cols="6"><div class="cm-stat"><div class="cm-stat-v text-success">{{ caregiverStats.completed }}</div><div class="cm-stat-l">Completed</div></div></v-col>
              <v-col cols="6"><div class="cm-stat"><div class="cm-stat-v text-teal">{{ caregiverStats.inProgress }}</div><div class="cm-stat-l">In progress</div></div></v-col>
              <v-col cols="6"><div class="cm-stat"><div class="cm-stat-v text-warning">{{ caregiverStats.missed }}</div><div class="cm-stat-l">Missed</div></div></v-col>
            </v-row>
            <div class="mt-3">
              <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
                <span>Completion rate</span><span class="font-weight-bold">{{ caregiverStats.completionRate }}%</span>
              </div>
              <v-progress-linear :model-value="caregiverStats.completionRate" color="success" rounded height="8" />
            </div>
            <div class="mt-2">
              <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-1">
                <span>Avg visit duration</span><span class="font-weight-bold">{{ caregiverStats.avgDuration }}h</span>
              </div>
              <v-progress-linear :model-value="Math.min(100, caregiverStats.avgDuration / 8 * 100)" color="pink" rounded height="8" />
            </div>
            <div class="d-flex flex-wrap ga-2 mt-3">
              <v-chip size="small" variant="tonal" color="purple"><v-icon icon="mdi-map-marker" start size="14" />{{ caregiverStats.checkIns }} check-ins</v-chip>
              <v-chip size="small" variant="tonal" color="info"><v-icon icon="mdi-timer" start size="14" />{{ caregiverStats.onTime }} on time</v-chip>
            </div>
            <template v-if="caregiverDoseStats">
              <v-divider class="my-3" />
              <div class="d-flex align-center ga-3 mb-2">
                <v-progress-circular :model-value="caregiverDoseStats.adherenceRate" :color="adherenceColor(caregiverDoseStats.adherenceRate)" size="56" width="6">
                  <span class="text-caption font-weight-bold">{{ caregiverDoseStats.adherenceRate }}%</span>
                </v-progress-circular>
                <div class="flex-grow-1">
                  <div class="text-caption text-medium-emphasis font-weight-medium">DOSE ADHERENCE</div>
                  <div class="text-body-2 font-weight-medium">{{ caregiverDoseStats.taken }} taken · {{ caregiverDoseStats.missed }} missed</div>
                  <div class="text-caption text-medium-emphasis">{{ caregiverDoseStats.total }} doses · {{ caregiverDoseStats.patients }} patients · {{ caregiverDoseStats.onTimeRate }}% on-time</div>
                </div>
              </div>
              <v-progress-linear :model-value="caregiverDoseStats.adherenceRate" :color="adherenceColor(caregiverDoseStats.adherenceRate)" rounded height="6" />
            </template>
            <v-btn block variant="tonal" color="indigo" rounded="lg" class="text-none mt-3"
                   prepend-icon="mdi-account-details" :to="`/homecare/caregivers/${selectedCaregiver}`">
              View full profile
            </v-btn>
          </div>
          <EmptyState v-else icon="mdi-account-search-outline" title="Select a caregiver" dense />
        </HomecarePanel>

        <!-- Check-in & location list -->
        <HomecarePanel class="mt-4" title="Check-ins & locations" subtitle="Live field check-ins with GPS"
                       icon="mdi-map-marker-check" color="#10b981">
          <template #actions>
            <v-chip size="small" variant="tonal" color="success">{{ checkInList.length }}</v-chip>
          </template>
          <div v-if="checkInList.length" class="d-flex flex-column ga-2 cm-checkin-list">
            <div v-for="c in checkInList" :key="c.id" class="cm-checkin-row"
                 :class="{ 'cm-checkin-active': c.status === 'checked_in' }"
                 @click="focusMarker(c)">
              <v-avatar size="38" :color="catColor(c.caregiver_category)" variant="flat" class="flex-shrink-0">
                <span class="text-caption font-weight-bold text-white">{{ initials(c.caregiver_name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-w-0 ml-2">
                <div class="text-body-2 font-weight-bold text-truncate">{{ c.caregiver_name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ c.patient_name }}</div>
                <div class="d-flex align-center ga-2 mt-1">
                  <v-chip size="x-small" :color="STATUS_META[c.status]?.color" variant="tonal">
                    <v-icon :icon="STATUS_META[c.status]?.icon" start size="10" />{{ STATUS_META[c.status]?.label }}
                  </v-chip>
                  <span class="text-caption text-medium-emphasis">
                    <v-icon icon="mdi-clock" size="11" />{{ formatTime(c.check_in_at) }}
                  </span>
                </div>
              </div>
              <div class="text-right flex-shrink-0">
                <v-icon icon="mdi-map-marker" color="teal" size="18" />
                <div class="text-caption text-medium-emphasis">{{ gpsShort(c.gps_check_in) }}</div>
              </div>
            </div>
          </div>
          <EmptyState v-else icon="mdi-map-marker-off" title="No check-ins yet"
                      message="Checked-in caregivers will appear here." dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Analysis row -->
    <v-row class="mt-3" align="start">
      <v-col cols="12" md="6" lg="3">
        <HomecarePanel title="Status breakdown" icon="mdi-chart-donut" color="#6366f1">
          <div class="d-flex justify-center mb-3">
            <DonutRing :segments="statusSegments" :size="160" :thickness="18">
              <div class="text-center">
                <div class="text-h5 font-weight-bold">{{ kpis.total }}</div>
                <div class="text-caption text-medium-emphasis">visits</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="s in statusSegments" :key="s.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ s.label }}</span>
              <span class="font-weight-bold text-body-2">{{ s.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6" lg="3">
        <HomecarePanel title="Shift mix" subtitle="By assignment type" icon="mdi-briefcase-clock" color="#0ea5e9">
          <div class="d-flex flex-column ga-2 mt-2">
            <div v-for="s in shiftBars" :key="s.label" class="d-flex align-center">
              <v-icon :icon="s.icon" :color="s.color" size="20" class="mr-3" />
              <span class="text-body-2 flex-grow-1">{{ s.label }}</span>
              <span class="font-weight-bold mr-2">{{ s.value }}</span>
              <v-progress-linear :model-value="s.pct" :color="s.color" rounded style="max-width:90px;" height="6" />
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">Completion performance</div>
          <div class="d-flex align-center ga-2 mt-1">
            <v-progress-circular :model-value="kpis.completionRate" color="success" size="56" width="6">
              <span class="text-caption font-weight-bold">{{ kpis.completionRate }}%</span>
            </v-progress-circular>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-medium">{{ kpis.completed }} completed</div>
              <div class="text-caption text-medium-emphasis">of {{ kpis.completed + kpis.missed + kpis.cancelled }} resolved</div>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6" lg="3">
        <HomecarePanel title="Punctuality" subtitle="On-time vs late check-ins" icon="mdi-timer-check" color="#10b981">
          <div class="d-flex justify-center my-2">
            <DonutRing :segments="punctualitySegments" :size="150" :thickness="16">
              <div class="text-center">
                <div class="text-h6 font-weight-bold text-success">{{ punctualityPct }}%</div>
                <div class="text-caption text-medium-emphasis">on time</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-column ga-1">
            <div v-for="p in punctualitySegments" :key="p.label" class="d-flex align-center pa-1 rounded-lg">
              <v-icon icon="mdi-circle" :color="p.color" size="9" class="mr-2" />
              <span class="flex-grow-1 text-body-2">{{ p.label }}</span>
              <span class="font-weight-bold text-body-2">{{ p.value }}</span>
            </div>
          </div>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="6" lg="3">
        <HomecarePanel title="Busiest caregivers" subtitle="Most assignments in range" icon="mdi-trophy" color="#f59e0b">
          <div v-if="topCaregivers.length" class="d-flex flex-column ga-2">
            <div v-for="(c, idx) in topCaregivers" :key="c.id" class="d-flex align-center pa-2 rounded-lg cm-row"
                 @click="selectedCaregiver = c.id">
              <v-avatar size="34" :color="leaderColor(idx)" variant="tonal" class="cursor-pointer">
                <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
              </v-avatar>
              <div class="flex-grow-1 ml-3 min-w-0">
                <div class="text-body-2 font-weight-bold text-truncate">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ c.total }} visits · {{ c.completed }} done</div>
              </div>
              <v-progress-linear :model-value="c.pct" color="amber" rounded style="max-width:70px;" height="6" />
              <span class="text-subtitle-2 font-weight-bold ml-3">{{ c.total }}</span>
            </div>
          </div>
          <EmptyState v-else icon="mdi-trophy-outline" title="No data" dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Assignments per caregiver bar chart -->
    <v-row class="mt-3" align="start">
      <v-col cols="12" md="6">
        <HomecarePanel title="Assignments per caregiver" subtitle="Workload distribution in selected range"
                       icon="mdi-chart-bar" color="#8b5cf6">
          <BarChart v-if="assignBars.values.length" :values="assignBars.values" :labels="assignBars.labels"
                    :colors="assignBars.colors" :height="240" :show-values="true" :rotate-labels="true" />
          <EmptyState v-else icon="mdi-chart-bar-offline" title="No assignments" dense />
        </HomecarePanel>
      </v-col>
      <v-col cols="12" md="6">
        <HomecarePanel title="Status trend" subtitle="Schedules grouped by day" icon="mdi-chart-areaspline" color="#ec4899">
          <BarChart v-if="trendBars.values.length" :values="trendBars.values" :labels="trendBars.labels"
                    :colors="trendBars.colors" :height="240" :show-values="true" />
          <EmptyState v-else icon="mdi-chart-bell-curve" title="No trend data" dense />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Dose adherence performance -->
    <v-row class="mt-3" align="start">
      <v-col cols="12" lg="8">
        <HomecarePanel title="Caregiver dose adherence" subtitle="How well each caregiver ensures patients take prescribed doses"
                       icon="mdi-pill-multiple" color="#10b981">
          <template #actions>
            <v-chip size="small" variant="tonal" color="success">{{ caregiverDoseRanking.length }} caregivers</v-chip>
          </template>
          <div v-if="caregiverDoseRanking.length" class="d-flex flex-column ga-2 cm-dose-list">
            <div v-for="(c, idx) in caregiverDoseRanking" :key="c.id" class="cm-dose-row"
                 :class="{ 'cm-dose-selected': c.id === selectedCaregiver }"
                 @click="selectedCaregiver = c.id">
              <div class="d-flex align-center mb-1">
                <v-avatar size="34" :color="catColor(c.category)" variant="flat" class="flex-shrink-0">
                  <span class="text-caption font-weight-bold text-white">{{ initials(c.name) }}</span>
                </v-avatar>
                <div class="flex-grow-1 ml-2 min-w-0">
                  <div class="text-body-2 font-weight-bold text-truncate">{{ c.name || 'Caregiver' }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    {{ c.taken }} taken · {{ c.missed }} missed · {{ c.skipped + c.refused + c.notGiven }} other · {{ c.patients }} patients
                  </div>
                </div>
                <div class="text-right flex-shrink-0 ml-2">
                  <div class="text-h6 font-weight-bold" :class="'text-' + adherenceColor(c.adherenceRate)">{{ c.adherenceRate }}%</div>
                  <div class="text-caption text-medium-emphasis">adherence</div>
                </div>
              </div>
              <v-progress-linear :model-value="c.adherenceRate" :color="adherenceColor(c.adherenceRate)" rounded height="7" />
              <div class="d-flex justify-space-between mt-1">
                <span class="text-caption text-medium-emphasis">
                  <v-icon icon="mdi-timer-check" size="11" />on-time docs {{ c.onTimeRate }}% · {{ c.total }} doses
                </span>
                <span v-if="c.autoMissed" class="text-caption text-warning font-weight-medium">
                  <v-icon icon="mdi-alert-octagon" size="11" />{{ c.autoMissed }} auto-missed
                </span>
                <span v-else class="text-caption font-weight-bold" :class="'text-' + adherenceColor(c.adherenceRate)">
                  {{ c.finalized }} finalized
                </span>
              </div>
            </div>
          </div>
          <EmptyState v-else icon="mdi-pill-off" title="No dose data"
                      message="Documented doses will appear here for the selected range." dense />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="Adherence overview" subtitle="All doses in selected range"
                       icon="mdi-clipboard-pulse" color="#ef4444">
          <div class="d-flex align-center ga-3 mb-3">
            <v-progress-circular :model-value="doseKpis.adherenceRate" :color="adherenceColor(doseKpis.adherenceRate)" size="84" width="8">
              <div class="text-center">
                <div class="text-h6 font-weight-bold">{{ doseKpis.adherenceRate }}%</div>
                <div class="text-caption text-medium-emphasis">adherence</div>
              </div>
            </v-progress-circular>
            <div class="flex-grow-1">
              <div class="d-flex flex-column ga-1">
                <div class="d-flex align-center">
                  <v-icon icon="mdi-pill" size="16" color="indigo" class="mr-2" />
                  <span class="text-body-2 flex-grow-1">Total doses</span>
                  <span class="font-weight-bold">{{ doseKpis.total }}</span>
                </div>
                <div class="d-flex align-center">
                  <v-icon icon="mdi-check-circle" size="16" color="success" class="mr-2" />
                  <span class="text-body-2 flex-grow-1">Documented</span>
                  <span class="font-weight-bold text-success">{{ doseKpis.taken }}</span>
                </div>
                <div class="d-flex align-center">
                  <v-icon icon="mdi-alert" size="16" color="error" class="mr-2" />
                  <span class="text-body-2 flex-grow-1">Missed</span>
                  <span class="font-weight-bold text-error">{{ doseKpis.missed }}</span>
                </div>
                <div class="d-flex align-center">
                  <v-icon icon="mdi-account-heart" size="16" color="teal" class="mr-2" />
                  <span class="text-body-2 flex-grow-1">By caregiver</span>
                  <span class="font-weight-bold text-teal">{{ doseKpis.administered }}</span>
                </div>
              </div>
            </div>
          </div>
          <v-divider class="mb-3" />
          <div class="d-flex justify-center">
            <DonutRing :segments="doseStatusSegments" :size="150" :thickness="16">
              <div class="text-center">
                <div class="text-h6 font-weight-bold">{{ doseKpis.finalized }}</div>
                <div class="text-caption text-medium-emphasis">finalized</div>
              </div>
            </DonutRing>
          </div>
          <div class="d-flex flex-wrap ga-1 mt-3 justify-center">
            <v-chip v-for="s in doseStatusSegments" :key="s.label" size="x-small" variant="tonal">
              <v-icon icon="mdi-circle" :color="s.color" start size="8" />{{ s.label }} · {{ s.value }}
            </v-chip>
          </div>
          <div v-if="doseKpis.autoMissed" class="mt-3">
            <v-alert density="compact" variant="tonal" color="warning" rounded="lg" class="text-body-2">
              <v-icon icon="mdi-alert-octagon" start size="16" />{{ doseKpis.autoMissed }} doses auto-marked missed (overdue)
            </v-alert>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Live map -->
    <v-row class="mt-3">
      <v-col cols="12">
        <HomecarePanel title="Live check-in map" subtitle="Real-time location of all checked-in caregivers"
                       icon="mdi-map-marker-radius" color="#0d9488">
          <template #actions>
            <v-chip size="small" variant="flat" color="teal" class="font-weight-bold">
              <v-icon icon="mdi-map-marker-multiple" start size="14" />{{ mapMarkers.length }}
            </v-chip>
          </template>
          <CaregiverMonitorMap :markers="mapMarkers" :height="500" />
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="600">
      <v-card v-if="selected" rounded="xl" class="pa-0">
        <div class="pa-4 d-flex align-center ga-2"
             :style="{ background: STATUS_META[selected.status]?.gradient, color:'white' }">
          <v-icon :icon="STATUS_META[selected.status]?.icon" />
          <div>
            <div class="text-overline" style="opacity:0.85;">{{ STATUS_META[selected.status]?.label }} · {{ shiftLabel(selected.shift_type) }}</div>
            <div class="text-h6 font-weight-bold">{{ formatDateTime(selected.start_at) }} – {{ formatTime(selected.end_at) }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" color="white" @click="detailDialog = false" />
        </div>
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Caregiver</div>
              <div class="font-weight-medium">{{ selected.caregiver_name || '—' }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div class="font-weight-medium">{{ selected.patient_name || '—' }}</div>
            </v-col>
            <v-col v-if="selected.check_in_at" cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Checked in</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.check_in_at) }}</div>
              <div v-if="selected.gps_check_in?.lat" class="text-caption text-medium-emphasis">
                <v-icon icon="mdi-map-marker" size="12" />
                {{ selected.gps_check_in.lat.toFixed(4) }}, {{ selected.gps_check_in.lng.toFixed(4) }}
                <v-chip size="x-small" variant="tonal" color="teal" class="ml-1">±{{ Math.round(selected.gps_check_in.accuracy || 0) }}m</v-chip>
              </div>
            </v-col>
            <v-col v-if="selected.check_out_at" cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Checked out</div>
              <div class="font-weight-medium">{{ formatDateTime(selected.check_out_at) }}</div>
              <div v-if="selected.check_in_at" class="text-caption text-medium-emphasis">
                Duration: {{ duration(selected.check_in_at, selected.check_out_at) }}
              </div>
            </v-col>
            <v-col v-if="selected.notes" cols="12">
              <div class="text-caption text-medium-emphasis">Notes</div>
              <div class="text-body-2" style="white-space: pre-wrap;">{{ selected.notes }}</div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn v-if="selected.gps_check_in?.lat" color="teal" variant="tonal" rounded="lg" class="text-none"
                 prepend-icon="mdi-map-marker" @click="focusMarker(selected); detailDialog = false">
            Show on map
          </v-btn>
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const schedules = ref([])
const doses = ref([])
const caregivers = ref([])
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

const range = ref('7d')
const customFrom = ref('')
const customTo = ref('')
const statusFilter = ref(null)
const caregiverFilter = ref(null)
const search = ref('')
const density = ref('comfortable')
const selectedCaregiver = ref(null)
const detailDialog = ref(false)
const selected = ref(null)

const STATUS_META = {
  scheduled:  { label: 'Scheduled',  icon: 'mdi-calendar-clock',  color: 'blue',
                gradient: 'linear-gradient(135deg,#1d4ed8 0%,#3b82f6 100%)', hex: '#3b82f6' },
  checked_in: { label: 'In progress', icon: 'mdi-progress-clock', color: 'teal',
                gradient: 'linear-gradient(135deg,#0f766e 0%,#14b8a6 100%)', hex: '#14b8a6' },
  completed:  { label: 'Completed',  icon: 'mdi-check-decagram',  color: 'success',
                gradient: 'linear-gradient(135deg,#15803d 0%,#22c55e 100%)', hex: '#22c55e' },
  missed:     { label: 'Missed',     icon: 'mdi-alert-octagon',   color: 'warning',
                gradient: 'linear-gradient(135deg,#b45309 0%,#f59e0b 100%)', hex: '#f59e0b' },
  cancelled:  { label: 'Cancelled',  icon: 'mdi-cancel',          color: 'grey',
                gradient: 'linear-gradient(135deg,#475569 0%,#94a3b8 100%)', hex: '#94a3b8' },
}

const statusOptions = Object.entries(STATUS_META).map(([k, v]) => ({ title: v.label, value: k }))
const shiftTypeOptions = [
  { title: 'Single Visit', value: 'visit' },
  { title: 'Live-in',      value: 'live_in' },
  { title: 'On Call',      value: 'on_call' },
]
function shiftLabel(v) { return shiftTypeOptions.find(o => o.value === v)?.title || v || 'Visit' }

const tableHeaders = [
  { title: 'Caregiver / Patient', key: 'caregiver_name', sortable: false },
  { title: 'When', key: 'when', sortable: false },
  { title: 'Status', key: 'status' },
  { title: 'Check-in', key: 'check_in', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const CAT = {
  nurse: { label: 'Nurse', color: 'indigo', hex: '#6366f1' },
  hca:   { label: 'HCA',   color: 'pink',   hex: '#ec4899' },
}
function catColor(c) { return CAT[c]?.color || 'teal' }
function catLabel(c) { return CAT[c]?.label || 'Caregiver' }
function catHex(c) { return CAT[c]?.hex || '#0d9488' }

const DOSE_STATUS_META = {
  pending:   { label: 'Pending',    icon: 'mdi-clock-outline',  color: 'warning', hex: '#f59e0b' },
  taken:     { label: 'Documented', icon: 'mdi-check-circle',   color: 'success', hex: '#10b981' },
  missed:    { label: 'Missed',     icon: 'mdi-alert',           color: 'error',   hex: '#ef4444' },
  skipped:   { label: 'Skipped',    icon: 'mdi-skip-next',       color: 'grey',    hex: '#94a3b8' },
  refused:   { label: 'Refused',    icon: 'mdi-do-not-disturb', color: 'grey',    hex: '#64748b' },
  not_given: { label: 'Not given', icon: 'mdi-pill-off',        color: 'error',   hex: '#dc2626' },
}
function doseStatusMeta(s) { return DOSE_STATUS_META[s] || { label: s, icon: 'mdi-pill', color: 'grey', hex: '#64748b' } }
function adherenceColor(rate) {
  if (rate >= 90) return 'success'
  if (rate >= 75) return 'warning'
  if (rate >= 50) return 'orange'
  return 'error'
}

const caregiverOptions = computed(() =>
  caregivers.value.map(c => ({ title: c.user?.full_name || c.user?.email || 'Caregiver', value: c.id }))
)

function caregiverMeta(id) {
  return caregivers.value.find(c => c.id === id)
}

function computeWindow() {
  const now = new Date()
  const r = range.value
  let start, end
  if (r === 'custom' && customFrom.value && customTo.value) {
    start = new Date(customFrom.value + 'T00:00:00')
    end = new Date(customTo.value + 'T23:59:59')
  } else if (r === 'today') {
    start = new Date(now); start.setHours(0, 0, 0, 0); end = new Date(now)
  } else if (r === 'yesterday') {
    start = new Date(now); start.setDate(start.getDate() - 1); start.setHours(0, 0, 0, 0)
    end = new Date(start); end.setHours(23, 59, 59, 999)
  } else if (r === '7d') {
    start = new Date(now); start.setDate(start.getDate() - 6); start.setHours(0, 0, 0, 0); end = new Date(now)
  } else if (r === '30d') {
    start = new Date(now); start.setDate(start.getDate() - 29); start.setHours(0, 0, 0, 0); end = new Date(now)
  } else if (r === '90d') {
    start = new Date(now); start.setDate(start.getDate() - 89); start.setHours(0, 0, 0, 0); end = new Date(now)
  } else if (r === '1y') {
    start = new Date(now); start.setFullYear(start.getFullYear() - 1); start.setHours(0, 0, 0, 0); end = new Date(now)
  } else {
    start = new Date(now); start.setFullYear(start.getFullYear() - 5); start.setHours(0, 0, 0, 0); end = new Date(now)
  }
  return { start, end }
}

const filteredSchedules = computed(() => {
  const q = search.value?.trim().toLowerCase()
  return schedules.value.filter(s => {
    if (statusFilter.value && s.status !== statusFilter.value) return false
    if (caregiverFilter.value && s.caregiver !== caregiverFilter.value) return false
    if (q) {
      const blob = [s.caregiver_name, s.patient_name, s.notes].filter(Boolean).join(' ').toLowerCase()
      if (!blob.includes(q)) return false
    }
    return true
  })
})

const kpis = computed(() => {
  const list = filteredSchedules.value
  const total = list.length
  const inProgress = list.filter(s => s.status === 'checked_in').length
  const completed = list.filter(s => s.status === 'completed').length
  const missed = list.filter(s => s.status === 'missed').length
  const cancelled = list.filter(s => s.status === 'cancelled').length
  const checkedInOnMap = list.filter(s => s.gps_check_in?.lat != null).length
  const resolved = completed + missed + cancelled
  const completionRate = resolved ? Math.round(completed / resolved * 100) : 0
  const missedRate = resolved ? Math.round(missed / resolved * 100) : 0
  const activeCaregivers = new Set(list.filter(s => s.status === 'checked_in').map(s => s.caregiver)).size
  let durSum = 0, durCnt = 0
  for (const s of list) {
    if (s.status === 'completed' && s.check_in_at && s.check_out_at) {
      const ms = new Date(s.check_out_at) - new Date(s.check_in_at)
      if (ms > 0 && ms < 1000 * 60 * 60 * 24) { durSum += ms; durCnt++ }
    }
  }
  const avgDuration = durCnt ? (durSum / durCnt / 3600000).toFixed(1) : 0
  return { total, inProgress, completed, missed, cancelled, checkedInOnMap, completionRate, missedRate, activeCaregivers, avgDuration }
})

const statusSegments = computed(() => {
  const list = filteredSchedules.value
  return [
    { label: 'Scheduled',  value: list.filter(s => s.status === 'scheduled').length,  color: '#3b82f6' },
    { label: 'In progress', value: list.filter(s => s.status === 'checked_in').length, color: '#14b8a6' },
    { label: 'Completed',  value: list.filter(s => s.status === 'completed').length,  color: '#22c55e' },
    { label: 'Missed',     value: list.filter(s => s.status === 'missed').length,     color: '#f59e0b' },
    { label: 'Cancelled',  value: list.filter(s => s.status === 'cancelled').length,  color: '#94a3b8' },
  ].filter(s => s.value > 0)
})

const shiftBars = computed(() => {
  const list = filteredSchedules.value
  const counts = { visit: 0, live_in: 0, on_call: 0 }
  for (const s of list) counts[s.shift_type] = (counts[s.shift_type] || 0) + 1
  const total = list.length || 1
  const items = [
    { label: 'Single Visit', key: 'visit', icon: 'mdi-account-arrow-right', color: 'teal' },
    { label: 'Live-in', key: 'live_in', icon: 'mdi-home-clock', color: 'indigo' },
    { label: 'On Call', key: 'on_call', icon: 'mdi-phone-in-talk', color: 'pink' },
  ]
  return items.map(i => {
    const value = counts[i.key] || 0
    return { ...i, value, pct: Math.round(value / total * 100) }
  })
})

const punctualitySegments = computed(() => {
  const list = filteredSchedules.value.filter(s => s.check_in_at && s.start_at)
  let onTime = 0, late = 0
  const grace = 15 * 60000
  for (const s of list) {
    const diff = new Date(s.check_in_at) - new Date(s.start_at)
    if (diff <= grace) { onTime++ } else { late++ }
  }
  return [
    { label: 'On time', value: onTime, color: '#22c55e' },
    { label: 'Late', value: late, color: '#f59e0b' },
  ]
})

const punctualityPct = computed(() => {
  const tot = punctualitySegments.value.reduce((a, b) => a + b.value, 0)
  return tot ? Math.round(punctualitySegments.value[0].value / tot * 100) : 0
})

const perCaregiver = computed(() => {
  const map = {}
  for (const s of filteredSchedules.value) {
    const id = s.caregiver
    if (!id) continue
    if (!map[id]) map[id] = { id, name: s.caregiver_name, category: caregiverMeta(id)?.category, total: 0, completed: 0, missed: 0, inProgress: 0, checkIns: 0, onTime: 0, durSum: 0, durCnt: 0 }
    const e = map[id]
    e.total++
    if (s.status === 'completed') e.completed++
    if (s.status === 'missed') e.missed++
    if (s.status === 'checked_in') e.inProgress++
    if (s.check_in_at) {
      e.checkIns++
      if (s.start_at && (new Date(s.check_in_at) - new Date(s.start_at)) <= 15 * 60000) e.onTime++
    }
    if (s.status === 'completed' && s.check_in_at && s.check_out_at) {
      const ms = new Date(s.check_out_at) - new Date(s.check_in_at)
      if (ms > 0 && ms < 1000 * 60 * 60 * 24) { e.durSum += ms; e.durCnt++ }
    }
  }
  return Object.values(map)
})

const topCaregivers = computed(() => {
  const arr = perCaregiver.value.slice().sort((a, b) => b.total - a.total).slice(0, 8)
  const max = arr[0]?.total || 1
  return arr.map(c => ({ ...c, pct: Math.round(c.total / max * 100) }))
})

const caregiverStats = computed(() => {
  if (!selectedCaregiver.value) return null
  const c = perCaregiver.value.find(x => x.id === selectedCaregiver.value)
  if (!c) return { name: caregiverMeta(selectedCaregiver.value)?.user?.full_name || 'Caregiver', category: caregiverMeta(selectedCaregiver.value)?.category, total: 0, completed: 0, missed: 0, inProgress: 0, checkIns: 0, onTime: 0, completionRate: 0, avgDuration: 0 }
  const resolved = c.completed + c.missed
  return {
    ...c,
    name: c.name || caregiverMeta(c.id)?.user?.full_name || 'Caregiver',
    completionRate: resolved ? Math.round(c.completed / resolved * 100) : 0,
    avgDuration: c.durCnt ? (c.durSum / c.durCnt / 3600000).toFixed(1) : 0,
  }
})

const assignBars = computed(() => {
  const arr = perCaregiver.value.slice().sort((a, b) => b.total - a.total).slice(0, 12)
  return {
    labels: arr.map(c => c.name || '—'),
    values: arr.map(c => c.total),
    colors: arr.map(c => catHex(c.category)),
  }
})

const trendBars = computed(() => {
  const list = filteredSchedules.value
  const byDay = {}
  for (const s of list) {
    const d = new Date(s.start_at)
    const key = d.toISOString().slice(0, 10)
    byDay[key] = (byDay[key] || 0) + 1
  }
  const keys = Object.keys(byDay).sort()
  return {
    labels: keys.map(k => k.slice(5)),
    values: keys.map(k => byDay[k]),
    colors: keys.map(() => '#ec4899'),
  }
})

const checkInList = computed(() =>
  filteredSchedules.value.filter(s => s.check_in_at)
    .sort((a, b) => new Date(b.check_in_at) - new Date(a.check_in_at))
    .slice(0, 50)
)

const mapMarkers = computed(() => {
  const statusColor = { checked_in: '#14b8a6', completed: '#22c55e', scheduled: '#3b82f6', missed: '#f59e0b', cancelled: '#94a3b8' }
  return filteredSchedules.value
    .filter(s => s.gps_check_in?.lat != null && s.gps_check_in?.lng != null)
    .map(s => {
      const live = s.status === 'checked_in'
      const color = live ? '#14b8a6' : (statusColor[s.status] || '#0d9488')
      const info = `<div style="min-width:200px;font-family:Inter,Roboto,sans-serif">
        <div style="font-weight:700;font-size:13px;margin-bottom:4px">${esc(s.caregiver_name || 'Caregiver')}</div>
        <div style="font-size:12px;color:#475569;margin-bottom:2px">Patient: ${esc(s.patient_name || '—')}</div>
        <div style="font-size:12px;color:#475569;margin-bottom:2px">Status: ${esc(STATUS_META[s.status]?.label || s.status)}</div>
        <div style="font-size:12px;color:#475569;margin-bottom:2px">Check-in: ${esc(formatDateTime(s.check_in_at))}</div>
        <div style="font-size:11px;color:#94a3b8">±${Math.round(s.gps_check_in.accuracy || 0)}m accuracy</div>
      </div>`
      return {
        lat: s.gps_check_in.lat,
        lng: s.gps_check_in.lng,
        title: s.caregiver_name || 'Caregiver',
        color,
        live,
        info,
      }
    })
})

function esc(t) {
  return String(t == null ? '' : t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]))
}

const doseKpis = computed(() => {
  const list = doses.value
  const c = { taken: 0, missed: 0, skipped: 0, refused: 0, not_given: 0, pending: 0, autoMissed: 0, administered: 0 }
  for (const d of list) {
    if (c[d.status] != null) c[d.status]++
    if (d.auto_missed) c.autoMissed++
    if (d.administered_by_caregiver) c.administered++
  }
  const total = list.length
  const finalized = c.taken + c.missed + c.skipped + c.refused + c.not_given
  const adherenceRate = finalized ? Math.round(c.taken / finalized * 100) : 0
  return { total, ...c, finalized, adherenceRate }
})

const doseStatusSegments = computed(() => {
  const c = doseKpis.value
  return [
    { label: 'Documented', value: c.taken,     color: '#10b981' },
    { label: 'Missed',     value: c.missed,    color: '#ef4444' },
    { label: 'Skipped',    value: c.skipped,   color: '#94a3b8' },
    { label: 'Refused',    value: c.refused,   color: '#64748b' },
    { label: 'Not given',  value: c.not_given, color: '#dc2626' },
    { label: 'Pending',    value: c.pending,   color: '#f59e0b' },
  ].filter(s => s.value > 0)
})

const perCaregiverDoses = computed(() => {
  const map = {}
  for (const d of doses.value) {
    const id = d.administered_by_caregiver
    if (!id) continue
    if (!map[id]) map[id] = {
      id, name: d.administered_by_name, category: caregiverMeta(id)?.category,
      total: 0, taken: 0, missed: 0, skipped: 0, notGiven: 0, refused: 0, pending: 0,
      autoMissed: 0, onTime: 0, takenWithTime: 0, patients: new Set(),
    }
    const e = map[id]
    e.total++
    if (d.status === 'taken') {
      e.taken++
      if (d.administered_at && d.scheduled_at) {
        e.takenWithTime++
        if ((new Date(d.administered_at) - new Date(d.scheduled_at)) <= 60 * 60000) e.onTime++
      }
    }
    if (d.status === 'missed') e.missed++
    if (d.status === 'skipped') e.skipped++
    if (d.status === 'not_given') e.notGiven++
    if (d.status === 'refused') e.refused++
    if (d.status === 'pending') e.pending++
    if (d.auto_missed) e.autoMissed++
    if (d.patient_id) e.patients.add(d.patient_id)
  }
  return Object.values(map).map(e => {
    const finalized = e.taken + e.missed + e.skipped + e.notGiven + e.refused
    const adherenceRate = finalized ? Math.round(e.taken / finalized * 100) : 0
    const onTimeRate = e.takenWithTime ? Math.round(e.onTime / e.takenWithTime * 100) : 0
    return { ...e, patients: e.patients.size, finalized, adherenceRate, onTimeRate }
  })
})

const caregiverDoseRanking = computed(() =>
  perCaregiverDoses.value.slice().sort((a, b) => b.adherenceRate - a.adherenceRate || b.taken - a.taken)
)

const caregiverDoseStats = computed(() => {
  if (!selectedCaregiver.value) return null
  return perCaregiverDoses.value.find(x => x.id === selectedCaregiver.value) || null
})

function leaderColor(idx) {
  const colors = ['amber', 'purple', 'teal', 'info', 'blue', 'pink', 'indigo', 'green', 'cyan', 'orange']
  return colors[idx % colors.length]
}

function focusMarker(item) {
  if (!item?.gps_check_in?.lat) return
  const el2 = document.querySelector('.cgm-map')
  if (el2) el2.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

function openDetail(ev) { selected.value = ev; detailDialog.value = true }

function gpsShort(g) {
  if (!g?.lat) return '—'
  return `${g.lat.toFixed(3)}, ${g.lng.toFixed(3)}`
}
function initials(name) {
  if (!name) return '?'
  const p = name.trim().split(/\s+/)
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || name[0].toUpperCase()
}
function formatTime(iso) { return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }
function formatDateTime(iso) { return iso ? new Date(iso).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : '' }
function duration(a, b) {
  const ms = new Date(b) - new Date(a); const m = Math.round(ms / 60000)
  const h = Math.floor(m / 60), mm = m % 60; return h ? `${h}h ${mm}m` : `${mm}m`
}

function onRangeChange() { reload() }
function reload() { loadSchedules(); loadDoses() }

async function loadCaregivers() {
  try {
    const { data } = await $api.get('/homecare/caregivers/', { params: { page_size: 500 } })
    caregivers.value = data?.results || data || []
    for (const c of caregivers.value) {
      if (!c.category && c.caregiver_category) c.category = c.caregiver_category
    }
  } catch { /* silent */ }
}

async function loadSchedules() {
  loading.value = true
  try {
    const { start, end } = computeWindow()
    const params = {
      page_size: 1000,
      start_after: start.toISOString(),
      end_before: end.toISOString(),
    }
    const { data } = await $api.get('/homecare/schedules/', { params })
    const list = data?.results || data || []
    for (const s of list) {
      if (!s.caregiver_category) {
        const m = caregiverMeta(s.caregiver)
        s.caregiver_category = m?.category
      }
    }
    schedules.value = list
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load schedules', color: 'error' })
  } finally {
    loading.value = false
  }
}

async function loadDoses() {
  try {
    try { await $api.post('/homecare/doses/auto_expire/') } catch { /* non-fatal */ }
    const { start, end } = computeWindow()
    const params = { page_size: 1000, from: start.toISOString(), to: end.toISOString(), ordering: 'scheduled_at' }
    const { data } = await $api.get('/homecare/doses/', { params })
    doses.value = data?.results || data || []
  } catch { /* doses optional */ }
}

async function loadAll() {
  await Promise.all([loadCaregivers(), loadSchedules(), loadDoses()])
}

const { connected: liveConnected } = useHomecareEvents((evt) => {
  if (!evt) return
  const t = evt.type || evt.event || ''
  if (/check_in|check_out|schedule|assignment|visit|dose|adherence|medication/i.test(t)) {
    reload()
  }
})

watch(statusFilter, () => {})
watch(caregiverFilter, () => {})

onMounted(loadAll)
</script>

<style scoped>
.cm-bg { min-height: calc(100vh - 64px); }
.cm-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark .cm-card) {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.cm-table :deep(th) { background: rgba(0,0,0,0.025); font-weight: 600; }
:global(.v-theme--dark .cm-table th) { background: rgba(255,255,255,0.04); }

.cm-stat { text-align: center; padding: 8px 4px; border-radius: 10px; background: rgba(15,23,42,0.03); }
:global(.v-theme--dark .cm-stat) { background: rgba(255,255,255,0.04); }
.cm-stat-v { font-size: 1.3rem; font-weight: 800; line-height: 1.1; }
.cm-stat-l { font-size: 11px; color: rgba(15,23,42,0.55); text-transform: uppercase; letter-spacing: .03em; }
:global(.v-theme--dark .cm-stat-l) { color: rgba(255,255,255,0.5); }

.cm-checkin-list { max-height: 360px; overflow-y: auto; }
.cm-checkin-row {
  display: flex; align-items: center; padding: 10px;
  border-radius: 12px; border: 1px solid rgba(15,23,42,0.06);
  cursor: pointer; transition: background .15s ease, border-color .15s ease;
}
.cm-checkin-row:hover { background: rgba(99,102,241,0.06); border-color: rgba(99,102,241,0.2); }
.cm-checkin-active { border-left: 3px solid #14b8a6; }
:global(.v-theme--dark .cm-checkin-row) { border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .cm-checkin-row:hover) { background: rgba(99,102,241,0.12); }

.cm-row { transition: background .15s ease; cursor: pointer; }
.cm-row:hover { background: rgba(99,102,241,0.06); }

.cm-dose-list { max-height: 460px; overflow-y: auto; }
.cm-dose-row {
  padding: 10px 12px; border-radius: 12px;
  border: 1px solid rgba(15,23,42,0.06); cursor: pointer;
  transition: background .15s ease, border-color .15s ease, transform .12s ease;
}
.cm-dose-row:hover { background: rgba(16,185,129,0.06); border-color: rgba(16,185,129,0.25); transform: translateY(-1px); }
.cm-dose-selected { border-color: #10b981; background: rgba(16,185,129,0.08); }
:global(.v-theme--dark .cm-dose-row) { border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .cm-dose-row:hover) { background: rgba(16,185,129,0.12); }
:global(.v-theme--dark .cm-dose-selected) { background: rgba(16,185,129,0.14); }

.cm-live-dot { animation: cm-pulse 1.4s ease-in-out infinite; }
@keyframes cm-pulse { 0%,100% { opacity: 1 } 50% { opacity: .25 } }

.cursor-pointer { cursor: pointer; }
.min-w-0 { min-width: 0; }
</style>
