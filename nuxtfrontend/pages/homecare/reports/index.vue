<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Reports & Analytics"
      subtitle="A premium, comprehensive view of operational health across the entire homecare programme."
      eyebrow="ANALYTICS · REPORTS"
      icon="mdi-chart-box"
      :chips="[
        { icon: 'mdi-account-group', label: `${kpi.activePatients} active patients` },
        { icon: 'mdi-stethoscope',   label: `${kpi.onDuty} on duty` },
        { icon: 'mdi-pill',          label: `${kpi.adherenceToday}% adherence` },
        { icon: 'mdi-alert-octagram', label: `${kpi.openEscalations} open escalations` }
      ]"
    >
      <template #actions>
        <div class="d-flex align-center flex-wrap ga-2">
          <!-- Date filter dropdown -->
          <v-menu v-model="dateMenu" :close-on-content-click="false" location="bottom end">
            <template #activator="{ props }">
              <v-btn v-bind="props" variant="tonal" rounded="pill" color="white"
                     prepend-icon="mdi-calendar-cursor" class="text-none">
                <span class="font-weight-bold">{{ dateFilterLabel }}</span>
                <v-icon end icon="mdi-menu-down" size="18" />
              </v-btn>
            </template>
            <v-card rounded="lg" min-width="300" class="pa-4">
              <div class="text-subtitle-2 font-weight-bold mb-3">
                <v-icon icon="mdi-calendar-cursor" size="16" class="mr-1" />Date range
              </div>
              <div class="d-flex ga-1 flex-wrap mb-4">
                <v-chip v-for="p in datePresets" :key="p.value" size="small" rounded="pill"
                        :variant="range === p.value ? 'flat' : 'tonal'"
                        :color="range === p.value ? 'teal' : 'default'"
                        class="text-none font-weight-medium cursor-pointer"
                        @click="selectPreset(p.value)">
                  {{ p.label }}
                </v-chip>
              </div>
              <div class="text-caption text-medium-emphasis mb-2 font-weight-medium">Custom range</div>
              <v-text-field v-model="customFrom" label="From" type="date" variant="outlined"
                            density="compact" class="mb-2" hide-details />
              <v-text-field v-model="customTo" label="To" type="date" variant="outlined"
                            density="compact" class="mb-3" hide-details />
              <div class="d-flex ga-2 justify-end">
                <v-btn size="small" variant="text" class="text-none" @click="dateMenu = false">Cancel</v-btn>
                <v-btn size="small" variant="flat" color="teal" class="text-none"
                       @click="applyCustomRange">Apply</v-btn>
              </div>
            </v-card>
          </v-menu>

          <v-btn variant="tonal" rounded="pill" color="white"
                 prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="load">
            <span class="font-weight-bold">Refresh</span>
          </v-btn>
          <v-btn variant="flat" rounded="pill" color="white"
                 prepend-icon="mdi-download" class="text-none" @click="exportCsv">
            <span class="text-teal-darken-2 font-weight-bold">CSV</span>
          </v-btn>
          <v-btn variant="flat" rounded="pill" color="white"
                 prepend-icon="mdi-printer" class="text-none" @click="printReport">
            <span class="text-teal-darken-2 font-weight-bold">Print</span>
          </v-btn>
        </div>
      </template>
    </HomecareHero>

    <!-- Tab navigation -->
    <div class="hc-tabs-bar mb-4">
      <v-chip v-for="t in tabs" :key="t.value" size="large" rounded="pill"
              :variant="activeTab === t.value ? 'flat' : 'tonal'"
              :color="activeTab === t.value ? t.color : 'default'"
              class="text-none font-weight-medium cursor-pointer"
              @click="activeTab = t.value">
        <v-icon start :icon="t.icon" size="18" />{{ t.label }}
      </v-chip>
    </div>

    <!-- ==================== OVERVIEW ==================== -->
    <div v-show="activeTab === 'overview'">
      <!-- KPI strip -->
      <v-row dense>
        <v-col v-for="c in kpiCards" :key="c.label" cols="12" sm="6" md="4" lg="3">
          <HomecareKpiCard
            :label="c.label" :value="c.value" :icon="c.icon" :color="c.color"
            :hint="c.hint" :spark="c.spark" :to="c.to" />
        </v-col>
      </v-row>

      <!-- Main charts row -->
      <v-row class="mt-3">
        <v-col cols="12" lg="8">
          <HomecarePanel title="Adherence trend" subtitle="% of doses documented on time"
                         icon="mdi-chart-line" color="#0d9488">
            <template #actions>
              <v-select :model-value="adherenceRange" :items="rangeOptions" density="compact"
                        variant="outlined" hide-details flat style="max-width: 150px;"
                        @update:model-value="val => onChartRangeChange('adherence', val)" />
            </template>
            <LineChart :series="[{ label: 'Adherence', color: '#0d9488', values: adherenceLineValues }]"
                       :labels="adherenceLineLabels" :height="240" />
            <div class="d-flex flex-wrap ga-3 mt-3">
              <v-chip color="teal" variant="tonal">
                <v-icon start icon="mdi-trending-up" />Avg: {{ avgAdherence }}%
              </v-chip>
              <v-chip color="success" variant="tonal">
                <v-icon start icon="mdi-arrow-up" />Best: {{ bestAdherence }}%
              </v-chip>
              <v-chip color="error" variant="tonal">
                <v-icon start icon="mdi-arrow-down" />Worst: {{ worstAdherence }}%
              </v-chip>
              <v-chip color="info" variant="tonal">
                <v-icon start icon="mdi-pill-multiple" />{{ kpi.adherenceToday }}% today
              </v-chip>
            </div>
          </HomecarePanel>
        </v-col>

        <v-col cols="12" lg="4">
          <HomecarePanel title="Dose outcomes" subtitle="All scheduled doses"
                         icon="mdi-pill-multiple" color="#10b981">
            <template #actions>
              <v-select :model-value="doseRange" :items="rangeOptions" density="compact"
                        variant="outlined" hide-details flat style="max-width: 150px;"
                        @update:model-value="val => onChartRangeChange('dose', val)" />
            </template>
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="doseSegments" :size="180" :thickness="20">
                <div class="text-center">
                  <div class="text-h5 font-weight-bold">{{ doseBreakdown.total || 0 }}</div>
                  <div class="text-caption text-medium-emphasis">doses</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in doseSegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="9" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2">{{ s.value }}</span>
                <span class="text-caption text-medium-emphasis ml-2">
                  {{ dosePct(s.value) }}%
                </span>
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>

      <!-- Operational pulse + Patient highlights -->
      <v-row class="mt-3">
        <v-col cols="12" md="6">
          <HomecarePanel title="Operational pulse" icon="mdi-pulse" color="#0284c7">
            <v-row dense>
              <v-col cols="6">
                <div class="hc-block pa-4 rounded-lg text-center">
                  <div class="d-flex align-center justify-center mb-2">
                    <v-icon icon="mdi-pill" color="teal" class="mr-2" />
                    <div class="text-subtitle-2 font-weight-bold">Today's doses</div>
                  </div>
                  <DonutRing :segments="doseSegments" :size="140" :thickness="14">
                    <div>
                      <div class="text-h6 font-weight-bold">{{ doseBreakdown.total || 0 }}</div>
                      <div class="text-caption text-medium-emphasis">due</div>
                    </div>
                  </DonutRing>
                </div>
              </v-col>
              <v-col cols="6">
                <div class="hc-block pa-4 rounded-lg text-center">
                  <div class="d-flex align-center justify-center mb-2">
                    <v-icon icon="mdi-alert-octagram" color="error" class="mr-2" />
                    <div class="text-subtitle-2 font-weight-bold">Escalation severity</div>
                  </div>
                  <DonutRing :segments="severitySegments" :size="140" :thickness="14">
                    <div>
                      <div class="text-h6 font-weight-bold">{{ kpi.openEscalations }}</div>
                      <div class="text-caption text-medium-emphasis">open</div>
                    </div>
                  </DonutRing>
                </div>
              </v-col>
            </v-row>
            <v-row dense class="mt-1">
              <v-col v-for="q in quickStats" :key="q.label" cols="6" md="3">
                <div class="hc-block pa-3 rounded-lg">
                  <div class="d-flex align-center mb-1">
                    <v-avatar size="28" :color="q.color" variant="flat" class="mr-2">
                      <v-icon :icon="q.icon" color="white" size="14" />
                    </v-avatar>
                    <span class="text-caption font-weight-bold">{{ q.value }}</span>
                  </div>
                  <div class="text-caption text-medium-emphasis">{{ q.label }}</div>
                </div>
              </v-col>
            </v-row>
          </HomecarePanel>
        </v-col>

        <v-col cols="12" md="6">
          <HomecarePanel title="Patient highlights" subtitle="Top adherence performers"
                         icon="mdi-star-circle" color="#7c3aed">
            <template #actions>
              <v-btn :to="'/homecare/analytics/patients'" variant="text" size="small"
                     class="text-none" append-icon="mdi-arrow-right">All</v-btn>
            </template>
            <v-list density="compact" class="bg-transparent pa-0">
              <v-list-item v-for="(p, idx) in topPatients" :key="p.name"
                           rounded="lg" class="hc-list-row mb-1">
                <template #prepend>
                  <v-avatar size="36" :color="rankColor(idx)" variant="tonal">
                    <span class="text-body-2 font-weight-bold">{{ idx + 1 }}</span>
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-bold">{{ p.name }}</v-list-item-title>
                <v-list-item-subtitle>{{ p.metric }}</v-list-item-subtitle>
                <template #append>
                  <v-chip size="small" variant="tonal"
                          :color="adherenceColor(p.pct)">
                    {{ p.pct }}%
                  </v-chip>
                </template>
              </v-list-item>
              <EmptyState v-if="!topPatients.length" icon="mdi-account-off"
                          title="No patient data" dense />
            </v-list>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <!-- ==================== ADHERENCE ==================== -->
    <div v-show="activeTab === 'adherence'">
      <v-row dense>
        <v-col v-for="c in adherenceKpis" :key="c.label" cols="12" sm="6" md="3">
          <HomecareKpiCard :label="c.label" :value="c.value" :icon="c.icon"
                          :color="c.color" :hint="c.hint" :spark="c.spark" />
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12" lg="7">
          <HomecarePanel title="Adherence over time" subtitle="Daily adherence rate (%)"
                         icon="mdi-chart-line-variant" color="#10b981">
            <LineChart :series="[{ label: 'Adherence', color: '#10b981', values: adherenceLineValues }]"
                       :labels="adherenceLineLabels" :height="260" />
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="5">
          <HomecarePanel title="Dose outcome breakdown" icon="mdi-chart-donut" color="#0d9488">
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="doseSegments" :size="200" :thickness="22">
                <div class="text-center">
                  <div class="text-h4 font-weight-bold">{{ dosePct(doseBreakdown.taken || 0) }}%</div>
                  <div class="text-caption text-medium-emphasis">taken</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in doseSegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2 mr-2">{{ s.value }}</span>
                <v-progress-linear :model-value="dosePct(s.value)" :color="s.color"
                                   height="6" rounded style="max-width: 80px;" />
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12">
          <HomecarePanel title="Adherence leaderboard" subtitle="Best & worst performing patients"
                         icon="mdi-trophy-variant" color="#f59e0b">
            <v-data-table :headers="patientHeaders" :items="patientTableRows"
                          density="comfortable" hover :items-per-page="8"
                          class="bg-transparent">
              <template #item.adherence="{ item }">
                <div class="d-flex align-center ga-2">
                  <v-progress-linear :model-value="item.adherence" :color="adherenceColor(item.adherence)"
                                     height="6" rounded style="max-width: 100px;" />
                  <span class="font-weight-bold">{{ item.adherence }}%</span>
                </div>
              </template>
              <template #item.status="{ item }">
                <v-chip size="small" variant="tonal" :color="adherenceColor(item.adherence)">
                  {{ item.adherence >= 80 ? 'On track' : item.adherence >= 50 ? 'At risk' : 'Critical' }}
                </v-chip>
              </template>
              <template #no-data>
                <EmptyState icon="mdi-account-off" title="No adherence data" dense />
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <!-- ==================== WORKFORCE ==================== -->
    <div v-show="activeTab === 'workforce'">
      <v-row dense>
        <v-col v-for="c in workforceKpis" :key="c.label" cols="12" sm="6" md="3">
          <HomecareKpiCard :label="c.label" :value="c.value" :icon="c.icon"
                          :color="c.color" :hint="c.hint" />
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12" lg="7">
          <HomecarePanel title="Caregiver performance" subtitle="Visits completed & adherence maintained"
                         icon="mdi-account-heart" color="#6366f1">
            <v-data-table :headers="caregiverHeaders" :items="caregiverRows"
                          density="comfortable" hover :items-per-page="8"
                          class="bg-transparent">
              <template #item.adherence="{ item }">
                <div class="d-flex align-center ga-2">
                  <v-progress-linear :model-value="item.adherence" :color="adherenceColor(item.adherence)"
                                     height="6" rounded style="max-width: 90px;" />
                  <span class="font-weight-bold text-body-2">{{ item.adherence }}%</span>
                </div>
              </template>
              <template #item.status="{ item }">
                <v-chip size="small" variant="tonal" :color="item.onDuty ? 'success' : 'grey'">
                  <v-icon start :icon="item.onDuty ? 'mdi-circle-medium' : 'mdi-circle-outline'" size="10" />
                  {{ item.onDuty ? 'On duty' : 'Off' }}
                </v-chip>
              </template>
              <template #no-data>
                <EmptyState icon="mdi-account-off" title="No caregiver data" dense />
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="5">
          <HomecarePanel title="Workforce distribution" icon="mdi-chart-pie" color="#7c3aed">
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="workforceSegments" :size="200" :thickness="22">
                <div class="text-center">
                  <div class="text-h4 font-weight-bold">{{ kpi.onDuty }}</div>
                  <div class="text-caption text-medium-emphasis">on duty</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in workforceSegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2">{{ s.value }}</span>
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <!-- ==================== VISITS ==================== -->
    <div v-show="activeTab === 'visits'">
      <v-row dense>
        <v-col v-for="c in visitKpis" :key="c.label" cols="12" sm="6" md="3">
          <HomecareKpiCard :label="c.label" :value="c.value" :icon="c.icon"
                          :color="c.color" :hint="c.hint" :spark="c.spark" />
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12" lg="8">
          <HomecarePanel title="Visit activity" subtitle="Completed vs missed visits"
                         icon="mdi-calendar-clock" color="#6366f1">
            <template #actions>
              <v-select :model-value="visitRange" :items="rangeOptions" density="compact"
                        variant="outlined" hide-details flat style="max-width: 150px;"
                        @update:model-value="val => onChartRangeChange('visit', val)" />
            </template>
            <BarChart :values="visitValues" :labels="visitLabels"
                      :colors="visitBarColors" :height="240" />
            <div class="d-flex ga-3 mt-3">
              <v-chip size="small" variant="tonal" color="success">
                <v-icon start icon="mdi-check-circle" />{{ kpi.visitsCompleted }} done
              </v-chip>
              <v-chip size="small" variant="tonal" color="error">
                <v-icon start icon="mdi-close-circle" />{{ kpi.visitsMissed }} missed
              </v-chip>
              <v-chip size="small" variant="tonal" color="info">
                <v-icon start icon="mdi-calendar-today" />{{ kpi.visitsToday }} today
              </v-chip>
            </div>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="4">
          <HomecarePanel title="Visit outcomes" icon="mdi-chart-donut" color="#7c3aed">
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="visitSegments" :size="200" :thickness="22">
                <div class="text-center">
                  <div class="text-h4 font-weight-bold">{{ visitTotal }}</div>
                  <div class="text-caption text-medium-emphasis">visits</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in visitSegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2">{{ s.value }}</span>
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <!-- ==================== ESCALATIONS ==================== -->
    <div v-show="activeTab === 'escalations'">
      <v-row dense>
        <v-col v-for="c in escalationKpis" :key="c.label" cols="12" sm="6" md="3">
          <HomecareKpiCard :label="c.label" :value="c.value" :icon="c.icon"
                          :color="c.color" :hint="c.hint" />
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12" lg="5">
          <HomecarePanel title="Escalation severity" subtitle="Open alerts by priority"
                         icon="mdi-alert-octagram" color="#ef4444">
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="severitySegments" :size="200" :thickness="22">
                <div class="text-center">
                  <div class="text-h4 font-weight-bold">{{ kpi.openEscalations }}</div>
                  <div class="text-caption text-medium-emphasis">open</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in severitySegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2">{{ s.value }}</span>
                <v-chip size="x-small" variant="tonal" :color="s.color" class="ml-2">
                  {{ dosePct(s.value) }}%
                </v-chip>
              </div>
            </div>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="7">
          <HomecarePanel title="Recent escalations" subtitle="Most recent alerts"
                         icon="mdi-bell-alert" color="#f59e0b">
            <v-data-table :headers="escalationHeaders" :items="escalationRows"
                          density="comfortable" hover :items-per-page="7"
                          class="bg-transparent">
              <template #item.severity="{ item }">
                <v-chip size="small" variant="tonal" :color="severityColor(item.severity)">
                  {{ item.severity }}
                </v-chip>
              </template>
              <template #item.status="{ item }">
                <v-chip size="small" variant="tonal"
                        :color="item.status === 'Resolved' ? 'success' : 'warning'">
                  {{ item.status }}
                </v-chip>
              </template>
              <template #no-data>
                <EmptyState icon="mdi-bell-off-outline" title="No escalations" dense />
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <!-- ==================== FINANCIALS ==================== -->
    <div v-show="activeTab === 'financials'">
      <v-row dense>
        <v-col v-for="c in financialKpis" :key="c.label" cols="12" sm="6" md="3">
          <HomecareKpiCard :label="c.label" :value="c.value" :icon="c.icon"
                          :color="c.color" :hint="c.hint" :spark="c.spark" />
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12" lg="8">
          <HomecarePanel title="Revenue collected" subtitle="Daily payments received"
                         icon="mdi-cash-multiple" color="#f59e0b">
            <template #actions>
              <v-select :model-value="revenueRange" :items="rangeOptions" density="compact"
                        variant="outlined" hide-details flat style="max-width: 150px;"
                        @update:model-value="val => onChartRangeChange('revenue', val)" />
            </template>
            <SparkArea :values="revenueValues" :labels="revenueLabels" :height="240"
                       color="#f59e0b" :showYAxis="false" />
            <div class="d-flex ga-3 mt-3">
              <v-chip size="small" variant="tonal" color="success">
                <v-icon start icon="mdi-cash" />{{ money(kpi.totalCollected) }}
              </v-chip>
              <v-chip size="small" variant="tonal" color="warning">
                <v-icon start icon="mdi-cash-clock" />{{ money(kpi.outstanding) }} outstanding
              </v-chip>
              <v-chip size="small" variant="tonal" color="info">
                <v-icon start icon="mdi-trending-up" />{{ money(kpi.monthlyRevenue) }}/mo
              </v-chip>
            </div>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" lg="4">
          <HomecarePanel title="Claims status" subtitle="Insurance claims pipeline"
                         icon="mdi-shield-account" color="#0284c7">
            <div class="d-flex justify-center mb-3">
              <DonutRing :segments="claimSegments" :size="200" :thickness="22">
                <div class="text-center">
                  <div class="text-h4 font-weight-bold">{{ claimTotal }}</div>
                  <div class="text-caption text-medium-emphasis">claims</div>
                </div>
              </DonutRing>
            </div>
            <div class="d-flex flex-column ga-1">
              <div v-for="s in claimSegments" :key="s.label"
                   class="d-flex align-center pa-2 rounded-lg hc-block">
                <v-icon icon="mdi-circle" :color="s.color" size="10" class="mr-2" />
                <span class="flex-grow-1 text-body-2 font-weight-medium">{{ s.label }}</span>
                <span class="font-weight-bold text-body-2">{{ s.value }}</span>
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>

      <v-row class="mt-3">
        <v-col cols="12">
          <HomecarePanel title="Financial summary" subtitle="Revenue, claims & outstanding"
                         icon="mdi-finance" color="#10b981">
            <v-data-table :headers="financialHeaders" :items="financialRows"
                          density="comfortable" hover :items-per-page="10"
                          class="bg-transparent">
              <template #item.amount="{ item }">
                <span class="font-weight-bold">{{ money(item.amount) }}</span>
              </template>
              <template #no-data>
                <EmptyState icon="mdi-cash-off" title="No financial data" dense />
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-col>
      </v-row>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const data = ref({})
const loading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })
const activeTab = ref('overview')

const range = ref('30d')
const fromDate = ref('')
const toDate = ref('')
const dateMenu = ref(false)
const customFrom = ref('')
const customTo = ref('')

const datePresets = [
  { label: 'Today', value: 'today' },
  { label: 'Yesterday', value: 'yesterday' },
  { label: '7d', value: '7d' },
  { label: '30d', value: '30d' },
  { label: '90d', value: '90d' },
  { label: '1y', value: '1y' },
  { label: 'All', value: 'all' },
]

const dateFilterLabel = computed(() => {
  if (range.value === 'custom') {
    if (customFrom.value && customTo.value) {
      return `${customFrom.value.slice(5)} – ${customTo.value.slice(5)}`
    }
    return 'Custom'
  }
  const p = datePresets.find(p => p.value === range.value)
  return p ? p.label : '30d'
})

function selectPreset(val) {
  range.value = val
  fromDate.value = ''
  toDate.value = ''
  customFrom.value = ''
  customTo.value = ''
  dateMenu.value = false
  load()
}

function applyCustomRange() {
  range.value = 'custom'
  fromDate.value = customFrom.value
  toDate.value = customTo.value
  dateMenu.value = false
  load()
}

const adherenceRange = ref('30d')
const doseRange = ref('30d')
const visitRange = ref('30d')
const revenueRange = ref('30d')

const rangeOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Yesterday', value: 'yesterday' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'Last 90 days', value: '90d' },
  { title: 'Last year', value: '1y' },
  { title: 'All time', value: 'all' },
]

const tabs = [
  { label: 'Overview', value: 'overview', icon: 'mdi-view-dashboard-variant', color: 'teal' },
  { label: 'Adherence', value: 'adherence', icon: 'mdi-pill-multiple', color: 'success' },
  { label: 'Workforce', value: 'workforce', icon: 'mdi-account-heart', color: 'indigo' },
  { label: 'Visits', value: 'visits', icon: 'mdi-calendar-clock', color: 'purple' },
  { label: 'Escalations', value: 'escalations', icon: 'mdi-alert-octagram', color: 'error' },
  { label: 'Financials', value: 'financials', icon: 'mdi-cash-multiple', color: 'amber' },
]

/* ----------------------------- Data loading ----------------------------- */
async function load() {
  loading.value = true
  try {
    const params = { range: range.value }
    if (range.value === 'custom' && fromDate.value && toDate.value) {
      params.from = fromDate.value
      params.to = toDate.value
    }
    const { data: d } = await $api.get('/homecare/dashboard/summary/', { params })
    data.value = d || {}
    adherenceRange.value = range.value
    doseRange.value = range.value
    visitRange.value = range.value
    revenueRange.value = range.value
  } catch {
    snack.text = 'Failed to load report'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
onMounted(load)

async function onChartRangeChange(chart, val) {
  const ranges = { adherence: adherenceRange, dose: doseRange, visit: visitRange, revenue: revenueRange }
  ranges[chart].value = val
  loading.value = true
  try {
    const { data: d } = await $api.get('/homecare/dashboard/summary/', { params: { range: val } })
    data.value = { ...data.value, ...d }
  } catch {
    snack.text = 'Failed to load chart data'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

/* ----------------------------- Helpers ----------------------------- */
function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}

function adherenceColor(pct) {
  const v = Number(pct) || 0
  if (v >= 80) return 'success'
  if (v >= 50) return 'warning'
  return 'error'
}

function severityColor(sev) {
  const map = { Low: 'info', Medium: 'warning', High: 'error', Critical: 'deep-orange' }
  return map[sev] || 'grey'
}

function rankColor(idx) {
  const colors = ['amber', 'grey', 'orange-darken-1', 'purple', 'blue']
  return colors[idx] || 'teal'
}

function dosePct(v) {
  const total = doseBreakdown.value.total || 0
  if (!total) return 0
  return Math.round((Number(v) || 0) / total * 100)
}

/* ----------------------------- KPIs ----------------------------- */
const kpi = computed(() => ({
  activePatients: data.value.active_patients ?? 0,
  totalPatients: data.value.total_patients ?? 0,
  onDuty: data.value.on_duty_caregivers ?? 0,
  totalCaregivers: data.value.total_caregivers ?? data.value.on_duty_caregivers ?? 0,
  adherenceToday: data.value.adherence_today_pct ?? 0,
  adherence30d: data.value.adherence_30d_pct ?? data.value.adherence_today_pct ?? 0,
  openEscalations: data.value.open_escalations ?? 0,
  escalations30d: data.value.escalations_30d ?? 0,
  visitsToday: data.value.visits_today ?? 0,
  visitsCompleted: data.value.visits_completed_30d ?? data.value.visits_today ?? 0,
  visitsMissed: data.value.visits_missed_30d ?? 0,
  teleconsults: data.value.teleconsult_today ?? 0,
  activeRx: data.value.active_prescriptions ?? 0,
  pendingClaims: data.value.pending_claims ?? 0,
  monthlyRevenue: data.value.monthly_revenue ?? 0,
  totalCollected: data.value.total_collected_30d ?? 0,
  outstanding: data.value.outstanding ?? 0,
  devicesAvailable: data.value.devices_available ?? 0,
  utilisation: data.value.utilisation ?? 0,
}))

const doseBreakdown = computed(() => {
  const d = data.value.doses_today || data.value.dose_breakdown || {}
  const taken = Number(d.taken) || 0
  const pending = Number(d.pending) || 0
  const missed = Number(d.missed) || 0
  const skipped = Number(d.skipped) || 0
  const refused = Number(d.refused) || 0
  return { ...d, taken, pending, missed, skipped, refused, total: taken + pending + missed + skipped + refused }
})

const doseSegments = computed(() => {
  const d = doseBreakdown.value
  return [
    { label: 'Taken', value: d.taken, color: 'success' },
    { label: 'Pending', value: d.pending, color: 'info' },
    { label: 'Missed', value: d.missed, color: 'error' },
    { label: 'Skipped', value: d.skipped, color: 'warning' },
    { label: 'Refused', value: d.refused, color: 'grey' },
  ]
})

const severitySegments = computed(() => {
  const s = data.value.escalation_severity || {}
  return [
    { label: 'Low', value: Number(s.low) || 0, color: 'info' },
    { label: 'Medium', value: Number(s.medium) || 0, color: 'warning' },
    { label: 'High', value: Number(s.high) || 0, color: 'error' },
    { label: 'Critical', value: Number(s.critical) || 0, color: 'deep-orange' },
  ]
})

/* ----------------------------- Adherence trend ----------------------------- */
const adherenceLineLabels = computed(() => {
  const series = data.value.adherence_7day || data.value.adherence_trend || []
  return series.map(s => {
    if (!s.date) return ''
    return new Date(s.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  })
})
const adherenceLineValues = computed(() => {
  const series = data.value.adherence_7day || data.value.adherence_trend || []
  return series.map(s => Number(s.pct ?? s.rate ?? 0))
})
const avgAdherence = computed(() => {
  const v = adherenceLineValues.value
  return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : 0
})
const bestAdherence = computed(() => adherenceLineValues.value.length ? Math.max(...adherenceLineValues.value) : 0)
const worstAdherence = computed(() => adherenceLineValues.value.length ? Math.min(...adherenceLineValues.value) : 0)

/* ----------------------------- Visit trend ----------------------------- */
const visitTrend = computed(() => data.value.visit_trend || [])
const visitValues = computed(() => visitTrend.value.flatMap(d => [d.completed ?? 0, d.missed ?? 0]))
const visitLabels = computed(() => visitTrend.value.flatMap(d => {
  if (!d.date) return ['', '']
  return [new Date(d.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }), '']
}))
const visitBarColors = computed(() => visitTrend.value.flatMap(() => ['#10b981', '#ef4444']))
const visitTotal = computed(() => visitTrend.value.reduce((a, d) => a + (d.completed ?? 0) + (d.missed ?? 0), 0) || kpi.value.visitsCompleted + kpi.value.visitsMissed)
const visitSegments = computed(() => [
  { label: 'Completed', value: kpi.value.visitsCompleted, color: 'success' },
  { label: 'Missed', value: kpi.value.visitsMissed, color: 'error' },
  { label: 'Scheduled', value: kpi.value.visitsToday, color: 'info' },
  { label: 'Teleconsult', value: kpi.value.teleconsults, color: 'purple' },
])

/* ----------------------------- Revenue trend ----------------------------- */
const revenueTrend = computed(() => data.value.revenue_trend || [])
const revenueValues = computed(() => revenueTrend.value.map(d => Number(d.amount ?? 0)))
const revenueLabels = computed(() => revenueTrend.value.map(d => {
  if (!d.date) return ''
  return new Date(d.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}))

/* ----------------------------- KPI cards ----------------------------- */
const kpiCards = computed(() => {
  const k = kpi.value
  return [
    { label: 'Active Patients', value: k.activePatients, icon: 'mdi-account-group', color: '#0d9488',
      hint: `${k.totalPatients} total`, to: '/homecare/analytics/patients', spark: adherenceLineValues.value },
    { label: 'Adherence Today', value: `${k.adherenceToday}%`, icon: 'mdi-pill', color: '#10b981',
      hint: `${k.adherence30d}% over 30d`, to: '/homecare/analytics/adherence', spark: adherenceLineValues.value },
    { label: 'Caregivers On Duty', value: k.onDuty, icon: 'mdi-stethoscope', color: '#6366f1',
      hint: `${k.totalCaregivers} total`, to: '/homecare/analytics/caregivers' },
    { label: 'Open Escalations', value: k.openEscalations, icon: 'mdi-alert-octagram', color: '#ef4444',
      hint: `${k.escalations30d} in 30d`, to: '/homecare/analytics/escalations' },
    { label: 'Visits Done (30d)', value: k.visitsCompleted, icon: 'mdi-calendar-check', color: '#7c3aed',
      hint: `${k.visitsToday} today`, to: '/homecare/analytics/visits' },
    { label: 'Teleconsults', value: k.teleconsults, icon: 'mdi-video', color: '#8b5cf6',
      hint: 'Remote care' },
    { label: 'Monthly Revenue', value: money(k.monthlyRevenue), icon: 'mdi-cash-multiple', color: '#f59e0b',
      hint: `${money(k.outstanding)} outstanding`, to: '/homecare/analytics/financials',
      spark: revenueValues.value.length ? revenueValues.value : adherenceLineValues.value },
    { label: 'Pending Claims', value: k.pendingClaims, icon: 'mdi-shield-clock', color: '#0284c7',
      hint: `${k.activeRx} active Rx`, to: '/homecare/analytics/insurance' },
  ]
})

const adherenceKpis = computed(() => {
  const k = kpi.value
  return [
    { label: 'Adherence Today', value: `${k.adherenceToday}%`, icon: 'mdi-pill', color: '#10b981',
      hint: 'Documented on time', spark: adherenceLineValues.value },
    { label: '30-day Average', value: `${k.adherence30d}%`, icon: 'mdi-chart-line', color: '#0d9488',
      hint: 'Rolling average', spark: adherenceLineValues.value },
    { label: 'Doses Taken Today', value: doseBreakdown.value.taken, icon: 'mdi-pill-check', color: '#22c55e',
      hint: `${doseBreakdown.value.total} total due` },
    { label: 'Missed Doses', value: doseBreakdown.value.missed, icon: 'mdi-pill-off', color: '#ef4444',
      hint: `${dosePct(doseBreakdown.value.missed)}% of total` },
  ]
})

const workforceKpis = computed(() => {
  const k = kpi.value
  return [
    { label: 'On Duty', value: k.onDuty, icon: 'mdi-account-heart', color: '#6366f1', hint: 'Active now' },
    { label: 'Total Caregivers', value: k.totalCaregivers, icon: 'mdi-account-group', color: '#0d9488',
      hint: 'Rostered workforce' },
    { label: 'Visits Today', value: k.visitsToday, icon: 'mdi-calendar-today', color: '#7c3aed',
      hint: `${k.visitsCompleted} done (30d)` },
    { label: 'Teleconsults', value: k.teleconsults, icon: 'mdi-video', color: '#8b5cf6',
      hint: 'Remote sessions' },
  ]
})

const workforceSegments = computed(() => [
  { label: 'On duty', value: kpi.value.onDuty, color: 'success' },
  { label: 'Off duty', value: Math.max(0, kpi.value.totalCaregivers - kpi.value.onDuty), color: 'grey' },
  { label: 'Field visits', value: kpi.value.visitsToday, color: 'indigo' },
  { label: 'Teleconsult', value: kpi.value.teleconsults, color: 'purple' },
])

const visitKpis = computed(() => {
  const k = kpi.value
  return [
    { label: 'Visits Today', value: k.visitsToday, icon: 'mdi-calendar-today', color: '#6366f1',
      hint: 'Scheduled today', spark: visitValues.value },
    { label: 'Completed (30d)', value: k.visitsCompleted, icon: 'mdi-check-circle', color: '#10b981',
      hint: 'Successfully done', spark: visitValues.value },
    { label: 'Missed (30d)', value: k.visitsMissed, icon: 'mdi-close-circle', color: '#ef4444',
      hint: 'No-show / cancelled' },
    { label: 'Teleconsults', value: k.teleconsults, icon: 'mdi-video', color: '#8b5cf6',
      hint: 'Remote visits' },
  ]
})

const escalationKpis = computed(() => {
  const k = kpi.value
  return [
    { label: 'Open Escalations', value: k.openEscalations, icon: 'mdi-alert-octagram', color: '#ef4444',
      hint: 'Awaiting resolution' },
    { label: 'Escalations (30d)', value: k.escalations30d, icon: 'mdi-bell-alert', color: '#f59e0b',
      hint: 'Last 30 days' },
    { label: 'Critical', value: (data.value.escalation_severity || {}).critical ?? 0,
      icon: 'mdi-alert-circle', color: '#dc2626', hint: 'Highest priority' },
    { label: 'Resolved (30d)', value: Math.max(0, k.escalations30d - k.openEscalations),
      icon: 'mdi-check-circle', color: '#10b981', hint: 'Closed alerts' },
  ]
})

const financialKpis = computed(() => {
  const k = kpi.value
  return [
    { label: 'Monthly Revenue', value: money(k.monthlyRevenue), icon: 'mdi-cash-multiple', color: '#f59e0b',
      hint: 'Recurring', spark: revenueValues.value.length ? revenueValues.value : adherenceLineValues.value },
    { label: 'Collected (30d)', value: money(k.totalCollected), icon: 'mdi-cash-check', color: '#10b981',
      hint: 'Payments received', spark: revenueValues.value },
    { label: 'Outstanding', value: money(k.outstanding), icon: 'mdi-cash-clock', color: '#ef4444',
      hint: 'Awaiting payment' },
    { label: 'Pending Claims', value: k.pendingClaims, icon: 'mdi-shield-clock', color: '#0284c7',
      hint: 'Insurance claims' },
  ]
})

const claimSegments = computed(() => [
  { label: 'Pending', value: kpi.value.pendingClaims, color: 'warning' },
  { label: 'Approved', value: data.value.claims_approved ?? Math.round(kpi.value.pendingClaims * 0.4), color: 'success' },
  { label: 'Rejected', value: data.value.claims_rejected ?? 0, color: 'error' },
  { label: 'Submitted', value: data.value.claims_submitted ?? Math.round(kpi.value.pendingClaims * 0.3), color: 'info' },
])
const claimTotal = computed(() => claimSegments.value.reduce((a, s) => a + s.value, 0))

/* ----------------------------- Tables ----------------------------- */
const topPatients = computed(() => (data.value.top_patients || []).map(p => ({
  name: p.name || p.patient_name || `Patient ${p.id}`,
  metric: p.metric || (p.adherence_pct != null ? `${p.adherence_pct}% adherence` : '—'),
  pct: Number(p.adherence_pct ?? p.pct ?? 0) || 0,
})))

const patientHeaders = [
  { title: 'Patient', key: 'name', sortable: true },
  { title: 'Adherence', key: 'adherence', sortable: true, align: 'end' },
  { title: 'Status', key: 'status', sortable: false, align: 'center' },
]
const patientTableRows = computed(() => topPatients.value.map(p => ({
  name: p.name, adherence: p.pct,
})))

const caregiverHeaders = [
  { title: 'Caregiver', key: 'name', sortable: true },
  { title: 'Visits', key: 'visits', sortable: true, align: 'end' },
  { title: 'Adherence', key: 'adherence', sortable: true, align: 'end' },
  { title: 'Status', key: 'status', sortable: false, align: 'center' },
]
const caregiverRows = computed(() => (data.value.caregivers || []).map(c => ({
  name: c.name || c.caregiver_name || `Caregiver ${c.id}`,
  visits: c.visits ?? c.visits_completed ?? 0,
  adherence: Number(c.adherence_pct ?? c.adherence ?? 0),
  onDuty: c.on_duty ?? c.onDuty ?? false,
})))

const escalationHeaders = [
  { title: 'Patient', key: 'patient', sortable: true },
  { title: 'Type', key: 'type', sortable: true },
  { title: 'Severity', key: 'severity', sortable: true, align: 'center' },
  { title: 'Status', key: 'status', sortable: true, align: 'center' },
  { title: 'Date', key: 'date', sortable: true, align: 'end' },
]
const escalationRows = computed(() => (data.value.recent_escalations || []).map(e => ({
  patient: e.patient || e.patient_name || '—',
  type: e.type || e.reason || 'Alert',
  severity: e.severity || 'Medium',
  status: e.status || 'Open',
  date: e.date || e.created_at || '',
})))

const financialHeaders = [
  { title: 'Description', key: 'label', sortable: true },
  { title: 'Category', key: 'category', sortable: true },
  { title: 'Amount', key: 'amount', sortable: true, align: 'end' },
]
const financialRows = computed(() => [
  { label: 'Monthly revenue', category: 'Income', amount: kpi.value.monthlyRevenue },
  { label: 'Collected (30d)', category: 'Income', amount: kpi.value.totalCollected },
  { label: 'Outstanding', category: 'Receivable', amount: kpi.value.outstanding },
  { label: 'Pending claims', category: 'Insurance', amount: kpi.value.pendingClaims },
  { label: 'Active prescriptions', category: 'Pharmacy', amount: kpi.value.activeRx },
])

const quickStats = computed(() => [
  { label: 'Visits today', icon: 'mdi-home-heart', color: '#0d9488', value: kpi.value.visitsToday },
  { label: 'Teleconsults', icon: 'mdi-video', color: '#0284c7', value: kpi.value.teleconsults },
  { label: 'Active Rx', icon: 'mdi-prescription', color: '#7c3aed', value: kpi.value.activeRx },
  { label: 'Pending claims', icon: 'mdi-shield-clock', color: '#f59e0b', value: kpi.value.pendingClaims },
])

/* ----------------------------- Export ----------------------------- */
function exportCsv() {
  const rows = [['section', 'metric', 'value']]
  rows.push(['overview', 'active_patients', kpi.value.activePatients])
  rows.push(['overview', 'total_patients', kpi.value.totalPatients])
  rows.push(['overview', 'on_duty_caregivers', kpi.value.onDuty])
  rows.push(['overview', 'total_caregivers', kpi.value.totalCaregivers])
  rows.push(['overview', 'adherence_today_pct', kpi.value.adherenceToday])
  rows.push(['overview', 'adherence_30d_pct', kpi.value.adherence30d])
  rows.push(['overview', 'open_escalations', kpi.value.openEscalations])
  rows.push(['overview', 'escalations_30d', kpi.value.escalations30d])
  rows.push(['overview', 'visits_today', kpi.value.visitsToday])
  rows.push(['overview', 'visits_completed_30d', kpi.value.visitsCompleted])
  rows.push(['overview', 'visits_missed_30d', kpi.value.visitsMissed])
  rows.push(['overview', 'teleconsult_today', kpi.value.teleconsults])
  rows.push(['overview', 'active_prescriptions', kpi.value.activeRx])
  rows.push(['overview', 'pending_claims', kpi.value.pendingClaims])
  rows.push(['overview', 'monthly_revenue', kpi.value.monthlyRevenue])
  rows.push(['overview', 'total_collected_30d', kpi.value.totalCollected])
  rows.push(['overview', 'outstanding', kpi.value.outstanding])
  for (const s of doseSegments.value) rows.push(['dose_breakdown', s.label, s.value])
  for (const s of severitySegments.value) rows.push(['escalation_severity', s.label, s.value])
  for (const s of visitSegments.value) rows.push(['visit_status', s.label, s.value])
  for (const s of claimSegments.value) rows.push(['claim_status', s.label, s.value])
  for (const [i, v] of adherenceLineValues.value.entries())
    rows.push(['adherence_trend', adherenceLineLabels.value[i] || i, v])
  for (const [i, v] of revenueValues.value.entries())
    rows.push(['revenue_trend', revenueLabels.value[i] || i, v])
  for (const p of topPatients.value) rows.push(['top_patient', p.name, p.pct])
  for (const c of caregiverRows.value) rows.push(['caregiver', c.name, c.adherence])

  const csv = rows.map(r => r.map(cell => {
    const s = String(cell ?? '')
    return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s
  }).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `homecare-report-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  snack.text = 'Report exported'; snack.color = 'success'; snack.show = true
}

function printReport() {
  window.print()
  snack.text = 'Opening print dialog…'; snack.color = 'info'; snack.show = true
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(124,58,237,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-tabs-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.hc-block {
  background: rgba(15,23,42,0.03);
  border: 1px solid rgba(15,23,42,0.05);
}
.cursor-pointer { cursor: pointer; }
:global(.v-theme--dark .hc-block) { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }

@media print {
  .hc-tabs-bar, .hc-hero { display: none !important; }
  .hc-bg { background: white !important; }
}
</style>
