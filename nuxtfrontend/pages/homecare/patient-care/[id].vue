<template>
  <div class="command-centre">
    <!-- ═══════════════════════════════════ PATIENT HEADER ═══════════════════════════════════ -->
    <div class="cc-hero" :style="{ background: heroGradient }">
      <div class="cc-hero-inner">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-arrow-left" class="text-none" to="/homecare/patient-care" size="small" />
          <div class="flex-grow-1">
            <div class="d-flex align-center ga-3 flex-wrap">
              <v-avatar size="56" :color="riskHex" class="cc-avatar"><span class="text-h5 font-weight-bold text-white">{{ initials(patientName) }}</span></v-avatar>
              <div>
                <div class="d-flex align-center ga-2 flex-wrap">
                  <h1 class="text-h4 font-weight-bold text-white mb-0">{{ patientName || 'Loading...' }}</h1>
                  <v-chip :color="riskColor" variant="flat" size="small" class="font-weight-bold text-white">{{ riskLabel }} RISK</v-chip>
                </div>
                <p class="text-body-2 mt-1 mb-0" style="color:rgba(255,255,255,0.75)">
                  {{ patientMrn || '—' }}
                  <span v-if="careSummaryPatient?.is_active"> · Active</span>
                  <span v-if="careSummaryPatient?.risk_level"> · {{ careSummaryPatient.risk_level }}</span>
                </p>
              </div>
            </div>
          </div>
          <div class="d-flex ga-2 flex-wrap">
            <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-heart-pulse" class="text-none" @click="openQuickVitals"><span class="font-weight-bold" :style="{ color: riskHex }">Record Vitals</span></v-btn>
            <v-btn variant="outlined" rounded="pill" color="white" prepend-icon="mdi-clipboard-plus" class="text-none" :to="`/homecare/assessments/new`">New Assessment</v-btn>
          </div>
        </div>
      </div>
      <div class="cc-hero-glow" /><div class="cc-hero-pattern" />
    </div>

    <!-- ═══════════════════════════════════ KPI ROW ═══════════════════════════════════════════ -->
    <v-row dense class="px-4 px-md-6 mt-n6 cc-kpi-row">
      <v-col v-for="kpi in kpiCards" :key="kpi.label" cols="6" sm="4" md="2">
        <v-card rounded="xl" elevation="8" class="cc-kpi-card pa-3 text-center">
          <v-icon :icon="kpi.icon" :color="kpi.color" size="22" class="mb-1" />
          <div class="text-h6 font-weight-bold" :class="kpi.valueClass">{{ kpi.value }}</div>
          <div class="text-caption text-medium-emphasis">{{ kpi.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════════════════════════════ MAIN TABS ═══════════════════════════════════════════ -->
    <v-card rounded="xl" elevation="0" class="cc-main mx-4 mx-md-6 mt-4">
      <v-tabs v-model="tab" color="teal" density="comfortable" show-arrows class="cc-tabs">
        <v-tab value="overview"><v-icon start icon="mdi-view-dashboard" size="18" />Overview</v-tab>
        <v-tab value="assessments"><v-icon start icon="mdi-clipboard-check" size="18" />Assessments</v-tab>
        <v-tab value="vitals"><v-icon start icon="mdi-heart-pulse" size="18" />Vitals & NEWS2</v-tab>
        <v-tab value="braden"><v-icon start icon="mdi-human" size="18" />Braden & Skin</v-tab>
        <v-tab value="clinical"><v-icon start icon="mdi-stethoscope" size="18" />Clinical</v-tab>
        <v-tab value="fluid"><v-icon start icon="mdi-water" size="18" />Fluid Balance</v-tab>
        <v-tab value="supplies"><v-icon start icon="mdi-package-variant" size="18" />Medical Supplies</v-tab>
        <v-tab value="equipment"><v-icon start icon="mdi-medical-bag" size="18" />Equipment & Drains</v-tab>
        <v-tab value="medications"><v-icon start icon="mdi-pill" size="18" />Medication Schedules</v-tab>
        <v-tab value="doses"><v-icon start icon="mdi-pill-multiple" size="18" />Doses</v-tab>
        <v-tab value="billing"><v-icon start icon="mdi-calculator-variant" size="18" />Billing</v-tab>
        <v-tab value="notes"><v-icon start icon="mdi-note-edit" size="18" />Notes</v-tab>
        <v-tab value="treatment-plan"><v-icon start icon="mdi-clipboard-text-outline" size="18" />Treatment Plan</v-tab>
        <v-tab value="documents"><v-icon start icon="mdi-file-document-multiple" size="18" />Documents</v-tab>
      </v-tabs>
      <v-divider />

      <!-- Loading overlay -->
      <v-overlay :model-value="pageLoading" contained class="align-center justify-center" persistent>
        <v-progress-circular indeterminate color="teal" size="48" />
        <span class="ml-3 text-teal">Loading patient data...</span>
      </v-overlay>

      <v-window v-model="tab">
        <!-- ═══════════════ OVERVIEW ═══════════════ -->
        <v-window-item value="overview">
          <v-row dense class="pa-4">
            <v-col cols="12" md="8">
              <!-- Nursing Worklist -->
              <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" color="teal">
                <div class="d-flex align-center mb-3">
                  <v-icon icon="mdi-clipboard-list" color="teal" class="mr-2" />
                  <span class="text-subtitle-1 font-weight-bold">Nursing Worklist</span>
                  <v-spacer />
                  <v-chip size="small" variant="tonal" color="teal">{{ worklistItems.length }} tasks</v-chip>
                </div>
                <div v-if="worklistItems.length" class="d-flex flex-column ga-2">
                  <div v-for="item in worklistItems" :key="item.id"
                       class="cc-worklist-item d-flex align-center ga-3 pa-3 rounded-lg"
                       :style="{ borderLeft: `4px solid ${item.color}` }">
                    <v-icon :icon="item.icon" :color="item.color" size="22" />
                    <div class="flex-grow-1">
                      <div class="font-weight-medium text-body-2">{{ item.title }}</div>
                      <div class="text-caption text-medium-emphasis">{{ item.detail }}</div>
                    </div>
                    <v-chip size="x-small" :color="item.statusColor" variant="tonal" label>{{ item.statusLabel }}</v-chip>
                    <v-btn v-if="item.action" size="x-small" :color="item.color" variant="tonal" class="text-none" @click="item.action">{{ item.actionLabel }}</v-btn>
                  </div>
                </div>
                <div v-else class="text-center py-4 text-medium-emphasis">
                  <v-icon icon="mdi-clipboard-check" size="36" class="mb-2" color="success" />
                  <div class="font-weight-medium">All caught up</div>
                  <div class="text-caption">No pending nursing tasks for this patient.</div>
                </div>
              </v-card>

              <!-- Latest Vitals Snapshot -->
              <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" color="blue">
                <div class="d-flex align-center mb-3">
                  <v-icon icon="mdi-heart-pulse" color="blue" class="mr-2" />
                  <span class="text-subtitle-1 font-weight-bold">Latest Vitals</span>
                  <v-spacer />
                  <span class="text-caption text-medium-emphasis">{{ lastVitalsTime }}</span>
                </div>
                <v-row dense v-if="latestVitals">
                  <v-col v-for="v in latestVitalsGrid" :key="v.label" cols="4" sm="3" md="2">
                    <div class="text-center pa-2 rounded-lg" :style="{ background: v.bg }">
                      <div class="text-caption text-medium-emphasis">{{ v.label }}</div>
                      <div class="text-body-2 font-weight-bold" :style="{ color: v.color }">{{ v.value }}</div>
                    </div>
                  </v-col>
                </v-row>
                <div v-else class="text-center py-3 text-medium-emphasis">
                  <v-icon icon="mdi-heart-pulse" size="28" class="mb-1" color="grey" />
                  <div class="text-caption">No vitals recorded yet. Click "Record Vitals" to add.</div>
                </div>
              </v-card>
            </v-col>

            <v-col cols="12" md="4">
              <!-- Alerts -->
              <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" :color="alertsPanelColor">
                <div class="d-flex align-center mb-2">
                  <v-icon icon="mdi-bell-alert" :color="alertsPanelColor" size="20" class="mr-2" />
                  <span class="text-subtitle-2 font-weight-bold">Clinical Alerts</span>
                  <v-spacer />
                  <v-chip size="x-small" :color="alertsPanelColor" variant="flat" class="font-weight-bold text-white">{{ activeAlerts.length }}</v-chip>
                </div>
                <div v-if="activeAlerts.length" class="d-flex flex-column ga-2">
                  <v-alert v-for="(a, i) in activeAlerts" :key="i" :type="a.type" variant="tonal"
                           density="compact" rounded="lg" class="text-caption" :icon="a.icon">
                    <strong>{{ a.title }}</strong><br />{{ a.detail }}
                  </v-alert>
                </div>
                <div v-else class="text-caption text-medium-emphasis text-center py-2">No active alerts</div>
              </v-card>

              <!-- Scores -->
              <v-card variant="tonal" rounded="xl" class="pa-4" color="purple">
                <div class="text-subtitle-2 font-weight-bold mb-2">
                  <v-icon icon="mdi-shield-check" color="purple" size="18" class="mr-1" /> Scores Snapshot
                </div>
                <div class="d-flex flex-column ga-2">
                  <div v-for="s in quickScores" :key="s.label" class="d-flex align-center pa-2 rounded-lg" :style="{ background: s.bg }">
                    <span class="text-caption font-weight-medium flex-grow-1">{{ s.label }}</span>
                    <span class="text-body-2 font-weight-bold" :class="'text-'+s.color">{{ s.value }}</span>
                    <span class="text-caption text-medium-emphasis ml-1">{{ s.unit }}</span>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- ═══════════════ ASSESSMENTS — WORKLIST ═══════════════ -->
        <v-window-item value="assessments">
          <div class="pa-4">
            <!-- Header -->
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <div class="d-flex align-center ga-3 flex-grow-1">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#0d9488,#0f766e);">
                  <v-icon icon="mdi-clipboard-check" size="18" />
                </div>
                <div>
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Assessment Worklist</h3>
                  <div class="text-caption text-medium-emphasis">Individual clinical components — track, complete, monitor</div>
                </div>
              </div>
              <v-btn color="teal" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                     prepend-icon="mdi-plus" @click="showAddAssessmentDialog = true">Add Assessment</v-btn>
            </div>

            <!-- Master-Detail Layout -->
            <div class="hc-assess-layout">
              <!-- ══ Left: Scrollable Worklist ══ -->
              <div class="hc-assess-list">
                <div class="hc-assess-list-scroll">
                  <div v-for="comp in assessmentWorklist" :key="comp.key"
                       class="hc-assess-item"
                       :class="{ 'hc-assess-item--active': selectedAssessment?.key === comp.key }"
                       @click="selectedAssessmentKey = comp.key">
                    <div class="hc-assess-item-accent" :style="{ background: statusHex(comp.statusColor) }" />
                    <v-avatar size="36" :color="comp.avatarBg" variant="tonal" rounded="lg" class="flex-shrink-0">
                      <v-icon :icon="comp.icon" :color="comp.avatarColor" size="20" />
                    </v-avatar>
                    <div class="flex-grow-1 min-w-0">
                      <div class="d-flex align-center justify-space-between ga-2">
                        <span class="font-weight-bold text-body-2 text-truncate">{{ comp.label }}</span>
                        <v-chip size="x-small" :color="comp.statusColor" variant="flat"
                                class="font-weight-bold text-white flex-shrink-0">
                          <v-icon start :icon="comp.statusIcon" size="10" />
                          {{ comp.statusLabel }}
                        </v-chip>
                      </div>
                      <div v-if="comp.progressPct != null || comp.scoreLine" class="d-flex align-center ga-2 mt-1">
                        <v-progress-linear v-if="comp.progressPct != null" :model-value="comp.progressPct"
                                           height="3" rounded :color="comp.progressColor" class="flex-grow-1" />
                        <span v-if="comp.scoreLine" class="text-caption font-weight-bold flex-shrink-0"
                              :style="{ color: comp.scoreColor }">{{ comp.scoreLine.split('—')[0].trim() }}</span>
                      </div>
                    </div>
                  </div>
                  <div v-if="!assessmentWorklist.length" class="text-center text-medium-emphasis pa-8">
                    <v-icon icon="mdi-clipboard-check-outline" size="42" class="mb-2" />
                    <div class="font-weight-medium">No assessments in worklist</div>
                    <div class="text-caption mt-1">Click "Add Assessment" to start tracking</div>
                  </div>
                </div>
                <!-- Legend -->
                <div class="hc-assess-legend">
                  <div class="d-flex align-center ga-3 flex-wrap text-caption">
                    <div class="d-flex align-center ga-1"><v-icon icon="mdi-circle" size="10" color="success" /> Done</div>
                    <div class="d-flex align-center ga-1"><v-icon icon="mdi-circle" size="10" color="warning" /> Due</div>
                    <div class="d-flex align-center ga-1"><v-icon icon="mdi-circle" size="10" color="error" /> Overdue</div>
                    <div class="d-flex align-center ga-1"><v-icon icon="mdi-circle" size="10" color="grey" /> Not started</div>
                  </div>
                </div>
              </div>

              <!-- ══ Right: Detail Panel ══ -->
              <div class="hc-assess-detail">
                <template v-if="selectedAssessment">
                  <!-- Detail Header -->
                  <div class="hc-detail-header" :style="{ background: selectedAssessment.bgColor }">
                    <div class="d-flex align-center ga-4 flex-wrap">
                      <v-avatar size="52" :color="selectedAssessment.avatarBg" variant="tonal" rounded="xl">
                        <v-icon :icon="selectedAssessment.icon" :color="selectedAssessment.avatarColor" size="28" />
                      </v-avatar>
                      <div class="flex-grow-1 min-w-0">
                        <div class="d-flex align-center ga-2 flex-wrap">
                          <h3 class="text-h6 font-weight-bold ma-0">{{ selectedAssessment.label }}</h3>
                          <v-chip size="small" :color="selectedAssessment.statusColor" variant="flat"
                                  class="font-weight-bold text-white">
                            <v-icon start :icon="selectedAssessment.statusIcon" size="14" />
                            {{ selectedAssessment.statusLabel }}
                          </v-chip>
                        </div>
                        <div class="text-caption text-medium-emphasis mt-1">{{ selectedAssessment.description }}</div>
                      </div>
                      <v-btn color="teal" variant="flat" rounded="lg" class="text-none font-weight-bold"
                             :prepend-icon="selectedAssessment.status === 'done' ? 'mdi-refresh' : 'mdi-play'"
                             @click="openRecordDialog(selectedAssessment.key)">
                        {{ selectedAssessment.status === 'done' ? 'Redo' : 'Do Now' }}
                      </v-btn>
                    </div>
                  </div>

                  <!-- Detail Body -->
                  <div class="pa-4">
                    <!-- Info Tiles -->
                    <v-row dense>
                      <v-col cols="6" sm="3">
                        <div class="hc-detail-tile">
                          <v-icon icon="mdi-clock-outline" size="18" color="teal" class="mb-1" />
                          <div class="text-caption text-medium-emphasis">Frequency</div>
                          <div class="font-weight-bold text-body-2">{{ selectedAssessment.frequency }}</div>
                        </div>
                      </v-col>
                      <v-col cols="6" sm="3">
                        <div class="hc-detail-tile">
                          <v-icon icon="mdi-history" size="18" color="blue-grey" class="mb-1" />
                          <div class="text-caption text-medium-emphasis">Last Done</div>
                          <div class="font-weight-bold text-body-2">{{ selectedAssessment.lastDone || 'Never' }}</div>
                        </div>
                      </v-col>
                      <v-col cols="6" sm="3">
                        <div class="hc-detail-tile">
                          <v-icon icon="mdi-calendar-arrow-right" size="18"
                                  :color="selectedAssessment.nextDue ? selectedAssessment.statusColor : 'grey'" class="mb-1" />
                          <div class="text-caption text-medium-emphasis">Next Due</div>
                          <div class="font-weight-bold text-body-2">{{ selectedAssessment.nextDue || '—' }}</div>
                        </div>
                      </v-col>
                      <v-col cols="6" sm="3">
                        <div class="hc-detail-tile">
                          <v-icon icon="mdi-chart-line" size="18" color="indigo" class="mb-1" />
                          <div class="text-caption text-medium-emphasis">Progress</div>
                          <div class="font-weight-bold text-body-2">{{ selectedAssessment.progressPct != null ? selectedAssessment.progressPct + '%' : '—' }}</div>
                        </div>
                      </v-col>
                    </v-row>

                    <!-- Progress Bar -->
                    <div v-if="selectedAssessment.progressPct != null" class="mt-3 mb-3">
                      <div class="d-flex justify-space-between text-caption mb-1">
                        <span class="text-medium-emphasis">Cycle Progress</span>
                        <span class="font-weight-bold" :style="{ color: selectedAssessment.progressColor }">{{ selectedAssessment.progressPct }}%</span>
                      </div>
                      <v-progress-linear :model-value="selectedAssessment.progressPct"
                                         height="8" rounded :color="selectedAssessment.progressColor" />
                    </div>

                    <!-- Current Score -->
                    <v-card v-if="selectedAssessment.scoreLine" variant="tonal" rounded="xl" class="pa-4 mb-3"
                            :style="{ background: selectedAssessment.scoreBg }">
                      <div class="d-flex align-center ga-3">
                        <v-icon icon="mdi-chart-bell-curve" size="24" :style="{ color: selectedAssessment.scoreColor }" />
                        <div class="flex-grow-1">
                          <div class="text-caption font-weight-medium">Current Score</div>
                          <div class="text-h5 font-weight-bold" :style="{ color: selectedAssessment.scoreColor }">{{ selectedAssessment.scoreLine }}</div>
                        </div>
                      </div>
                    </v-card>

                    <!-- Skin Care Alert -->
                    <v-alert v-if="selectedAssessment.key === 'skin_care' && skinCareActive"
                             type="error" variant="tonal" density="comfortable" rounded="xl"
                             class="mb-3" icon="mdi-alert-octagon">
                      Braden {{ latestBraden?.total || '—' }} — Bundle active q4h per protocol.
                    </v-alert>

                    <!-- Action Buttons -->
                    <div class="d-flex ga-2 mb-4">
                      <v-btn color="teal" variant="flat" rounded="lg" class="text-none font-weight-bold flex-grow-1"
                             :prepend-icon="selectedAssessment.status === 'done' ? 'mdi-refresh' : 'mdi-play'"
                             @click="openRecordDialog(selectedAssessment.key)">
                        {{ selectedAssessment.status === 'done' ? 'Redo Assessment' : 'Do Now' }}
                      </v-btn>
                      <v-btn variant="outlined" rounded="lg" class="text-none font-weight-medium"
                             prepend-icon="mdi-history" @click="openAssessmentHistory(selectedAssessment.key)">
                        View History
                      </v-btn>
                    </div>

                    <!-- Recent History -->
                    <div class="hc-detail-history">
                      <div class="d-flex align-center mb-3">
                        <v-icon icon="mdi-history" size="20" color="teal" class="mr-2" />
                        <span class="text-subtitle-2 font-weight-bold">Recent Records</span>
                        <v-chip v-if="selectedAssessmentHistory.length" size="x-small" color="teal" variant="tonal"
                                class="ml-2 font-weight-bold">{{ selectedAssessmentHistory.length }}</v-chip>
                        <v-spacer />
                        <v-btn v-if="selectedAssessmentHistory.length > 5" size="small" variant="text" class="text-none"
                               prepend-icon="mdi-arrow-expand-all" @click="openAssessmentHistory(selectedAssessment.key)">
                          All
                        </v-btn>
                      </div>
                      <div v-if="selectedAssessmentHistory.length" class="d-flex flex-column ga-2">
                        <div v-for="(entry, idx) in selectedAssessmentHistory.slice(0, 5)" :key="entry.id"
                             class="hc-history-entry" :class="{ 'hc-history-entry--latest': idx === 0 }">
                          <div class="d-flex align-start justify-space-between ga-2 flex-wrap">
                            <div class="flex-grow-1 min-w-0">
                              <div class="font-weight-bold text-body-2">{{ entry.resultText }}</div>
                              <div class="text-caption text-medium-emphasis mt-1">
                                {{ formatDateTime(entry.timestamp) }}
                                <span v-if="entry.staff && entry.staff !== '—'"> · {{ entry.staff }}</span>
                              </div>
                            </div>
                            <v-chip v-if="idx === 0" size="x-small" color="teal" variant="tonal" label class="flex-shrink-0">Latest</v-chip>
                          </div>
                          <div v-if="entry.metrics.length" class="d-flex flex-wrap ga-1 mt-2">
                            <v-chip v-for="metric in entry.metrics.slice(0, 5)" :key="`${entry.id}-${metric.label}`"
                                    size="x-small" variant="tonal" color="teal" label>
                              {{ metric.label }}: {{ metric.value }}
                            </v-chip>
                            <span v-if="entry.metrics.length > 5" class="text-caption text-medium-emphasis align-self-center">+{{ entry.metrics.length - 5 }} more</span>
                          </div>
                          <div v-if="entry.notes" class="text-caption text-medium-emphasis mt-2">{{ entry.notes }}</div>
                        </div>
                      </div>
                      <div v-else class="text-center text-medium-emphasis pa-6">
                        <v-icon icon="mdi-history" size="36" color="grey" class="mb-2" />
                        <div class="font-weight-medium text-body-2">No records yet</div>
                        <div class="text-caption mt-1">Completed assessments will appear here</div>
                      </div>
                    </div>
                  </div>
                </template>
                <!-- Empty state -->
                <div v-else class="d-flex align-center justify-center hc-assess-detail-empty">
                  <div class="text-center text-medium-emphasis">
                    <v-icon icon="mdi-clipboard-check-outline" size="56" class="mb-3" />
                    <div class="font-weight-medium text-body-1">Select an assessment</div>
                    <div class="text-caption mt-1">Choose a component from the worklist to view details</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </v-window-item>

        <!-- Add Assessment Dialog -->
        <v-dialog v-model="showAddAssessmentDialog" max-width="680">
          <v-card rounded="xl">
            <v-card-title class="d-flex align-center">
              <v-icon icon="mdi-plus-circle" color="teal" class="mr-2" />
              Add Assessment Component
            </v-card-title>
            <v-card-text>
              <div class="text-caption text-medium-emphasis mb-3">Select individual clinical components to add to the assessment worklist.</div>
              <v-row dense>
                <v-col v-for="atype in ASSESSMENT_TYPES" :key="atype.key" cols="6" md="4">
                  <v-card variant="tonal" rounded="lg" class="pa-3 text-center cc-assess-add-card"
                    :color="atype.color" @click="openAddSingleCard(atype.key)"
                    style="cursor:pointer; transition: all .2s">
                    <v-icon :icon="atype.icon" :color="atype.avatarColor" size="24" class="mb-2" />
                    <div class="font-weight-medium text-body-2">{{ atype.label }}</div>
                    <div class="text-caption text-medium-emphasis">{{ atype.description }}</div>
                    <v-chip size="x-small" variant="tonal" :color="atype.color" class="mt-1">{{ atype.frequency }}</v-chip>
                  </v-card>
                </v-col>
              </v-row>
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn variant="text" @click="showAddAssessmentDialog = false">Done</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <!-- Single Assessment Config Dialog -->
        <v-dialog v-model="showAddSingleDialog" max-width="480">
          <v-card rounded="xl">
            <v-card-title class="d-flex align-center" v-if="addSingleTypeDef">
              <v-icon :icon="addSingleTypeDef.icon" :color="addSingleTypeDef.avatarColor" class="mr-2" />
              {{ addSingleTypeDef.label }}
            </v-card-title>
            <v-card-text>
              <div class="text-caption text-medium-emphasis mb-3">{{ addSingleTypeDef?.description }}</div>
              <v-text-field v-model="addSingleStartTime" type="datetime-local" label="Start time"
                variant="outlined" density="comfortable" class="mb-3" />
              <div class="text-caption font-weight-medium mb-2">Frequency</div>
              <div v-if="addSingleTypeDef?.freqOptions" class="d-flex flex-wrap ga-2 mb-3">
                <v-chip v-for="opt in addSingleTypeDef.freqOptions" :key="opt"
                  size="small" variant="tonal" :color="addSingleFrequency === opt ? 'teal' : 'grey'"
                  @click="addSingleFrequency = opt; addSingleCustomFreq = ''" class="cursor-pointer">
                  {{ opt }}
                </v-chip>
                <v-chip v-if="addSingleCustomFreq" size="small" variant="flat" color="teal">
                  {{ addSingleCustomFreq }}
                  <v-btn size="x-small" icon="mdi-close" variant="text" density="compact" @click="addSingleCustomFreq=''" />
                </v-chip>
              </div>
              <v-text-field v-model="addSingleCustomFreq" label="Custom frequency"
                placeholder="e.g. Every 3 hrs, Every 2 days" variant="outlined" density="comfortable" persistent-hint
                hint="Type a custom schedule" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn variant="text" @click="showAddSingleDialog = false">Cancel</v-btn>
              <v-btn color="teal" variant="flat" @click="confirmAddSingle">Add to Worklist</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <!-- Record Assessment Entry Dialog -->
        <v-dialog v-model="showRecordDialog" max-width="960" scrollable eager>
          <v-card rounded="xl">
            <v-card-title class="d-flex align-center" v-if="recordTypeKey">
              <v-icon :icon="ASSESSMENT_TYPES.find(t=>t.key===recordTypeKey)?.icon || 'mdi-clipboard-check'" color="teal" class="mr-2" />
              Record: {{ ASSESSMENT_TYPES.find(t=>t.key===recordTypeKey)?.label || '' }}
            </v-card-title>
            <v-card-text>
              <div class="text-caption text-medium-emphasis mb-3">{{ ASSESSMENT_TYPES.find(t=>t.key===recordTypeKey)?.description || '' }}</div>

              <!-- BRADEN SCALE -->
              <template v-if="recordTypeKey==='braden'">
                <v-row dense>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_sensory" :items="bradenFieldOptions('sensory')" label="Sensory Perception" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_moisture" :items="bradenFieldOptions('moisture')" label="Moisture" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_activity" :items="bradenFieldOptions('activity')" label="Activity" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_mobility" :items="bradenFieldOptions('mobility')" label="Mobility" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_nutrition" :items="bradenFieldOptions('nutrition')" label="Nutrition" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model.number="recordForm.braden_friction" :items="bradenFieldOptions('friction')" label="Friction & Shear" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-sheet rounded="lg" color="warning-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">Braden Total</span>
                    <span class="text-h6 font-weight-bold">{{ bradenFormTotal }}</span>
                  </div>
                </v-sheet>
              </template>

              <!-- MUST -->
              <template v-else-if="recordTypeKey==='must'">
                <v-row dense>
                  <v-col cols="6"><v-text-field v-model.number="recordForm.must_height" type="number" label="Height (cm)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-model.number="recordForm.must_weight" type="number" label="Weight (kg)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-sheet v-if="recordForm.must_height && recordForm.must_weight" rounded="lg" color="blue-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">BMI</span>
                    <span class="text-h6 font-weight-bold">{{ mustFormBMI }}</span>
                  </div>
                  <div class="text-caption">Score: {{ mustFormBMIScore > 0 ? mustFormBMIScore : '0' }} pt</div>
                </v-sheet>
                <v-select v-model.number="recordForm.must_loss_score" :items="mustLossOptions" label="Unplanned Weight Loss" variant="outlined" density="comfortable" class="mb-2" />
                <v-checkbox v-model="recordForm.must_acute_none" label="Acutely ill / No nutritional intake >5 days" color="teal" density="compact" class="mb-2" />
                <v-sheet rounded="lg" color="teal-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">MUST Total</span>
                    <span class="text-h6 font-weight-bold">{{ mustFormTotal }} / 6</span>
                  </div>
                </v-sheet>
              </template>

              <!-- MORSE FALL SCALE -->
              <template v-else-if="recordTypeKey==='morse'">
                <v-checkbox v-model="recordForm.morse_history_falls" label="History of falling" color="warning" density="compact" class="mb-1" />
                <v-checkbox v-model="recordForm.morse_secondary_dx" label="Secondary diagnosis" color="warning" density="compact" class="mb-1" />
                <v-select v-model="recordForm.morse_ambulatory_aid" :items="morseAidOptions" label="Ambulatory aid" variant="outlined" density="comfortable" class="mb-2" />
                <v-checkbox v-model="recordForm.morse_iv_lock" label="IV / Heparin lock" color="warning" density="compact" class="mb-1" />
                <v-select v-model="recordForm.morse_gait" :items="morseGaitOptions" label="Gait / Transferring" variant="outlined" density="comfortable" class="mb-2" />
                <v-select v-model="recordForm.morse_mental_status" :items="morseMentalOptions" label="Mental status" variant="outlined" density="comfortable" class="mb-2" />
                <v-sheet rounded="lg" color="orange-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">Morse Fall Score</span>
                    <span class="text-h6 font-weight-bold">{{ morseFormTotal }} / 125</span>
                  </div>
                </v-sheet>
              </template>

              <!-- GCS -->
              <template v-else-if="recordTypeKey==='gcs'">
                <v-row dense>
                  <v-col cols="4"><v-select v-model.number="recordForm.gcs_eyes" :items="gcsEyeOptions" label="Eye Opening" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="4"><v-select v-model.number="recordForm.gcs_verbal" :items="gcsVerbalOptions" label="Verbal" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="4"><v-select v-model.number="recordForm.gcs_motor" :items="gcsMotorOptions" label="Motor" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-sheet rounded="lg" color="indigo-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">GCS Total</span>
                    <span class="text-h6 font-weight-bold">{{ gcsFormTotal }} / 15</span>
                  </div>
                </v-sheet>
              </template>

              <!-- CAPRINI -->
              <v-text-field v-else-if="recordTypeKey==='caprini'" v-model.number="recordForm.caprini_points" type="number" min="0" max="20" label="Caprini Points" variant="outlined" density="comfortable" class="mb-2" />

              <!-- ═══ PAIN ASSESSMENT (COMPREHENSIVE) ═══ -->
              <template v-else-if="recordTypeKey==='pain_reassess'">
                <!-- Tool Selection -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">Assessment Tool</div>
                <v-select v-model="painForm.tool_type" :items="painToolOptions" variant="outlined" density="comfortable" class="mb-4" hide-details />
                <v-divider class="mb-4" />

                <!-- NRS Slider -->
                <template v-if="painForm.tool_type === 'nrs'">
                  <div class="d-flex align-center justify-space-between mb-1">
                    <span class="text-body-2 text-grey-darken-1">Pain Score</span>
                    <v-chip :color="painScoreChipColor" variant="flat" size="small" class="font-weight-bold text-white">{{ painForm.score ?? '—' }} / 10</v-chip>
                  </div>
                  <v-slider v-model="painForm.score" :min="0" :max="10" :step="1" :color="painScoreSliderColor" track-size="8" thumb-size="28" show-ticks="always" tick-size="4" class="mb-4">
                    <template v-slot:prepend><span class="text-caption font-weight-medium">0</span></template>
                    <template v-slot:append><span class="text-caption font-weight-medium">10</span></template>
                  </v-slider>
                  <div class="d-flex justify-space-between mb-4">
                    <div v-for="lvl in painNrsLevels" :key="lvl.label" class="text-center" :style="{ flex:'1' }">
                      <v-icon :color="lvl.color" size="18">{{ lvl.icon }}</v-icon>
                      <div class="text-caption font-weight-medium" :style="{ color: lvl.color }">{{ lvl.label }}</div>
                      <div class="text-caption text-grey-darken-1">{{ lvl.range }}</div>
                    </div>
                  </div>
                  <v-row dense>
                    <v-col cols="6"><v-text-field v-model.number="painForm.worst_pain_24h" type="number" min="0" max="10" label="Worst (24h)" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="painForm.least_pain_24h" type="number" min="0" max="10" label="Least (24h)" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="painForm.average_pain" type="number" min="0" max="10" label="Average" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="painForm.acceptable_pain_goal" type="number" min="0" max="10" label="Acceptable Goal" variant="outlined" density="comfortable" /></v-col>
                  </v-row>
                </template>

                <!-- VAS -->
                <template v-if="painForm.tool_type === 'vas'">
                  <div class="text-body-2 mb-1">
                    <span class="text-grey-darken-1">Visual Analog Scale — mark the position</span>
                    <v-chip size="x-small" :color="painScoreSliderColor" variant="tonal" class="ml-2">{{ painForm.vas_mm ?? 0 }} mm</v-chip>
                  </div>
                  <v-slider v-model="painForm.vas_mm" :min="0" :max="100" :step="1" color="#8b5cf6" track-size="6" thumb-size="20" class="mb-4">
                    <template v-slot:prepend><span class="text-caption">No Pain</span></template>
                    <template v-slot:append><span class="text-caption">Worst Imaginable</span></template>
                  </v-slider>
                  <div class="text-caption text-right text-grey-darken-1 mb-4">Score: {{ Math.round((painForm.vas_mm || 0) / 10) }} / 10</div>
                </template>

                <!-- FACES -->
                <template v-if="painForm.tool_type === 'faces'">
                  <v-row dense class="mb-4">
                    <v-col v-for="face in painFacesOptions" :key="face.value" cols="2" class="text-center">
                      <v-sheet :rounded="'xl'" :color="painForm.faces_choice === face.value ? 'amber-lighten-3' : 'grey-lighten-4'" class="pa-2 cursor-pointer" @click="painForm.faces_choice = face.value" style="transition:all .2s">
                        <div style="font-size:28px">{{ face.emoji }}</div>
                        <div class="text-caption font-weight-bold">{{ face.value }}</div>
                        <div class="text-caption text-grey-darken-1" style="font-size:10px">{{ face.label }}</div>
                      </v-sheet>
                    </v-col>
                  </v-row>
                  <v-text-field v-model="painForm.faces_description" label="Child's verbal description (if applicable)" variant="outlined" density="comfortable" class="mb-2" />
                </template>

                <!-- FLACC -->
                <template v-if="painForm.tool_type === 'flacc'">
                  <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">FLACC Score: {{ flaccTotal }} / 10</div>
                  <v-row dense>
                    <v-col cols="12"><v-select v-model="painForm.flacc_face" :items="flaccItems('Face')" label="Face" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.flacc_legs" :items="flaccItems('Legs')" label="Legs" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.flacc_activity" :items="flaccItems('Activity')" label="Activity" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.flacc_cry" :items="flaccItems('Cry')" label="Cry" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.flacc_consolability" :items="flaccItems('Consolability')" label="Consolability" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>
                </template>

                <!-- PAINAD -->
                <template v-if="painForm.tool_type === 'painad'">
                  <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">PAINAD Score: {{ painadTotal }} / 10</div>
                  <v-row dense>
                    <v-col cols="12"><v-select v-model="painForm.painad_breathing" :items="painadItems('Breathing')" label="Breathing" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.painad_negative_vocal" :items="painadItems('Vocalisation')" label="Negative Vocalisation" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.painad_facial" :items="painadItems('Facial')" label="Facial Expression" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.painad_body_language" :items="painadItems('Body Language')" label="Body Language" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12"><v-select v-model="painForm.painad_consolability" :items="painadItems('Consolability')" label="Consolability" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>
                </template>
                <v-divider class="mb-4" />

                <!-- PQRST Framework -->
                <v-expansion-panels v-model="painPqrstPanel" variant="accordion" class="mb-4">
                  <v-expansion-panel value="pqrst" elevation="0" border>
                    <v-expansion-panel-title class="font-weight-bold text-body-2">
                      <v-icon size="20" class="mr-2" color="#d97706">mdi-magnify</v-icon> PQRST Framework (detailed)
                    </v-expansion-panel-title>
                    <v-expansion-panel-text class="pt-2">
                      <v-row dense>
                        <!-- P - Provocation / Palliation -->
                        <v-col cols="12" md="6">
                          <div class="text-caption font-weight-bold mb-1">P — What makes pain worse?</div>
                          <v-select v-model="painForm.provocation_factors" :items="painProvocationOptions" multiple chips variant="outlined" density="comfortable" class="mb-3" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <div class="text-caption font-weight-bold mb-1">P — What relieves pain?</div>
                          <v-select v-model="painForm.palliation_factors" :items="painPalliationOptions" multiple chips variant="outlined" density="comfortable" class="mb-3" />
                        </v-col>
                        <!-- Q - Quality -->
                        <v-col cols="12">
                          <div class="text-caption font-weight-bold mb-1">Q — Pain quality</div>
                          <v-select v-model="painForm.quality_descriptors" :items="painQualityOptions" multiple chips variant="outlined" density="comfortable" class="mb-2" />
                          <v-text-field v-model="painForm.quality_other" label="Other quality descriptor" variant="outlined" density="comfortable" class="mb-3" />
                        </v-col>
                        <!-- R - Region / Radiation -->
                        <v-col cols="12" md="6">
                          <div class="text-caption font-weight-bold mb-1">R — Pain locations</div>
                          <v-select v-model="painForm.pain_locations" :items="painBodyRegions" multiple chips variant="outlined" density="comfortable" class="mb-2" />
                          <v-switch v-model="painForm.has_radiation" label="Pain radiates?" color="warning" density="compact" hide-details class="mb-1" />
                          <v-textarea v-if="painForm.has_radiation" v-model="painForm.radiation_pathway" label="Radiation pathway" variant="outlined" density="comfortable" rows="2" class="mb-3" />
                        </v-col>
                        <!-- S - Severity (auto) + T - Timing -->
                        <v-col cols="12" md="6">
                          <div class="text-caption font-weight-bold mb-1">T — Timing</div>
                          <v-row dense>
                            <v-col cols="6"><v-select v-model="painForm.onset_type" :items="['sudden','gradual']" label="Onset" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                            <v-col cols="6"><v-select v-model="painForm.pain_pattern" :items="['constant','intermittent']" label="Pattern" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                            <v-col cols="6"><v-text-field v-model="painForm.pain_duration" label="Duration" placeholder="e.g. 30 min" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                            <v-col cols="6"><v-text-field v-model="painForm.pain_frequency" label="Frequency" placeholder="e.g. 3×/day" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                          </v-row>
                        </v-col>
                      </v-row>
                    </v-expansion-panel-text>
                  </v-expansion-panel>
                </v-expansion-panels>

                <!-- Functional Impact -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">Functional Impact</div>
                <v-row dense>
                  <v-col cols="6"><v-switch v-model="painForm.impact_sleep" label="Sleep" color="orange" density="compact" hide-details class="mb-2" /></v-col>
                  <v-col cols="6"><v-switch v-model="painForm.impact_adl" label="ADLs" color="orange" density="compact" hide-details class="mb-2" /></v-col>
                  <v-col cols="6"><v-switch v-model="painForm.impact_mood" label="Mood" color="orange" density="compact" hide-details class="mb-2" /></v-col>
                  <v-col cols="6"><v-switch v-model="painForm.impact_appetite" label="Appetite" color="orange" density="compact" hide-details class="mb-2" /></v-col>
                </v-row>
                <v-text-field v-model="painForm.impact_other" label="Other functional impact" variant="outlined" density="comfortable" class="mb-4" />

                <!-- Treatment Response -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">Treatment Response</div>
                <v-row dense>
                  <v-col cols="6"><v-text-field v-model.number="painForm.pre_treatment_score" type="number" min="0" max="10" label="Pre-treatment Score" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-model.number="painForm.post_treatment_score" type="number" min="0" max="10" label="Post-treatment Score" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-textarea v-model="painForm.treatment_given" label="Treatment / Intervention" placeholder="e.g. Paracetamol 1g PO, repositioning, ice pack" variant="outlined" density="comfortable" rows="2" class="mb-2" />
              </template>

              <!-- DIABETES BUNDLE -->
              <template v-else-if="recordTypeKey==='diabetes_bundle'">
                <v-row dense>
                  <v-col cols="6"><v-text-field v-model.number="recordForm.db_glucose" type="number" label="Blood Glucose (mmol/L)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-model.number="recordForm.db_ketones" type="number" label="Ketones (mmol/L)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
              </template>

              <!-- HEART FAILURE BUNDLE -->
              <template v-else-if="recordTypeKey==='hf_bundle'">
                <v-row dense>
                  <v-col cols="4"><v-text-field v-model.number="recordForm.hf_weight" type="number" label="Weight (kg)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="4"><v-text-field v-model.number="recordForm.hf_fluid_balance" type="number" label="Fluid Balance (ml)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="4"><v-text-field v-model.number="recordForm.hf_spo2" type="number" label="SpO₂ (%)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
              </template>

              <!-- ═══ PIVC ASSESSMENT (VIP Score 0–5) ═══ -->
              <template v-else-if="recordTypeKey==='pivc'">
                <div class="d-flex align-center ga-2 mb-3 flex-wrap">
                  <v-icon color="cyan-darken-1" size="20">mdi-needle</v-icon>
                  <span class="text-body-2 font-weight-bold text-cyan-darken-1">PIVC Clinical Assessment</span>
                  <v-spacer />
                  <v-chip v-if="previousVipScoreAuto != null" size="x-small" variant="tonal" color="cyan" label>Previous VIP: {{ previousVipScoreAuto }}/5</v-chip>
                </div>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.assessment_type" :items="pivcAssessmentTypeOptions" label="Assessment Type" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-combobox v-model="pivcForm.catheter_id" :items="pivcDeviceOptions" label="Catheter ID" variant="outlined" density="comfortable" clearable class="mb-2" hint="Select from Device Register or type manually" persistent-hint /></v-col>
                  <v-col cols="6" sm="4"><v-combobox v-model="pivcForm.current_infusion" :items="pivcInfusionOptions" label="Current Infusion" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="pivcForm.catheter_site" :items="pivcSiteOptions" label="Site" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="pivcForm.vein" :items="pivcVeinOptions" label="Vein" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="pivcForm.gauge" :items="pivcGaugeOptions" label="Gauge" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.insertion_date" type="datetime-local" label="Date Inserted" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model.number="pivcForm.previous_vip_score" type="number" min="0" max="5" label="Previous VIP Score" variant="outlined" density="comfortable" class="mb-2" :suffix="previousVipScoreAuto != null ? 'auto' : ''" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.last_flush" type="datetime-local" label="Last Flush" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.last_dressing_change" type="datetime-local" label="Last Dressing Change" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-divider class="mb-4" />

                <!-- Clinical Assessment -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0891b2">Clinical Assessment</div>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.pain_level" :items="pivcPainOptions" label="Pain" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model.number="pivcForm.pain_score_nrs" type="number" min="0" max="10" label="Pain Score (0–10)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.pain_quality" label="Pain Quality" placeholder="e.g. burning, throbbing" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.pain_onset" label="Pain Onset" placeholder="e.g. sudden, gradual" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.pain_duration" label="Pain Duration" placeholder="e.g. 2 hrs" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model.number="pivcForm.swelling_circumference_cm" type="number" step="0.1" label="Swelling Circumference (cm)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.erythema" :items="pivcErythemaOptions" label="Erythema (Redness)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.swelling" :items="pivcSwellingOptions" label="Swelling" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.warmth" :items="pivcWarmthOptions" label="Warmth" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.induration" :items="pivcIndurationOptions" label="Induration" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.palpable_cord" :items="pivcCordOptions" label="Palpable Venous Cord" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.drainage_type" :items="pivcDrainageOptions" label="Drainage Type" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.drainage_quantity" label="Drainage Quantity" placeholder="e.g. moderate" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.skin_integrity" :items="pivcSkinIntegrityOptions" label="Skin Integrity" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.leakage" :items="pivcLeakageOptions" label="Leakage" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.catheter_patency" :items="pivcPatencyOptions" label="Catheter Patency" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-select v-model="pivcForm.blood_return" :items="pivcBloodReturnOptions" label="Blood Return" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>

                <v-sheet v-if="pivcVipPreview != null" rounded="lg" :color="pivcVipPreviewColor" class="pa-3 my-2">
                  <div class="d-flex justify-space-between align-center">
                    <span class="font-weight-bold text-white">VIP Score: {{ pivcVipPreview }} — {{ pivcVipPreviewLabel }}</span>
                    <v-chip size="small" variant="flat" color="white" class="text-uppercase font-weight-bold" :style="{ color: pivcVipPreviewHex }">{{ pivcVipPreviewColour }}</v-chip>
                  </div>
                </v-sheet>

                <v-divider class="mb-4" />

                <!-- Limb Assessment -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0891b2">Limb Assessment</div>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.limb_colour" label="Colour" placeholder="e.g. pink, pale, cyanotic" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.limb_temperature" label="Temperature" placeholder="e.g. warm, cool" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.capillary_refill" label="Capillary Refill" placeholder="e.g. <2 sec" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.distal_pulses" label="Distal Pulses" placeholder="e.g. radial — strong" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.limb_sensation" label="Sensation" placeholder="e.g. intact, altered" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6" sm="4"><v-text-field v-model="pivcForm.limb_movement" label="Movement" placeholder="e.g. full ROM" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>

                <v-divider class="mb-4" />

                <!-- Maintenance Bundle -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0891b2">Maintenance Bundle</div>

                <!-- Hand Hygiene -->
                <div class="text-caption font-weight-bold mb-1">Hand Hygiene</div>
                <v-row dense class="mb-2">
                  <v-col cols="12" sm="6"><v-select v-model="pivcForm.bundle_hand_hygiene_before" :items="pivcResponseOptions" label="Performed before catheter contact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="pivcForm.bundle_hand_hygiene_after" :items="pivcResponseOptions" label="Performed after procedure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- PPE -->
                <div class="text-caption font-weight-bold mb-1">Personal Protective Equipment</div>
                <v-row dense class="mb-2">
                  <v-col cols="12" sm="6"><v-select v-model="pivcForm.bundle_gloves" :items="pivcResponseOptions" label="Gloves worn" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="pivcForm.bundle_additional_ppe" :items="pivcResponseOptions" label="Additional PPE if indicated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- ANTT -->
                <div class="text-caption font-weight-bold mb-1">Aseptic Non-Touch Technique (ANTT)</div>
                <v-row dense class="mb-2">
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_antt_key_parts" :items="pivcResponseOptions" label="Key parts protected" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_antt_sterile" :items="pivcResponseOptions" label="Sterile equipment used" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_antt_aseptic" :items="pivcResponseOptions" label="Aseptic technique maintained" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Catheter Necessity -->
                <div class="text-caption font-weight-bold mb-1">Catheter Necessity</div>
                <v-row dense class="mb-2">
                  <v-col cols="12"><v-select v-model="pivcForm.bundle_catheter_necessary" :items="pivcResponseOptions" label="Catheter still clinically indicated?" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Dressing Assessment -->
                <div class="text-caption font-weight-bold mb-1">Dressing Assessment</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_clean" :items="pivcResponseOptions" label="Clean" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_dry" :items="pivcResponseOptions" label="Dry" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_intact" :items="pivcResponseOptions" label="Intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_transparent" :items="pivcResponseOptions" label="Transparent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_label" :items="pivcResponseOptions" label="Label present" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_date_visible" :items="pivcResponseOptions" label="Date visible" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_time_visible" :items="pivcResponseOptions" label="Time visible" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_edges_secure" :items="pivcResponseOptions" label="Edges secure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_no_blood" :items="pivcResponseOptions" label="No blood" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_dressing_no_moisture" :items="pivcResponseOptions" label="No moisture" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Catheter Securement -->
                <div class="text-caption font-weight-bold mb-1">Catheter Securement</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_securement" :items="pivcResponseOptions" label="Secure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_stabilization_intact" :items="pivcResponseOptions" label="Stabilization device intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_supported" :items="pivcResponseOptions" label="Tubing supported" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_no_tension" :items="pivcResponseOptions" label="No tension" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Site Assessment -->
                <div class="text-caption font-weight-bold mb-1">Site Assessment</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_site_no_redness" :items="pivcResponseOptions" label="No redness" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_site_no_swelling" :items="pivcResponseOptions" label="No swelling" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_site_no_pain" :items="pivcResponseOptions" label="No pain" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_site_no_warmth" :items="pivcResponseOptions" label="No warmth" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_site_no_discharge" :items="pivcResponseOptions" label="No discharge" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_vip_completed" :items="pivcResponseOptions" label="VIP assessment completed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Hub and Port Disinfection -->
                <div class="text-caption font-weight-bold mb-1">Hub & Port Disinfection</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_hub_scrubbed" :items="pivcResponseOptions" label="Hub scrubbed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_hub_antiseptic" :items="pivcResponseOptions" label="Correct antiseptic" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_hub_contact_time" :items="pivcResponseOptions" label="Contact time achieved" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_hub_dried" :items="pivcResponseOptions" label="Allowed to dry" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Flushing Practice -->
                <div class="text-caption font-weight-bold mb-1">Flushing Practice</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_syringe" :items="pivcResponseOptions" label="Correct syringe" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_solution" :items="pivcResponseOptions" label="Correct solution" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_before" :items="pivcResponseOptions" label="Flush before medication" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_after" :items="pivcResponseOptions" label="Flush after medication" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_push_pause" :items="pivcResponseOptions" label="Push-pause technique" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="2"><v-select v-model="pivcForm.bundle_flush_positive_pressure" :items="pivcResponseOptions" label="Positive pressure lock" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Medication Administration -->
                <div class="text-caption font-weight-bold mb-1">Medication Administration</div>
                <v-row dense class="mb-2">
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_med_five_rights" :items="pivcResponseOptions" label="Five Rights completed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_med_compatibility" :items="pivcResponseOptions" label="Compatibility checked" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="4"><v-select v-model="pivcForm.bundle_med_flush_between" :items="pivcResponseOptions" label="Flush between incompatible meds" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Administration Set -->
                <div class="text-caption font-weight-bold mb-1">Administration Set</div>
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_dated" :items="pivcResponseOptions" label="Tubing dated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_interval" :items="pivcResponseOptions" label="Within replacement interval" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_secure" :items="pivcResponseOptions" label="Connections secure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_no_air" :items="pivcResponseOptions" label="No air" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="6" sm="4" md="3"><v-select v-model="pivcForm.bundle_tubing_no_kinks" :items="pivcResponseOptions" label="No kinks" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>

                <!-- Bundle compliance preview -->
                <v-sheet v-if="pivcBundleCompliancePct != null" rounded="lg" :color="pivcBundleComplianceColor" class="pa-3 my-2">
                  <div class="d-flex justify-space-between align-center">
                    <span class="font-weight-bold text-white">Bundle Compliance: {{ pivcBundleCompliancePct }}%</span>
                  </div>
                </v-sheet>

                <v-divider class="my-3" />

                <!-- Catheter Removal -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b91c1c">Catheter Removal</div>
                <v-row dense>
                  <v-col cols="12"><v-switch v-model="pivcForm.catheter_removed" label="Catheter Removed" color="red" density="compact" hide-details class="mb-2" /></v-col>
                  <v-col v-if="pivcForm.catheter_removed" cols="12"><v-text-field v-model="pivcForm.removal_reason" label="Removal Reason" placeholder="e.g. Phlebitis, therapy complete, dislodged" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
              </template>

              <!-- ═══ ENTERAL FEEDING ASSESSMENT ═══ -->
              <template v-else-if="recordTypeKey==='enteral_feeding'">
                <div class="d-flex align-center ga-2 mb-3 flex-wrap">
                  <v-icon color="amber-darken-2" size="20">mdi-food-tube</v-icon>
                  <span class="text-body-2 font-weight-bold text-amber-darken-2">Enteral Access Device Maintenance</span>
                </div>
                <v-row dense>
                  <v-col cols="6"><v-select v-model="enteralForm.device_type" :items="enteralDeviceTypeOptions" label="Device Type" variant="outlined" density="comfortable" class="mb-2" hint="Auto-detected from Device Register" persistent-hint /></v-col>
                  <v-col cols="6"><v-combobox v-model="enteralForm.tube_size" :items="enteralTubeSizeOptions" label="Tube Size" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="6"><v-combobox v-model="enteralForm.insertion_site" :items="enteralSiteOptions" label="Insertion Site" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="6"><v-combobox v-model="enteralForm.external_length_cm" :items="enteralLengthOptions" label="External Length (cm)" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="6"><v-switch v-model="enteralForm.device_removed" label="Device Removed" color="red" density="compact" hide-details class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-if="enteralForm.device_removed" v-model="enteralForm.removal_reason" label="Removal Reason" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>
                <v-divider class="mb-3" />
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#b45309">Maintenance Bundle</div>
                <v-row dense>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_hand_hygiene" :items="enteralResponseOptions" label="Hand Hygiene" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_ppe" :items="enteralResponseOptions" label="PPE" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_device_necessity" :items="enteralResponseOptions" label="Daily Device Necessity Review" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_device_securement" :items="enteralResponseOptions" label="Device Securement" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_tube_patency" :items="enteralResponseOptions" label="Tube Patency" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_water_flush_protocol" :items="enteralResponseOptions" label="Water Flush Protocol" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_feeding_equipment_check" :items="enteralResponseOptions" label="Feeding Equipment Check" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_patient_positioning" :items="enteralResponseOptions" label="Patient Positioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_oral_care" :items="enteralResponseOptions" label="Oral Care" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_documentation_complete" :items="enteralResponseOptions" label="Documentation Complete" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <!-- NGT/OGT/NJ specific -->
                  <v-col v-if="isEnteralNasalDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_position_verification" :items="enteralResponseOptions" label="Position Verification" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralNasalDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_nare_care" :items="enteralResponseOptions" label="Nare Care" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralNasalDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_skin_protection" :items="enteralResponseOptions" label="Skin Protection" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralNasalDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_nasal_pressure_prevention" :items="enteralResponseOptions" label="Nasal Pressure Injury Prevention" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <!-- PEG/PEJ/GJ/J-Tube specific -->
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_stoma_care" :items="enteralResponseOptions" label="Stoma Care" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_external_fixation_check" :items="enteralResponseOptions" label="External Fixation Check" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_external_length_verify" :items="enteralResponseOptions" label="External Length Verification" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_tube_rotation" :items="enteralResponseOptions" label="Tube Rotation (per policy)" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_dressing_management" :items="enteralResponseOptions" label="Dressing Management" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_buried_bumper" :items="enteralResponseOptions" label="Buried Bumper Prevention" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col v-if="isEnteralStomaDevice" cols="12" sm="6"><v-select v-model="enteralForm.bundle_peristomal_care" :items="enteralResponseOptions" label="Peristomal Care" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_med_safety_check" :items="enteralResponseOptions" label="Medication Safety Check" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="enteralForm.bundle_patient_education" :items="enteralResponseOptions" label="Patient/Caregiver Education" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>
                <v-sheet v-if="enteralCompliancePct != null" rounded="lg" :color="enteralComplianceColor" class="pa-3 my-2">
                  <div class="d-flex justify-space-between align-center">
                    <span class="font-weight-bold text-white">Bundle Compliance: {{ enteralCompliancePct }}%</span>
                  </div>
                </v-sheet>
              </template>

              <!-- ═══ URINARY CATHETER MAINTENANCE BUNDLE ═══ -->
              <template v-else-if="recordTypeKey==='urinary_catheter'">
                <div class="d-flex align-center ga-2 mb-3 flex-wrap">
                  <v-icon color="teal-darken-1" size="20">mdi-water-pipe</v-icon>
                  <span class="text-body-2 font-weight-bold text-teal-darken-1">Urinary Catheter Maintenance</span>
                </div>
                <v-row dense>
                  <v-col cols="6"><v-select v-model="ucForm.catheter_type" :items="ucCatheterTypeOptions" label="Catheter Type" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model="ucForm.assessment_type" :items="ucAssessmentTypeOptions" label="Assessment Type" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="ucForm.catheter_day" :items="ucDayOptions" label="Catheter Day" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="ucForm.catheter_size_fr" :items="ucSizeOptions" label="Size (Fr)" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="4"><v-combobox v-model="ucForm.balloon_volume_ml" :items="ucBalloonOptions" label="Balloon (mL)" variant="outlined" density="comfortable" clearable class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-model="ucForm.current_indication" label="Current Indication" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-switch v-model="ucForm.catheter_indicated" label="Catheter Still Indicated?" color="teal" density="compact" hide-details class="mb-2" /></v-col>
                </v-row>
                <v-divider class="mb-3" />

                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0f766e">Catheter & Site Assessment</div>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.catheter_secure" label="Secure" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.correct_position" label="Correct Position" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.no_traction" label="No Traction" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.no_leakage" label="No Leakage" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.no_obstruction" label="No Obstruction" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.tubing_patent" label="Tubing Patent" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.no_dependent_loops" label="No Dependent Loops" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.bag_below_bladder" label="Bag Below Bladder" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.closed_system_maintained" label="Closed System" color="teal" density="compact" hide-details class="mb-1" /></v-col>
                </v-row>
                <v-divider class="mb-3" />

                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0f766e">Urine Assessment</div>
                <v-row dense>
                  <v-col cols="6"><v-select v-model="ucForm.urine_colour" :items="ucUrineColourOptions" label="Colour" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model="ucForm.urine_clarity" :items="ucUrineClarityOptions" label="Clarity" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model="ucForm.urine_odour" :items="ucUrineOdourOptions" label="Odour" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model="ucForm.urine_sediment" :items="ucUrineSedimentOptions" label="Sediment" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-select v-model="ucForm.urine_blood" :items="ucUrineBloodOptions" label="Blood" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  <v-col cols="6"><v-text-field v-model.number="ucForm.urine_output_ml" type="number" label="Urine Output (mL)" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                </v-row>

                <!-- Patient Symptoms -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0f766e">Patient Symptoms</div>
                <v-row dense>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_fever" label="Fever" color="red" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_chills" label="Chills" color="red" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_dysuria" label="Dysuria" color="red" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_abdominal_pain" label="Abdominal Pain" color="red" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_flank_pain" label="Flank Pain" color="red" density="compact" hide-details class="mb-1" /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="ucForm.patient_confusion" label="Confusion" color="red" density="compact" hide-details class="mb-1" /></v-col>
                </v-row>
                <v-divider class="mb-3" />

                <!-- Maintenance Bundle (compact dropdowns) -->
                <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0f766e">Maintenance Bundle</div>
                <v-row dense>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_necessity_reviewed" :items="enteralResponseOptions" label="Necessity Reviewed Today" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_necessity_indicated" :items="enteralResponseOptions" label="Catheter Still Indicated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_hand_hygiene_before" :items="enteralResponseOptions" label="Hand Hygiene Before" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_hand_hygiene_after" :items="enteralResponseOptions" label="Hand Hygiene After" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_ppe_gloves" :items="enteralResponseOptions" label="Gloves Worn" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_meatal_hygiene_done" :items="enteralResponseOptions" label="Meatal Hygiene Done" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_securement_intact" :items="enteralResponseOptions" label="Securement Intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_drain_closed" :items="enteralResponseOptions" label="Closed Drainage System" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_bag_below_bladder" :items="enteralResponseOptions" label="Bag Below Bladder" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_bag_not_floor" :items="enteralResponseOptions" label="Bag Not Touching Floor" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_empty_clean" :items="enteralResponseOptions" label="Empty Bag — Clean Technique" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_empty_output_doc" :items="enteralResponseOptions" label="Output Documented" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  <v-col cols="12" sm="6"><v-select v-model="ucForm.bundle_io_urine_recorded" :items="enteralResponseOptions" label="Urine Output Recorded" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                </v-row>
                <v-sheet v-if="ucCompliancePct != null" rounded="lg" :color="ucComplianceColor" class="pa-3 my-2">
                  <div class="d-flex justify-space-between align-center">
                    <span class="font-weight-bold text-white">Bundle Compliance: {{ ucCompliancePct }}%</span>
                  </div>
                </v-sheet>
              </template>

              <!-- CAM -->
              <template v-else-if="recordTypeKey==='cam'">
                <v-checkbox v-model="recordForm.cam_acute_onset" label="Acute onset / fluctuating course" color="deep-purple" density="compact" class="mb-1" />
                <v-checkbox v-model="recordForm.cam_inattention" label="Inattention" color="deep-purple" density="compact" class="mb-1" />
                <v-checkbox v-model="recordForm.cam_disorganized" label="Disorganized thinking" color="deep-purple" density="compact" class="mb-1" />
                <v-checkbox v-model="recordForm.cam_altered" label="Altered level of consciousness" color="deep-purple" density="compact" class="mb-2" />
                <v-sheet v-if="recordForm.cam_acute_onset && recordForm.cam_inattention && (recordForm.cam_disorganized || recordForm.cam_altered)" rounded="lg" color="deep-purple-lighten-5" class="pa-3 my-2">
                  <span class="font-weight-bold text-deep-purple">CAM Positive — Delirium likely</span>
                </v-sheet>
              </template>

              <!-- SKIN CARE -->
              <template v-else-if="recordTypeKey==='skin_care'">
                <v-alert type="info" variant="tonal" density="comfortable" rounded="lg" class="mb-3" icon="mdi-bandage">
                  Tick all bundle actions completed during this skin care round.
                </v-alert>
                <div class="d-flex flex-column ga-2 mb-3">
                  <div v-for="item in skinCareItems" :key="item.key" class="d-flex align-center ga-3 pa-3 rounded-lg" style="border: 1px solid rgba(148,163,184,0.22);">
                    <v-checkbox v-model="recordForm[`skin_${item.key}`]" density="comfortable" hide-details color="pink" />
                    <v-icon :icon="item.icon" size="18" color="pink-darken-1" />
                    <span class="text-body-2 flex-grow-1">{{ item.label }}</span>
                  </div>
                </div>
                <v-sheet rounded="lg" color="pink-lighten-5" class="pa-3 my-2">
                  <div class="d-flex justify-space-between">
                    <span class="font-weight-medium">Bundle Tasks Completed</span>
                    <span class="text-h6 font-weight-bold">{{ skinCareFormTotal }} / {{ skinCareItems.length }}</span>
                  </div>
                </v-sheet>
              </template>

              <!-- ═══ ARTIFICIAL AIRWAY ASSESSMENT ═══ -->
              <template v-else-if="recordTypeKey==='artificial_airway'">
                <div class="d-flex align-center ga-2 mb-3 flex-wrap">
                  <v-icon color="cyan-darken-1" size="20">mdi-air-humidifier</v-icon>
                  <span class="text-body-2 font-weight-bold text-cyan-darken-1">Artificial Airway Management</span>
                </div>

                <!-- Device Header -->
                <v-row dense class="mb-2">
                  <v-col cols="6" sm="3">
                    <v-select v-model="airwayForm.airway_device" :items="airwayDeviceOptions" label="Airway Device" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-select v-model="airwayForm.assessment_type" :items="airwayAssessmentTypeOptions" label="Assessment Type" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-text-field v-model="airwayForm.tube_brand" label="Tube Brand / Model" placeholder="e.g. Shiley 8.0" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-text-field v-model="airwayForm.tube_size" label="Tube Size" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-text-field v-model.number="airwayForm.device_day" type="number" label="Device Day" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-text-field v-model="airwayForm.location" label="Location" placeholder="ICU / Home / Ward" variant="outlined" density="comfortable" class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-switch v-model="airwayForm.is_cuffed" label="Cuffed Tube" color="cyan" density="compact" hide-details class="mb-2" />
                  </v-col>
                  <v-col cols="6" sm="3">
                    <v-switch v-model="airwayForm.mechanically_ventilated" label="Mechanically Ventilated" color="error" density="compact" hide-details class="mb-2" />
                  </v-col>
                </v-row>
                <v-row dense class="mb-3">
                  <v-col cols="6" sm="4"><v-switch v-model="airwayForm.inner_cannula_present" label="Inner Cannula Present" color="cyan" density="compact" hide-details /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="airwayForm.subglottic_port_present" label="Subglottic Port" color="cyan" density="compact" hide-details /></v-col>
                  <v-col cols="6" sm="4"><v-switch v-model="airwayForm.device_removed" label="Device Removed" color="red" density="compact" hide-details /></v-col>
                  <v-col v-if="airwayForm.device_removed" cols="12">
                    <v-text-field v-model="airwayForm.removal_reason" label="Removal Reason (decannulation/extubation)" variant="outlined" density="comfortable" class="mt-2" />
                  </v-col>
                </v-row>

                <v-alert v-if="airwayEmergencyIncomplete" type="error" variant="tonal" density="comfortable" rounded="lg" class="mb-3" icon="mdi-alert-octagon">
                  <strong>Critical:</strong> Emergency equipment incomplete — bedside airway emergency supplies must be verified immediately.
                </v-alert>

                <!-- ═══ TRACHEOSTOMY ASSESSMENT ═══ -->
                <template v-if="isAirwayTracheostomy">
                  <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#0891b2">Tracheostomy Care Bundle</div>

                  <!-- Section 1: General Infection Prevention -->
                  <div class="text-caption font-weight-bold mb-1">Section 1 — General Infection Prevention</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_hand_hygiene_before" :items="airwayResponseOptions" label="Hand hygiene before procedure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_gloves_worn" :items="airwayResponseOptions" label="Gloves worn" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_ppe_used" :items="airwayResponseOptions" label="PPE used if indicated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_hand_hygiene_after" :items="airwayResponseOptions" label="Hand hygiene after procedure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 2: Tube Assessment -->
                  <div class="text-caption font-weight-bold mb-1">Section 2 — Tube Assessment</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_position_correct" :items="airwayResponseOptions" label="Tube position correct" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_patent" :items="airwayResponseOptions" label="Tube patent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_intact" :items="airwayResponseOptions" label="Tube intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_unobstructed" :items="airwayResponseOptions" label="Tube unobstructed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_size_verified" :items="airwayResponseOptions" label="Tube size verified" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_type_verified" :items="airwayResponseOptions" label="Tube type verified" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_secured" :items="airwayResponseOptions" label="Tube secured" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_no_air_leak" :items="airwayResponseOptions" label="No air leak" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_tube_no_visible_damage" :items="airwayResponseOptions" label="No visible damage" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 3: Stoma Assessment -->
                  <div class="text-caption font-weight-bold mb-1">Section 3 — Stoma Assessment</div>
                  <v-row dense class="mb-1">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_skin_clean" :items="airwayResponseOptions" label="Skin clean" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_skin_dry" :items="airwayResponseOptions" label="Skin dry" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_redness" :items="airwayResponseOptions" label="No redness" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_swelling" :items="airwayResponseOptions" label="No swelling" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_bleeding" :items="airwayResponseOptions" label="No bleeding" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_discharge" :items="airwayResponseOptions" label="No discharge" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_odor" :items="airwayResponseOptions" label="No odor" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_granulation" :items="airwayResponseOptions" label="No granulation tissue" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_pressure_injury" :items="airwayResponseOptions" label="No pressure injury" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_no_skin_breakdown" :items="airwayResponseOptions" label="No skin breakdown" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_stoma_pain_absent" :items="airwayResponseOptions" label="Pain absent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>
                  <v-expand-transition>
                    <div v-if="airwayForm.t_stoma_no_redness === 'no'" class="mb-3">
                      <v-select v-model="airwayForm.t_stoma_redness_severity" :items="['mild','moderate','severe']" label="Redness Severity" variant="outlined" density="comfortable" class="mb-2" />
                      <v-text-field v-model="airwayForm.t_stoma_photo_url" label="Photo URL (if documented)" variant="outlined" density="comfortable" class="mb-2" />
                      <v-textarea v-model="airwayForm.t_stoma_interventions" label="Interventions" rows="2" variant="outlined" density="comfortable" />
                    </div>
                  </v-expand-transition>

                  <!-- Section 4: Securement -->
                  <div class="text-caption font-weight-bold mb-1">Section 4 — Securement</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_neck_ties_intact" :items="airwayResponseOptions" label="Neck ties intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_correct_tightness" :items="airwayResponseOptions" label="Correct tightness" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_holder_intact" :items="airwayResponseOptions" label="Commercial holder intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_finger_spacing" :items="airwayResponseOptions" label="One–two finger spacing" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_no_pressure_injury" :items="airwayResponseOptions" label="No pressure injury" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_secure_no_excessive_movement" :items="airwayResponseOptions" label="No excessive movement" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 5: Inner Cannula (conditional) -->
                  <template v-if="airwayForm.inner_cannula_present">
                    <div class="text-caption font-weight-bold mb-1">Section 5 — Inner Cannula</div>
                    <v-row dense class="mb-3">
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_inner_clean" :items="airwayResponseOptions" label="Inner cannula clean" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_inner_patent" :items="airwayResponseOptions" label="Inner cannula patent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_inner_changed_today" :items="airwayResponseOptions" label="Changed today" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_inner_type" :items="['disposable','reusable']" label="Cannula type" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_inner_replacement_required" :items="airwayResponseOptions" label="Replacement required" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    </v-row>
                  </template>

                  <!-- Section 6: Cuff Assessment (conditional) -->
                  <template v-if="airwayForm.is_cuffed">
                    <div class="text-caption font-weight-bold mb-1">Section 6 — Cuff Assessment</div>
                    <v-row dense class="mb-3">
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_cuff_inflated" :items="airwayResponseOptions" label="Cuff inflated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_cuff_pressure_measured" :items="airwayResponseOptions" label="Pressure measured" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-text-field v-model.number="airwayForm.t_cuff_pressure_value" type="number" label="Pressure (cmH₂O) — target 20–30" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_cuff_pressure_in_range" :items="airwayResponseOptions" label="Pressure within target range" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_cuff_air_leak_absent" :items="airwayResponseOptions" label="Air leak absent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                      <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_cuff_pilot_balloon_intact" :items="airwayResponseOptions" label="Pilot balloon intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    </v-row>
                  </template>

                  <!-- Section 7: Humidification -->
                  <div class="text-caption font-weight-bold mb-1">Section 7 — Humidification</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_prescribed" :items="airwayResponseOptions" label="Humidification prescribed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_functioning" :items="airwayResponseOptions" label="Humidification functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_hme_functioning" :items="airwayResponseOptions" label="HME functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_heated_functioning" :items="airwayResponseOptions" label="Heated humidifier functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_water_chamber_adequate" :items="airwayResponseOptions" label="Water chamber adequate" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_humid_tubing_functioning" :items="airwayResponseOptions" label="Tubing functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 8: Suction Equipment -->
                  <div class="text-caption font-weight-bold mb-1">Section 8 — Suction Equipment</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_suction_available" :items="airwayResponseOptions" label="Suction available" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_suction_pressure_checked" :items="airwayResponseOptions" label="Pressure checked" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_suction_catheter_available" :items="airwayResponseOptions" label="Catheter available" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_suction_correct_size" :items="airwayResponseOptions" label="Correct catheter size" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_suction_equipment_functional" :items="airwayResponseOptions" label="Equipment functional" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 9: Emergency Equipment -->
                  <div class="text-caption font-weight-bold mb-1" style="color:#b91c1c">Section 9 — Emergency Equipment</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_same_size_tube" :items="airwayResponseOptions" label="Same-size spare tube" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_smaller_tube" :items="airwayResponseOptions" label="One-size smaller tube" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_obturator" :items="airwayResponseOptions" label="Obturator" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_bag_valve_mask" :items="airwayResponseOptions" label="Bag-valve-mask" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_oxygen" :items="airwayResponseOptions" label="Oxygen available" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_emerg_call_bell" :items="airwayResponseOptions" label="Emergency call bell" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 10: Communication -->
                  <div class="text-caption font-weight-bold mb-1">Section 10 — Communication</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_method_assessed" :items="airwayResponseOptions" label="Communication method assessed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_speaking_valve" :items="airwayResponseOptions" label="Speaking valve" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_writing_board" :items="airwayResponseOptions" label="Writing board" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_communication_chart" :items="airwayResponseOptions" label="Communication chart" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_interpreter" :items="airwayResponseOptions" label="Interpreter" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.t_comm_caregiver_support" :items="airwayResponseOptions" label="Caregiver support" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 11: Documentation -->
                  <div class="text-caption font-weight-bold mb-1">Section 11 — Documentation</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_doc_bundle_complete" :items="airwayResponseOptions" label="Bundle complete" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.t_doc_education_completed" :items="airwayResponseOptions" label="Education completed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Trach compliance preview -->
                  <v-sheet v-if="airwayTrachCompliancePct != null" rounded="lg" :color="complianceColor(airwayTrachCompliancePct)" class="pa-3 mb-3">
                    <div class="d-flex justify-space-between align-center">
                      <span class="font-weight-bold text-white">Tracheostomy Compliance: {{ airwayTrachCompliancePct }}%</span>
                    </div>
                  </v-sheet>
                </template>

                <!-- ═══ VAP PREVENTION BUNDLE ═══ -->
                <template v-if="isAirwayVAPActive">
                  <v-divider class="my-3" />
                  <div class="text-caption text-uppercase font-weight-bold mb-2" style="color:#7c3aed">VAP Prevention Bundle</div>

                  <!-- Section 1: Head of Bed -->
                  <div class="text-caption font-weight-bold mb-1">Section 1 — Head of Bed</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.v_hob_30_45_maintained" :items="airwayResponseOptions" label="30–45° maintained" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.v_hob_contraindication" :items="airwayResponseOptions" label="Contraindication present" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 2: Oral Care -->
                  <div class="text-caption font-weight-bold mb-1">Section 2 — Oral Care</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_care_completed" :items="airwayResponseOptions" label="Oral care completed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_teeth_cleaned" :items="airwayResponseOptions" label="Teeth cleaned" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_tongue_cleaned" :items="airwayResponseOptions" label="Tongue cleaned" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_mucosa_clean" :items="airwayResponseOptions" label="Mucosa clean" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_moisturizer_applied" :items="airwayResponseOptions" label="Moisturizer applied" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_oral_chlorhexidine_used" :items="airwayResponseOptions" label="Chlorhexidine used (per policy)" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6"><v-select v-model="airwayForm.v_oral_secretions_removed" :items="airwayResponseOptions" label="Secretions removed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 3: Airway Device -->
                  <div class="text-caption font-weight-bold mb-1">Section 3 — Airway Device</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_airway_tube_secure" :items="airwayResponseOptions" label="Tube secure" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_airway_position_correct" :items="airwayResponseOptions" label="Tube position correct" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_airway_cuff_pressure_target" :items="airwayResponseOptions" label="Cuff pressure within target" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_airway_no_air_leak" :items="airwayResponseOptions" label="No air leak" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col v-if="airwayForm.subglottic_port_present" cols="12" sm="6" md="4"><v-select v-model="airwayForm.v_airway_subglottic_functioning" :items="airwayResponseOptions" label="Subglottic drainage functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 4: Sedation -->
                  <div class="text-caption font-weight-bold mb-1">Section 4 — Sedation</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_sedation_daily_review" :items="airwayResponseOptions" label="Daily sedation review" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_sedation_interruption" :items="airwayResponseOptions" label="Sedation interruption" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_sedation_contraindication" :items="airwayResponseOptions" label="Contraindication documented" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 5: Weaning -->
                  <div class="text-caption font-weight-bold mb-1">Section 5 — Weaning</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_weaning_readiness_assessed" :items="airwayResponseOptions" label="Readiness assessed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_weaning_sbt_considered" :items="airwayResponseOptions" label="SBT considered" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="4"><v-select v-model="airwayForm.v_weaning_extubation_readiness" :items="airwayResponseOptions" label="Extubation readiness" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 6: Suctioning -->
                  <div class="text-caption font-weight-bold mb-1">Section 6 — Suctioning</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_suction_need_assessed" :items="airwayResponseOptions" label="Need assessed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_suction_secretions_removed" :items="airwayResponseOptions" label="Secretions removed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_suction_closed_functioning" :items="airwayResponseOptions" label="Closed suction functioning" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_suction_catheter_changed" :items="airwayResponseOptions" label="Catheter changed per policy" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 7: Ventilator Circuit -->
                  <div class="text-caption font-weight-bold mb-1">Section 7 — Ventilator Circuit</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_circuit_intact" :items="airwayResponseOptions" label="Circuit intact" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_circuit_no_disconnections" :items="airwayResponseOptions" label="No unnecessary disconnections" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_circuit_condensation_managed" :items="airwayResponseOptions" label="Condensation managed" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_circuit_changed_per_policy" :items="airwayResponseOptions" label="Circuit changed per policy" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 8: Aspiration Prevention -->
                  <div class="text-caption font-weight-bold mb-1">Section 8 — Aspiration Prevention</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_asp_head_elevated" :items="airwayResponseOptions" label="Head elevated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_asp_feeding_paused" :items="airwayResponseOptions" label="Feeding paused if indicated" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_asp_tube_position_verified" :items="airwayResponseOptions" label="Tube position verified" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                    <v-col cols="12" sm="6" md="3"><v-select v-model="airwayForm.v_asp_regurgitation_absent" :items="airwayResponseOptions" label="Regurgitation absent" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- Section 9: Documentation -->
                  <div class="text-caption font-weight-bold mb-1">Section 9 — Documentation</div>
                  <v-row dense class="mb-3">
                    <v-col cols="12"><v-select v-model="airwayForm.v_doc_bundle_complete" :items="airwayResponseOptions" label="Bundle complete" variant="outlined" density="comfortable" class="mb-1" /></v-col>
                  </v-row>

                  <!-- VAP compliance preview -->
                  <v-sheet v-if="airwayVapCompliancePct != null" rounded="lg" :color="complianceColor(airwayVapCompliancePct)" class="pa-3 mb-3">
                    <div class="d-flex justify-space-between align-center">
                      <span class="font-weight-bold text-white">VAP Compliance: {{ airwayVapCompliancePct }}%</span>
                    </div>
                  </v-sheet>
                </template>

                <!-- Overall compliance preview -->
                <v-sheet v-if="airwayOverallCompliancePct != null" rounded="xl" :style="{ background: airwayOverallComplianceColor }" class="pa-4 mb-3">
                  <div class="d-flex align-center justify-space-between">
                    <span class="text-h6 font-weight-bold text-white">Overall Compliance</span>
                    <span class="text-h4 font-weight-bold text-white">{{ airwayOverallCompliancePct }}%</span>
                  </div>
                </v-sheet>
              </template>

              <v-divider class="my-3" />
              <v-text-field v-model="recordForm.assessed_at" type="datetime-local" label="Date / Time" variant="outlined" density="comfortable" class="mb-2" />
              <v-textarea v-model="recordForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn variant="text" @click="showRecordDialog = false">Cancel</v-btn>
              <v-btn color="teal" variant="flat" :loading="assessmentSaving" @click="saveAssessmentEntry">Save Record</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <v-dialog v-model="showAssessmentHistoryDialog" max-width="920" scrollable>
          <v-card rounded="xl">
            <v-card-title class="d-flex align-center ga-2" v-if="assessmentHistoryTypeDef">
              <v-icon :icon="assessmentHistoryTypeDef.icon" :color="assessmentHistoryTypeDef.color" />
              <span>{{ assessmentHistoryTypeDef.label }} History</span>
              <v-spacer />
              <v-chip size="small" color="teal" variant="tonal" label>{{ assessmentHistoryEntries.length }} records</v-chip>
            </v-card-title>
            <v-card-text class="pa-0">
              <!-- Braden history: table-like expandable rows -->
              <div v-if="assessmentHistoryEntries.length && assessmentHistoryTypeKey === 'braden'" class="pa-4" style="max-height: 70vh; overflow-y: auto;">
                <v-table density="compact" class="cc-table">
                  <thead>
                    <tr>
                      <th>Date / Time</th>
                      <th>Braden Total</th>
                      <th>Risk Level</th>
                      <th>Staff</th>
                      <th class="text-center">Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    <template v-for="entry in assessmentHistoryEntries" :key="entry.id">
                      <tr @click="toggleHistoryExpand(entry.id)" style="cursor:pointer" class="cc-braden-history-row">
                        <td class="text-caption">{{ formatDateTime(entry.timestamp) }}</td>
                        <td><span class="font-weight-bold" :style="{ color: bradenScoreColor(entry.bradenTotal) }">{{ entry.bradenTotal ?? '—' }} / 23</span></td>
                        <td><v-chip size="x-small" :color="bradenScoreChipColor(entry.bradenTotal)" variant="tonal" label>{{ bradenRiskLabel(entry.bradenTotal) || '—' }}</v-chip></td>
                        <td class="text-caption">{{ entry.staff }}</td>
                        <td class="text-center"><v-icon size="small" :icon="expandedHistoryIds.has(entry.id) ? 'mdi-chevron-up' : 'mdi-chevron-down'" /></td>
                      </tr>
                      <tr v-if="expandedHistoryIds.has(entry.id)">
                        <td colspan="5" class="pa-0">
                          <div class="pa-4" style="background: rgba(245,158,11,0.04);">
                            <div class="d-flex align-center ga-2 flex-wrap mb-3">
                              <v-chip size="x-small" color="success" variant="tonal" label>{{ entry.statusLabel }}</v-chip>
                              <v-chip size="x-small" color="blue-grey" variant="tonal" label>{{ entry.sessionType }}</v-chip>
                              <v-chip v-if="entry.overallRisk" size="x-small" color="warning" variant="tonal" label>{{ entry.overallRisk }}</v-chip>
                            </div>
                            <div class="text-caption font-weight-bold mb-2">Subscale Scores</div>
                            <div v-if="entry.braden && Object.keys(extractBradenSubscales(entry.braden)).length" class="d-flex flex-wrap ga-2 mb-3">
                              <v-chip v-for="(v, k) in extractBradenSubscales(entry.braden)" :key="k" size="small" variant="tonal" label
                                      :color="v <= 2 ? 'error' : v <= 3 ? 'warning' : 'success'">{{ bradenSubscaleLabel(k) }}: {{ v }}</v-chip>
                            </div>
                            <div v-else class="text-caption text-medium-emphasis mb-3">No subscale data recorded for this entry.</div>
                            <div v-if="entry.notes" class="text-body-2 text-medium-emphasis mt-2">{{ entry.notes }}</div>
                          </div>
                        </td>
                      </tr>
                    </template>
                  </tbody>
                </v-table>
              </div>
              <!-- ▸▸▸ Pain history: premium layered layout — most-recent fully expanded, older collapsible ▸▸▸ -->
              <div v-else-if="assessmentHistoryEntries.length && assessmentHistoryTypeKey === 'pain_reassess'" class="pa-4" style="max-height: 75vh; overflow-y: auto;">
                <template v-for="(entry, idx) in assessmentHistoryEntries" :key="entry.id">
                  <!-- Most‑recent record: always fully expanded -->
                  <v-sheet v-if="idx === 0" rounded="xl" color="orange-lighten-5" class="pa-4 mb-4" border="orange-lighten-4 opacity-50">
                    <div class="d-flex align-center ga-2 mb-3">
                      <v-icon color="#b45309" size="22">mdi-history</v-icon>
                      <span class="font-weight-bold text-body-1">Most Recent — {{ formatDateTime(entry.timestamp) }}</span>
                      <v-spacer />
                      <v-chip size="x-small" color="grey-darken-1" variant="tonal" label>{{ entry.staff }}</v-chip>
                    </div>
                    <!-- Pain header badges -->
                    <div class="d-flex flex-wrap ga-2 mb-3">
                      <v-chip size="x-small" color="#b45309" variant="flat" class="font-weight-bold text-white">{{ entry.resultText }}</v-chip>
                      <v-chip v-if="entry.overallRisk" size="x-small" color="warning" variant="tonal" label>{{ entry.overallRisk }}</v-chip>
                    </div>
                    <!-- Rich metric chips -->
                    <div v-if="entry.metrics.length" class="d-flex flex-wrap ga-2">
                      <v-chip v-for="metric in entry.metrics" :key="`pain-${entry.id}-${metric.label}`" size="x-small" variant="outlined"
                              :color="metric.label==='Score'||metric.label==='FLACC Total'||metric.label==='PAINAD Total'?'#b45309':metric.label.startsWith('Worst')?'red':
                                      metric.label.startsWith('Treatment')||metric.label==='Intervention'?'purple':'blue-grey'" label>
                        <span class="font-weight-medium">{{ metric.label }}</span><span class="ml-1 text-medium-emphasis">{{ metric.value }}</span>
                      </v-chip>
                    </div>
                    <div v-if="entry.notes" class="text-body-2 text-medium-emphasis mt-3 pa-2" style="background:rgba(255,255,255,0.5);border-radius:8px">{{ entry.notes }}</div>
                  </v-sheet>
                  <!-- Older records: collapsible card -->
                  <v-card v-else variant="outlined" rounded="lg" class="mb-3" :class="expandedHistoryIds.has(entry.id) ? 'border-orange-lighten-2' : ''">
                    <div class="pa-4 cursor-pointer" @click="toggleHistoryExpand(entry.id)" style="transition:background .15s">
                      <div class="d-flex align-center ga-3 flex-wrap">
                        <v-icon :icon="expandedHistoryIds.has(entry.id) ? 'mdi-chevron-up' : 'mdi-chevron-down'" size="20" color="grey" />
                        <v-chip size="x-small" :color="painScoreChipColorFor(entry.itemScore)" variant="flat" class="font-weight-bold text-white">{{ entry.resultText }}</v-chip>
                        <span class="text-caption text-medium-emphasis">{{ formatShortDateTime(entry.timestamp) }}</span>
                        <v-spacer />
                        <span class="text-caption text-grey">{{ entry.staff }}</span>
                      </div>
                      <!-- Inline summary metric preview -->
                      <div v-if="entry.metrics.length" class="d-flex flex-wrap ga-1 mt-2 ml-8">
                        <span v-for="metric in entry.metrics.slice(0, 4)" :key="`ps-${entry.id}-${metric.label}`" class="text-caption text-grey-darken-2 mr-2">{{ metric.label }}: <strong>{{ metric.value }}</strong></span>
                        <span v-if="entry.metrics.length > 4" class="text-caption text-medium-emphasis">+{{ entry.metrics.length - 4 }} more</span>
                      </div>
                    </div>
                    <v-expand-transition>
                      <div v-if="expandedHistoryIds.has(entry.id)" class="pa-4 pt-0" style="background:rgba(245,158,11,0.03)">
                        <v-divider class="mb-3" />
                        <div class="d-flex flex-wrap ga-2 mb-3">
                          <v-chip size="x-small" color="success" variant="tonal" label>{{ entry.statusLabel }}</v-chip>
                          <v-chip size="x-small" color="blue-grey" variant="tonal" label>{{ entry.sessionType }}</v-chip>
                          <v-chip v-if="entry.overallRisk" size="x-small" color="warning" variant="tonal" label>{{ entry.overallRisk }}</v-chip>
                        </div>
                        <div v-if="entry.metrics.length" class="d-flex flex-wrap ga-2">
                          <v-chip v-for="metric in entry.metrics" :key="`pexp-${entry.id}-${metric.label}`" size="x-small" variant="outlined"
                                  :color="metric.label==='Score'||metric.label==='FLACC Total'||metric.label==='PAINAD Total'?'#b45309':metric.label.startsWith('Worst')?'red':
                                          metric.label.startsWith('Treatment')||metric.label==='Intervention'?'purple':'blue-grey'" label>
                            <span class="font-weight-medium">{{ metric.label }}</span><span class="ml-1 text-medium-emphasis">{{ metric.value }}</span>
                          </v-chip>
                        </div>
                        <div v-if="entry.notes" class="text-body-2 text-medium-emphasis mt-3">{{ entry.notes }}</div>
                      </div>
                    </v-expand-transition>
                  </v-card>
                </template>
              </div>
              <!-- All other types: card layout -->
              <div v-else-if="assessmentHistoryEntries.length" class="pa-4" style="max-height: 70vh; overflow-y: auto;">
                <v-card v-for="entry in assessmentHistoryEntries" :key="entry.id" variant="outlined" rounded="lg" class="pa-4 mb-3">
                  <div class="d-flex align-start justify-space-between ga-3 flex-wrap mb-2">
                    <div>
                      <div class="font-weight-bold text-body-1">{{ entry.resultText }}</div>
                      <div class="text-caption text-medium-emphasis mt-1">
                        {{ formatDateTime(entry.timestamp) }}
                        <span v-if="entry.staff && entry.staff !== '—'"> · {{ entry.staff }}</span>
                      </div>
                    </div>
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <v-chip size="x-small" color="success" variant="tonal" label>{{ entry.statusLabel }}</v-chip>
                      <v-chip size="x-small" color="blue-grey" variant="tonal" label>{{ entry.sessionType }}</v-chip>
                      <v-chip v-if="entry.overallRisk" size="x-small" color="warning" variant="tonal" label>{{ entry.overallRisk }}</v-chip>
                    </div>
                  </div>

                  <div v-if="entry.metrics.length" class="d-flex flex-wrap ga-2 mt-3">
                    <v-chip v-for="metric in entry.metrics" :key="`${entry.id}-${metric.label}`" size="small" variant="tonal" color="teal" label>
                      {{ metric.label }}: {{ metric.value }}
                    </v-chip>
                  </div>

                  <div v-if="entry.notes" class="text-body-2 text-medium-emphasis mt-3">
                    {{ entry.notes }}
                  </div>
                </v-card>
              </div>
              <div v-else class="pa-8 text-center text-medium-emphasis">
                <v-icon icon="mdi-history" size="42" color="grey" class="mb-3" />
                <div class="font-weight-medium">No completed {{ assessmentHistoryTypeDef?.label || 'assessment' }} records yet.</div>
                <div class="text-caption mt-1">Completed assessment entries will appear here with timestamp, staff, and recorded results.</div>
              </div>
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn variant="text" @click="showAssessmentHistoryDialog = false">Close</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <!-- ═══════════════ VITALS & NEWS2 ═══════════════ -->
        <v-window-item value="vitals">
          <v-row dense class="pa-4">
            <v-col cols="12" md="5">
              <v-card rounded="xl" variant="tonal" class="pa-4 mb-3" color="blue">
                <div class="text-overline font-weight-bold text-blue mb-1">NEWS2 Monitoring</div>
                <div class="d-flex align-center ga-4 mb-3">
                  <div class="cc-gauge" :style="{ '--gauge-pct': news2GaugePct, '--gauge-color': riskHex }">
                    <svg viewBox="0 0 120 120" class="cc-gauge-svg">
                      <circle cx="60" cy="60" r="52" fill="none" stroke="rgba(148,163,184,0.15)" stroke-width="10" />
                      <circle cx="60" cy="60" r="52" fill="none" :stroke="riskHex" stroke-width="10"
                              stroke-linecap="round" :stroke-dasharray="gaugeDasharray" :stroke-dashoffset="0"
                              transform="rotate(-90 60 60)" class="cc-gauge-arc" />
                    </svg>
                    <div class="cc-gauge-value">
                      <span class="text-h4 font-weight-bold" :style="{ color: riskHex }">{{ latestNews2 ?? '—' }}</span>
                      <span class="text-caption text-medium-emphasis">/ 20</span>
                    </div>
                  </div>
                  <div>
                    <v-chip :color="riskColor" variant="flat" class="font-weight-bold mb-2">{{ riskLabel }} Risk</v-chip>
                    <div class="text-caption text-medium-emphasis">
                      <div><v-icon icon="mdi-clock" size="14" /> {{ vitalsFrequency }}</div>
                      <div><v-icon icon="mdi-update" size="14" /> Next due: {{ nextVitalsDue }}</div>
                    </div>
                  </div>
                </div>
                <div class="cc-countdown-bar mb-3">
                  <div class="d-flex justify-space-between text-caption mb-1">
                    <span>Last: {{ lastVitalsTimeShort }}</span><span>Next: {{ nextVitalsTimeShort }}</span>
                  </div>
                  <div class="cc-countdown-track">
                    <div class="cc-countdown-fill" :style="{ width: vitalsProgressPct, background: vitalsProgressColor }" />
                  </div>
                  <div class="text-caption text-center mt-1" :class="vitalsUrgencyClass">{{ vitalsUrgencyText }}</div>
                </div>
                <div class="text-caption font-weight-bold mb-2">Scale Breakdown</div>
                <div v-if="news2Breakdown.length">
                  <div v-for="b in news2Breakdown" :key="b.key" class="cc-news2-row">
                    <v-icon size="16" class="me-2" :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'grey')">{{ b.icon }}</v-icon>
                    <span class="text-caption flex-grow-1">{{ b.label }}</span>
                    <span class="text-caption text-medium-emphasis me-2">{{ b.value }}</span>
                    <v-chip size="x-small" variant="tonal" :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'success')">{{ b.score }}</v-chip>
                  </div>
                </div>
                <div v-else class="text-caption text-medium-emphasis">Record vitals to see NEWS2 breakdown.</div>
              </v-card>
            </v-col>
            <v-col cols="12" md="7">
              <v-card rounded="xl" variant="tonal" class="pa-4" color="teal">
                <div class="d-flex align-center mb-3">
                  <v-icon icon="mdi-chart-line" color="teal" class="mr-2" />
                  <span class="text-subtitle-1 font-weight-bold">Vitals History</span>
                  <v-spacer />
                  <v-btn size="small" color="teal" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openQuickVitals">Record</v-btn>
                </div>
                <v-table density="compact" class="cc-table">
                  <thead><tr><th>Date/Time</th><th>NEWS2</th><th>BP</th><th>RR</th><th>Pulse</th><th>Temp</th><th>SpO₂</th></tr></thead>
                  <tbody>
                    <tr v-for="r in patientVitals" :key="r.id">
                      <td class="text-caption">{{ formatShortDateTime(r.recorded_at) }}</td>
                      <td><v-chip v-if="r.news2!=null" size="x-small" variant="tonal" :color="news2Color(r.news2)">{{ r.news2 }}</v-chip><span v-else>—</span></td>
                      <td>{{ r.systolic||'—' }}/{{ r.diastolic||'—' }}</td><td>{{ r.rr||'—' }}</td><td>{{ r.pulse||'—' }}</td>
                      <td>{{ r.temperature||'—' }}</td><td>{{ r.spo2||'—' }}%</td>
                    </tr>
                    <tr v-if="!patientVitals.length"><td colspan="7" class="text-center text-medium-emphasis py-4">No vitals recorded yet.</td></tr>
                  </tbody>
                </v-table>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- ═══════════════ BRADEN & SKIN CARE ═══════════════ -->
        <v-window-item value="braden">
          <v-row dense class="pa-4">
            <v-col cols="12" md="5">
              <v-card rounded="xl" variant="tonal" class="pa-4 mb-3" color="orange">
                <div class="text-overline font-weight-bold text-orange-darken-2 mb-1">Braden Scale</div>
                <div class="d-flex align-center ga-4 mb-3">
                  <div class="cc-gauge" :style="{ '--gauge-pct': bradenGaugePct, '--gauge-color': bradenColor }">
                    <svg viewBox="0 0 120 120" class="cc-gauge-svg">
                      <circle cx="60" cy="60" r="52" fill="none" stroke="rgba(148,163,184,0.15)" stroke-width="10" />
                      <circle cx="60" cy="60" r="52" fill="none" :stroke="bradenColor" stroke-width="10"
                              stroke-linecap="round" :stroke-dasharray="bradenDasharray" :stroke-dashoffset="0"
                              transform="rotate(-90 60 60)" class="cc-gauge-arc" />
                    </svg>
                    <div class="cc-gauge-value">
                      <span class="text-h4 font-weight-bold" :style="{ color: bradenColor }">{{ latestBraden?.total ?? '—' }}</span>
                      <span class="text-caption text-medium-emphasis">/ 23</span>
                    </div>
                  </div>
                  <div>
                    <v-chip :color="bradenChipColor" variant="flat" class="font-weight-bold mb-2">{{ latestBraden?.risk_level || 'No data' }}</v-chip>
                    <div class="text-caption text-medium-emphasis">
                      <div><v-icon icon="mdi-clock" size="14" /> Every 12 hrs</div>
                      <div><v-icon icon="mdi-update" size="14" /> Next: {{ nextBradenDue }}</div>
                    </div>
                  </div>
                </div>
                <div class="cc-countdown-bar mb-3">
                  <div class="d-flex justify-space-between text-caption mb-1">
                    <span>Last: {{ lastBradenTimeShort }}</span><span>Next: {{ nextBradenTimeShort }}</span>
                  </div>
                  <div class="cc-countdown-track">
                    <div class="cc-countdown-fill" :style="{ width: bradenProgressPct, background: bradenProgressColor }" />
                  </div>
                  <div class="text-caption text-center mt-1" :class="bradenUrgencyClass">{{ bradenUrgencyText }}</div>
                </div>
                <div class="text-caption font-weight-bold mb-2">Subscale Scores</div>
                <div v-if="latestBraden && Object.keys(latestBradenSubs).length" class="d-flex flex-wrap ga-2">
                  <v-chip v-for="(v,k) in latestBradenSubs" :key="k" size="small" variant="tonal" label
                          :color="v <= 2 ? 'error' : v <= 3 ? 'warning' : 'success'">{{ k }}: {{ v }}</v-chip>
                </div>
                <div v-else class="text-caption text-medium-emphasis">No Braden score recorded. Complete an assessment first.</div>
                <v-alert v-if="bradenLowAlert" type="error" variant="tonal" density="compact" rounded="lg"
                         icon="mdi-alert-octagon" class="mt-3 text-caption">
                  <strong>Braden ≤ 12</strong> — Skin care bundle activated automatically every 4 hrs.
                </v-alert>
              </v-card>
            </v-col>
            <v-col cols="12" md="7">
              <v-card rounded="xl" variant="tonal" class="pa-4 mb-3" color="pink">
                <div class="d-flex align-center mb-3">
                  <v-icon icon="mdi-bandage" color="pink" class="mr-2" />
                  <span class="text-subtitle-1 font-weight-bold">Skin Care Bundle</span>
                  <v-spacer />
                  <v-chip size="small" :color="skinCareActive ? 'error' : 'success'" variant="tonal" label>{{ skinCareActive ? 'ACTIVE q4h' : 'Standby' }}</v-chip>
                </div>
                <div class="cc-countdown-bar mb-3">
                  <div class="d-flex justify-space-between text-caption mb-1">
                    <span>Last done: {{ lastSkinCareTimeShort }}</span><span>Next due: {{ nextSkinCareTimeShort }}</span>
                  </div>
                  <div class="cc-countdown-track cc-countdown-track-lg">
                    <div class="cc-countdown-fill" :style="{ width: skinCareProgressPct, background: skinCareProgressColor }" />
                  </div>
                  <div class="text-caption text-center mt-2 font-weight-bold" :class="skinCareUrgencyClass">{{ skinCareUrgencyText }}</div>
                </div>
                <div class="text-caption font-weight-bold mb-2">Bundle Items (every 4 hrs)</div>
                <div class="d-flex flex-column ga-2">
                  <div v-for="item in skinCareItems" :key="item.key"
                       class="d-flex align-center ga-2 pa-2 rounded-lg cc-skin-item" :class="{ 'done': item.done }">
                    <v-checkbox v-model="item.done" density="compact" hide-details :color="item.done ? 'success' : undefined"
                                @update:model-value="v => toggleSkinCareItem(item.key, v)" />
                    <v-icon :icon="item.icon" size="18" :color="item.done ? 'success' : 'grey'" />
                    <span class="text-body-2 flex-grow-1" :class="{ 'text-decoration-line-through': item.done }">{{ item.label }}</span>
                    <span v-if="item.done" class="text-caption text-success">{{ item.doneTime }}</span>
                  </div>
                </div>
                <v-btn block color="pink" variant="flat" rounded="lg" class="text-none mt-3"
                       prepend-icon="mdi-check-all" :disabled="!skinCareActive" @click="completeSkinCare">Complete Bundle</v-btn>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

        <!-- ═══════════════ CLINICAL ASSESSMENT ═══════════════ -->
        <v-window-item value="clinical">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <v-icon icon="mdi-stethoscope" color="purple" size="24" />
              <span class="text-h6 font-weight-bold">Clinical Assessment Components</span>
              <v-spacer />
              <v-btn color="purple" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="showAddClinical = true">Add Component</v-btn>
            </div>
            <v-row dense>
              <v-col v-for="comp in activeClinicalComponents" :key="comp.key" cols="12" md="6" lg="4">
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-2 cc-clinical-card border-purple">
                  <div class="d-flex align-center mb-2">
                    <v-icon :icon="comp.icon" color="purple" size="22" class="mr-2" />
                    <span class="font-weight-medium flex-grow-1">{{ comp.label }}</span>
                    <v-btn size="x-small" variant="text" icon="mdi-close" color="grey" @click="removeClinical(comp.key)" />
                  </div>
                  <div class="text-caption text-medium-emphasis mb-2">{{ comp.description }}</div>
                  <v-select v-if="comp.options" v-model="comp.value" :items="comp.options"
                            :label="comp.label" variant="outlined" density="compact" rounded="lg" hide-details class="mb-2" />
                  <v-text-field v-else-if="comp.type==='number'" v-model.number="comp.value" type="number"
                                :label="comp.label" variant="outlined" density="compact" rounded="lg" hide-details class="mb-2" :suffix="comp.unit" />
                  <v-textarea v-else-if="comp.type==='text'" v-model="comp.value" :label="comp.label"
                              variant="outlined" density="compact" rounded="lg" hide-details rows="2" />
                  <v-checkbox v-else v-model="comp.value" :label="comp.label" density="compact" hide-details />
                  <div class="d-flex justify-space-between mt-2">
                    <span class="text-caption text-medium-emphasis">Last: {{ comp.lastDone || 'Never' }}</span>
                    <v-btn size="x-small" color="purple" variant="tonal" class="text-none" @click="markClinicalDone(comp.key)">Mark Done</v-btn>
                  </div>
                </v-card>
              </v-col>
              <v-col v-if="!activeClinicalComponents.length" cols="12">
                <div class="text-center py-6 text-medium-emphasis">
                  <v-icon icon="mdi-stethoscope" size="48" class="mb-2" color="grey" />
                  <div class="font-weight-medium">No clinical components active</div>
                  <div class="text-caption">Click "Add Component" to start building your clinical assessment.</div>
                </div>
              </v-col>
            </v-row>
            <v-dialog v-model="showAddClinical" max-width="420">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center"><v-icon icon="mdi-plus-circle" color="purple" class="mr-2" />Add Clinical Component</v-card-title>
                <v-card-text>
                  <v-select v-model="newClinical.key" :items="availableClinicals" item-title="label" item-value="key"
                            label="Component" variant="outlined" density="comfortable" class="mb-2" />
                </v-card-text>
                <v-card-actions><v-spacer /><v-btn variant="text" @click="showAddClinical = false">Cancel</v-btn>
                  <v-btn color="purple" variant="flat" @click="addClinical">Add</v-btn></v-card-actions>
              </v-card>
            </v-dialog>
          </div>
        </v-window-item>

        <!-- ═══════════════ FLUID BALANCE ═══════════════ -->
        <v-window-item value="fluid">
          <v-row dense class="pa-4">
            <v-col cols="12" md="4">
              <v-card rounded="xl" variant="tonal" class="pa-4 mb-3" color="cyan">
                <div class="text-overline font-weight-bold text-cyan-darken-2 mb-1">Fluid Balance</div>
                <div class="text-center mb-3">
                  <div class="text-h3 font-weight-bold" :class="fluidBalanceClass">{{ fluidBalance > 0 ? '+' : '' }}{{ fluidBalance }}ml</div>
                  <div class="text-caption text-medium-emphasis">Net Balance (24h)</div>
                </div>
                <v-row dense>
                  <v-col cols="6">
                    <v-card variant="flat" rounded="lg" class="pa-3 text-center" color="blue-lighten-5">
                      <v-icon icon="mdi-water-plus" color="blue" size="20" />
                      <div class="text-h6 font-weight-bold text-blue">{{ fluidIntake }}ml</div>
                      <div class="text-caption">Intake</div>
                    </v-card>
                  </v-col>
                  <v-col cols="6">
                    <v-card variant="flat" rounded="lg" class="pa-3 text-center" color="orange-lighten-5">
                      <v-icon icon="mdi-water-minus" color="orange" size="20" />
                      <div class="text-h6 font-weight-bold text-orange-darken-2">{{ fluidOutput }}ml</div>
                      <div class="text-caption">Output</div>
                    </v-card>
                  </v-col>
                </v-row>
              </v-card>
            </v-col>
            <v-col cols="12" md="8">
              <v-card rounded="xl" variant="tonal" class="pa-4" color="teal">
                <div class="d-flex align-center mb-3">
                  <v-icon icon="mdi-water" color="teal" class="mr-2" />
                  <span class="text-subtitle-1 font-weight-bold">Fluid Log</span>
                  <v-spacer />
                  <v-btn size="small" color="teal" variant="tonal" rounded="lg" class="text-none mr-2" prepend-icon="mdi-plus" @click="openFluidEntry('intake')">+ Intake</v-btn>
                  <v-btn size="small" color="deep-orange" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openFluidEntry('output')">+ Output</v-btn>
                </div>
                <v-table density="compact" class="cc-table">
                  <thead><tr><th>Time</th><th>Type</th><th>Route</th><th>Amount</th><th></th></tr></thead>
                  <tbody>
                    <tr v-for="f in fluidEntries" :key="f.id" :class="f.type==='intake'?'cc-fluid-in':'cc-fluid-out'">
                      <td class="text-caption">{{ formatTime(f.timestamp) }}</td>
                      <td><v-chip size="x-small" :color="f.type==='intake'?'blue':'deep-orange'" variant="tonal" label>{{ f.type==='intake'?'IN':'OUT' }}</v-chip>
                        <span class="text-caption ml-1">{{ f.subtype }}</span></td>
                      <td class="text-caption">{{ f.route||'—' }}</td>
                      <td class="font-weight-medium">{{ f.amount }}ml</td>
                      <td><v-btn size="x-small" variant="text" icon="mdi-delete" color="error" @click="deleteFluidEntry(f)" /></td>
                    </tr>
                    <tr v-if="!fluidEntries.length"><td colspan="5" class="text-center text-medium-emphasis py-4">No fluid entries recorded today.</td></tr>
                  </tbody>
                </v-table>
              </v-card>
            </v-col>
          </v-row>
          <v-dialog v-model="fluidDialog.show" max-width="420">
            <v-card rounded="xl">
              <v-card-title class="d-flex align-center">
                <v-icon :icon="fluidDialog.type==='intake'?'mdi-water-plus':'mdi-water-minus'"
                        :color="fluidDialog.type==='intake'?'blue':'deep-orange'" class="mr-2" />
                {{ fluidDialog.type==='intake'?'Record Intake':'Record Output' }}
              </v-card-title>
              <v-card-text>
                <v-select v-model="fluidDialog.subtype" :items="fluidDialog.type==='intake'?INTAKE_TYPES:OUTPUT_TYPES"
                          label="Type" variant="outlined" density="comfortable" class="mb-2" />
                <v-select v-if="fluidDialog.type==='intake'" v-model="fluidDialog.route" :items="FLUID_ROUTES"
                          label="Route" variant="outlined" density="comfortable" class="mb-2" />
                <v-text-field v-model.number="fluidDialog.amount" type="number" label="Amount (ml)"
                              variant="outlined" density="comfortable" suffix="ml" class="mb-2" />
              </v-card-text>
              <v-card-actions><v-spacer /><v-btn variant="text" @click="fluidDialog.show=false">Cancel</v-btn>
                <v-btn :color="fluidDialog.type==='intake'?'blue':'deep-orange'" variant="flat" @click="saveFluidEntry">Save</v-btn></v-card-actions>
            </v-card>
          </v-dialog>
        </v-window-item>

        <!-- ═══════════════ MEDICAL SUPPLIES ═══════════════ -->
        <v-window-item value="supplies">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <v-icon icon="mdi-package-variant-closed" color="orange-darken-2" size="24" />
              <span class="text-h6 font-weight-bold">Medical Supplies Ledger</span>
              <v-chip size="small" color="orange" variant="tonal">{{ supplyList.length }} tracked</v-chip>
              <v-chip size="small" color="teal" variant="tonal">{{ money(summary.supplies_total) }}</v-chip>
              <v-spacer />
              <v-btn color="orange-darken-2" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openAddSupply">Add Medical Supply</v-btn>
              <v-btn color="orange-darken-2" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="billingRefreshing" @click="refreshBilling">Refresh supplies</v-btn>
            </div>

            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="orange">
                  <v-icon icon="mdi-package-variant" color="orange-darken-2" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-orange-darken-2">{{ billableSupplyCount }}</div>
                  <div class="text-caption text-medium-emphasis">Billable items</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="teal">
                  <v-icon icon="mdi-currency-usd" color="teal" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-teal">{{ money(summary.supplies_total) }}</div>
                  <div class="text-caption text-medium-emphasis">Billable total</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-alert-outline" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ supplyAttentionItems.length }}</div>
                  <div class="text-caption text-medium-emphasis">Need attention</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="grey">
                  <v-icon icon="mdi-cash-remove" color="grey-darken-1" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-grey-darken-1">{{ nonBillableSupplyCount }}</div>
                  <div class="text-caption text-medium-emphasis">Non-billable</div>
                </v-card>
              </v-col>
            </v-row>

            <v-row dense>
              <v-col cols="12" lg="8">
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-clipboard-list" color="orange-darken-2" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Supply Register</span>
                    <v-spacer />
                    <span class="text-caption text-medium-emphasis">Category, stock use, billing status and replacement watch</span>
                  </div>
                  <v-table density="comfortable" class="cc-table">
                    <thead><tr><th>Supply</th><th>Quantity</th><th class="text-right">Unit Price</th><th class="text-right">Total</th><th>Billing</th><th>Status</th><th class="text-center">Actions</th></tr></thead>
                    <tbody>
                      <tr v-for="s in supplyList" :key="s.id">
                        <td>
                          <div class="font-weight-medium">{{ s.name }}</div>
                          <div class="text-caption text-medium-emphasis">{{ s.category_label || s.category || 'General supply' }}</div>
                        </td>
                        <td class="text-caption">{{ s.quantity }} {{ s.unit }}</td>
                        <td class="text-right text-caption">{{ money(s.unit_price) }}</td>
                        <td class="text-right font-weight-medium">{{ money(s.total_cost) }}</td>
                        <td>
                          <v-chip size="x-small" :color="s.billable ? 'teal' : 'grey'" variant="tonal" label>{{ s.billable ? 'Billable' : 'Included' }}</v-chip>
                        </td>
                        <td>
                          <v-chip size="x-small" :color="supplyUsageMeta(s.usage_status).color" variant="tonal" label>{{ supplyUsageMeta(s.usage_status).label }}</v-chip>
                          <div v-if="s.days_remaining != null" class="text-caption text-medium-emphasis mt-1">{{ s.days_remaining }} days remaining</div>
                        </td>
                        <td class="text-center">
                          <div class="d-flex ga-1 justify-center flex-wrap">
                            <v-btn size="x-small" color="cyan" variant="tonal" icon="mdi-eye-outline" @click="viewSupplyDetail(s)" title="View details" />
                            <v-btn size="x-small" color="primary" variant="tonal" icon="mdi-pencil-outline" @click="openEditSupply(s)" title="Edit supply" />
                            <v-btn v-if="s.usage_status === 'expired'" size="x-small" color="teal" variant="tonal" class="text-none" prepend-icon="mdi-refresh" :loading="supplyActionSaving && supplyActionTargetId === s.id" @click="openSupplyActionDialog('renew', s)">Renew</v-btn>
                            <v-btn v-if="s.usage_status === 'due_soon'" size="x-small" color="warning" variant="tonal" class="text-none" prepend-icon="mdi-clock-refresh" :loading="supplyActionSaving && supplyActionTargetId === s.id" @click="openSupplyActionDialog('extend', s)">Extend</v-btn>
                          </div>
                        </td>
                      </tr>
                      <tr v-if="!supplyList.length"><td colspan="7" class="text-center text-medium-emphasis py-4">No medical supplies linked to this patient yet.</td></tr>
                    </tbody>
                  </v-table>
                </v-card>
              </v-col>

              <v-col cols="12" lg="4">
                <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" color="warning">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-bell-ring-outline" color="warning" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Renewal Watchlist</span>
                  </div>
                  <div v-if="supplyAttentionItems.length" class="d-flex flex-column ga-2">
                    <div v-for="s in supplyAttentionItems.slice(0, 6)" :key="`watch-${s.id}`" class="pa-3 rounded-lg" style="background: rgba(255,255,255,0.72)">
                      <div class="d-flex align-center ga-2">
                        <span class="font-weight-medium flex-grow-1">{{ s.name }}</span>
                        <v-chip size="x-small" :color="supplyUsageMeta(s.usage_status).color" variant="tonal" label>{{ supplyUsageMeta(s.usage_status).label }}</v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis mt-1">{{ s.category_label || s.category || 'General supply' }}<span v-if="s.replace_due"> · Replace due {{ formatDate(s.replace_due) }}</span></div>
                    </div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis">No supply items currently need attention.</div>
                </v-card>

                <v-card variant="outlined" rounded="xl" class="pa-4">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-finance" color="teal" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Billing Posture</span>
                  </div>
                  <div class="d-flex flex-column ga-3">
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Billable value</span>
                      <span class="font-weight-bold text-teal">{{ money(summary.supplies_total) }}</span>
                    </div>
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Tracked cost</span>
                      <span class="font-weight-bold">{{ money(totalSupplyCost) }}</span>
                    </div>
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Coverage ratio</span>
                      <span class="font-weight-bold">{{ totalSupplyCost > 0 ? Math.round((Number(summary.supplies_total || 0) / totalSupplyCost) * 100) : 0 }}%</span>
                    </div>
                    <v-btn block color="teal" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-calculator-variant" @click="tab='billing'">Open Billing Console</v-btn>
                  </div>
                </v-card>
              </v-col>
            </v-row>

            <!-- Add Medical Supply Dialog -->
            <v-dialog v-model="addSupplyDialog" max-width="620">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-package-variant-plus" color="orange-darken-2" class="mr-2" />
                  Add Medical Supply for {{ patientName }}
                </v-card-title>
                <v-card-text>
                  <v-row dense>
                    <v-col cols="12"><v-combobox v-model="addSupplyForm.name" :items="knownSupplyNameOptions" label="Medical supply name *" variant="outlined" density="comfortable" placeholder="Choose or type a medical supply" clearable /></v-col>
                    <v-col cols="6"><v-select v-model="addSupplyForm.category" :items="SUPPLY_CATEGORIES" label="Category" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-switch v-model="addSupplyForm.billable" label="Billable" color="teal" density="compact" hide-details class="mt-2" /></v-col>
                    <v-col cols="4"><v-text-field v-model.number="addSupplyForm.quantity" type="number" label="Quantity" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="4"><v-text-field v-model="addSupplyForm.unit" label="Unit" variant="outlined" density="comfortable" placeholder="pieces, ml, etc." /></v-col>
                    <v-col cols="4"><v-text-field v-model.number="addSupplyForm.max_use_days" type="number" label="Max use (days)" variant="outlined" density="comfortable" hint="Auto-calculates replace date" persistent-hint /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="addSupplyForm.unit_price" type="number" label="Unit price" variant="outlined" density="comfortable" prefix="KSh" /></v-col>
                    <v-col cols="6"><v-text-field v-model="addSupplyForm.supplied_at" type="date" label="Supplied date" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="12"><v-textarea v-model="addSupplyForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" /></v-col>
                  </v-row>
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="addSupplyDialog = false">Cancel</v-btn>
                  <v-btn color="orange-darken-2" variant="flat" :loading="supplySaving" @click="saveSupply" prepend-icon="mdi-content-save">Add Supply</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <v-dialog v-model="supplyActionDialog" max-width="460">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon :icon="supplyActionMode === 'renew' ? 'mdi-refresh' : 'mdi-clock-refresh'" :color="supplyActionMode === 'renew' ? 'teal' : 'warning'" class="mr-2" />
                  {{ supplyActionMode === 'renew' ? 'Renew Medical Supply' : 'Extend Medical Supply' }}
                </v-card-title>
                <v-card-text>
                  <div v-if="supplyActionItem" class="mb-3">
                    <div class="font-weight-medium">{{ supplyActionItem.name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ supplyActionItem.category_label || supplyActionItem.category || 'General supply' }}<span v-if="supplyActionItem.replace_due"> · current due {{ formatDate(supplyActionItem.replace_due) }}</span></div>
                  </div>
                  <v-text-field v-model.number="supplyActionDays" type="number" min="1" label="Days to add" variant="outlined" density="comfortable" hint="Used from today for renew, added to current lifespan for extend" persistent-hint />
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="closeSupplyActionDialog">Cancel</v-btn>
                  <v-btn :color="supplyActionMode === 'renew' ? 'teal' : 'warning'" variant="flat" :loading="supplyActionSaving" @click="confirmSupplyAction">{{ supplyActionMode === 'renew' ? 'Renew' : 'Extend' }}</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- View Supply Detail Dialog -->
            <v-dialog v-model="supplyViewDialog" max-width="500">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-eye-outline" color="cyan" class="mr-2" />
                  Supply Details
                </v-card-title>
                <v-card-text v-if="supplyViewItem">
                  <v-table density="compact" class="cc-bill-table">
                    <tbody>
                      <tr><td class="font-weight-medium">Name</td><td>{{ supplyViewItem.name }}</td></tr>
                      <tr><td class="font-weight-medium">Category</td><td>{{ supplyViewItem.category_label || supplyViewItem.category || 'General' }}</td></tr>
                      <tr><td class="font-weight-medium">Quantity</td><td>{{ supplyViewItem.quantity }} {{ supplyViewItem.unit }}</td></tr>
                      <tr><td class="font-weight-medium">Unit Price</td><td>{{ money(supplyViewItem.unit_price) }}</td></tr>
                      <tr><td class="font-weight-medium">Total Cost</td><td>{{ money(supplyViewItem.total_cost) }}</td></tr>
                      <tr><td class="font-weight-medium">Billable</td><td>{{ supplyViewItem.billable ? 'Yes' : 'No' }}</td></tr>
                      <tr><td class="font-weight-medium">Supplied Date</td><td>{{ formatDate(supplyViewItem.supplied_at) }}</td></tr>
                      <tr v-if="supplyViewItem.expiry_date"><td class="font-weight-medium">Expiry Date</td><td>{{ formatDate(supplyViewItem.expiry_date) }}</td></tr>
                      <tr v-if="supplyViewItem.replace_due"><td class="font-weight-medium">Replace Due</td><td>{{ formatDate(supplyViewItem.replace_due) }}</td></tr>
                      <tr v-if="supplyViewItem.days_remaining != null"><td class="font-weight-medium">Days Remaining</td><td><v-chip size="x-small" :color="supplyUsageMeta(supplyViewItem.usage_status).color" variant="tonal" label>{{ supplyViewItem.days_remaining }} days</v-chip></td></tr>
                      <tr v-if="supplyViewItem.notes"><td class="font-weight-medium">Notes</td><td>{{ supplyViewItem.notes }}</td></tr>
                    </tbody>
                  </v-table>
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="supplyViewDialog = false">Close</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Edit Supply Dialog -->
            <v-dialog v-model="supplyEditDialog" max-width="620">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-pencil-outline" color="primary" class="mr-2" />
                  Edit Medical Supply
                </v-card-title>
                <v-card-text>
                  <v-row dense>
                    <v-col cols="12"><v-combobox v-model="supplyEditForm.name" :items="knownSupplyNameOptions" label="Medical supply name *" variant="outlined" density="comfortable" placeholder="Choose or type a medical supply" clearable /></v-col>
                    <v-col cols="6"><v-select v-model="supplyEditForm.category" :items="SUPPLY_CATEGORIES" label="Category" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-switch v-model="supplyEditForm.billable" label="Billable" color="teal" density="compact" hide-details class="mt-2" /></v-col>
                    <v-col cols="4"><v-text-field v-model.number="supplyEditForm.quantity" type="number" label="Quantity" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="4"><v-text-field v-model="supplyEditForm.unit" label="Unit" variant="outlined" density="comfortable" placeholder="pieces, ml, etc." /></v-col>
                    <v-col cols="4"><v-text-field v-model.number="supplyEditForm.max_use_days" type="number" label="Max use (days)" variant="outlined" density="comfortable" hint="Auto-calculates replace date" persistent-hint /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="supplyEditForm.unit_price" type="number" label="Unit price" variant="outlined" density="comfortable" prefix="KSh" /></v-col>
                    <v-col cols="6"><v-text-field v-model="supplyEditForm.supplied_at" type="date" label="Supplied date" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="12"><v-textarea v-model="supplyEditForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" /></v-col>
                  </v-row>
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="supplyEditDialog = false">Cancel</v-btn>
                  <v-btn color="primary" variant="flat" :loading="supplyEditSaving" @click="saveSupplyEdit" prepend-icon="mdi-content-save">Save Changes</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>
          </div>
        </v-window-item>

        <!-- ═══════════════ EQUIPMENT & DRAINS ═══════════════ -->
        <v-window-item value="equipment">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <v-icon icon="mdi-medical-bag" color="indigo" size="24" />
              <span class="text-h6 font-weight-bold">Equipment & Drain Operations</span>
              <v-chip size="small" color="indigo" variant="tonal">{{ equipmentList.length }} billed items</v-chip>
              <v-chip size="small" color="cyan-darken-2" variant="tonal">{{ activeDevices.length }} registered drains & lines</v-chip>
              <v-spacer />
              <v-btn color="indigo" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="showAddDevice = true">Register Drain & Lines</v-btn>
              <v-btn color="teal" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-account-arrow-right" @click="openAssignEquipment">Assign Equipment</v-btn>
            </div>

            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="indigo">
                  <v-icon icon="mdi-crane" color="indigo" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-indigo">{{ activeEquipmentCount }}</div>
                  <div class="text-caption text-medium-emphasis">Active hires</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="cyan">
                  <v-icon icon="mdi-cash" color="cyan-darken-2" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-cyan-darken-2">{{ money(summary.equipment_total) }}</div>
                  <div class="text-caption text-medium-emphasis">Billed total</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-timer-alert" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ deviceAttentionCount }}</div>
                  <div class="text-caption text-medium-emphasis">Need review</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="grey">
                  <v-icon icon="mdi-archive-check-outline" color="grey-darken-1" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-grey-darken-1">{{ returnedEquipmentCount }}</div>
                  <div class="text-caption text-medium-emphasis">Returned hires</div>
                </v-card>
              </v-col>
            </v-row>

            <v-row dense>
              <v-col cols="12" lg="7">
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-clipboard-text-clock-outline" color="indigo" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Equipment Billing Ledger</span>
                    <v-spacer />
                    <span class="text-caption text-medium-emphasis">Hire cycle, deposits and accrued charges</span>
                  </div>
                  <v-table density="comfortable" class="cc-table">
                    <thead><tr><th>Equipment</th><th>Period</th><th class="text-right">Rate</th><th class="text-right">Deposit</th><th class="text-right">Charge</th><th>Status</th><th class="text-center">Actions</th></tr></thead>
                    <tbody>
                      <tr v-for="e in equipmentList" :key="e.id">
                        <td>
                          <div class="font-weight-medium">{{ e.device }}</div>
                          <div class="text-caption text-medium-emphasis">Assigned {{ formatDate(e.assigned_at) }}<span v-if="e.returned_at"> · Returned {{ formatDate(e.returned_at) }}</span></div>
                        </td>
                        <td class="text-caption">{{ e.hire_period_label || 'Ad hoc' }}</td>
                        <td class="text-right text-caption">{{ e.hire_rate ? money(e.hire_rate) : '—' }}</td>
                        <td class="text-right text-caption">{{ e.deposit ? money(e.deposit) : '—' }}</td>
                        <td class="text-right font-weight-medium">{{ money(e.amount) }}</td>
                        <td><v-chip size="x-small" :color="e.active ? 'success' : 'grey'" variant="tonal" label>{{ e.active ? 'Active' : 'Returned' }}</v-chip></td>
                        <td class="text-center">
                          <div class="d-flex ga-1 justify-center">
                            <v-btn size="x-small" color="cyan" variant="tonal" icon="mdi-eye-outline" @click="viewEquipmentDetail(e)" title="View details" />
                            <v-btn size="x-small" color="primary" variant="tonal" icon="mdi-pencil-outline" @click="openEditEquipment(e)" title="Edit assignment" />
                          </div>
                        </td>
                      </tr>
                      <tr v-if="!equipmentList.length"><td colspan="7" class="text-center text-medium-emphasis py-4">No billed equipment has been assigned yet.</td></tr>
                    </tbody>
                  </v-table>
                  <!-- Pagination -->
                  <div v-if="equipmentTotalPages > 1" class="d-flex align-center justify-center ga-2 mt-3">
                    <v-btn size="x-small" variant="outlined" color="indigo" :disabled="equipmentPage <= 1" @click="equipmentPage--" icon="mdi-chevron-left" />
                    <span class="text-caption font-weight-medium">{{ equipmentPage }} / {{ equipmentTotalPages }}</span>
                    <v-btn size="x-small" variant="outlined" color="indigo" :disabled="equipmentPage >= equipmentTotalPages" @click="equipmentPage++" icon="mdi-chevron-right" />
                  </div>
                </v-card>

                <v-card variant="tonal" rounded="xl" class="pa-4" color="blue-grey">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-radar" color="blue-grey-darken-1" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Operational Watchlist</span>
                  </div>
                  <div v-if="deviceAttentionList.length" class="d-flex flex-column ga-2">
                    <div v-for="dev in deviceAttentionList" :key="`attention-${dev.id}`" class="pa-3 rounded-lg" style="background: rgba(255,255,255,0.72)">
                      <div class="d-flex align-center ga-2">
                        <span class="font-weight-medium flex-grow-1">{{ dev.name || dev.type_label }}</span>
                        <v-chip size="x-small" :color="parseFloat(deviceProgressPct(dev)) >= 100 ? 'error' : 'warning'" variant="tonal" label>{{ parseFloat(deviceProgressPct(dev)) >= 100 ? 'Overdue' : 'Due soon' }}</v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis mt-1">{{ dev.site || 'No site recorded' }} · {{ dev.daysInSitu }} days in situ</div>
                    </div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis">No device reviews are currently due.</div>
                </v-card>
              </v-col>

              <v-col cols="12" lg="5">
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-connection" color="indigo" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Drain & Line Register</span>
                  </div>
                  <div v-if="activeDevices.length" class="d-flex flex-column ga-2">
                    <v-card v-for="dev in activeDevices" :key="dev.id" variant="tonal" rounded="lg" class="pa-3 cc-device-card">
                      <div class="d-flex align-start ga-3">
                        <v-avatar :color="dev.statusColor" variant="tonal" size="42"><v-icon :icon="deviceIcon(dev.type)" /></v-avatar>
                        <div class="flex-grow-1">
                          <div class="d-flex align-center ga-2 flex-wrap mb-1">
                            <span class="font-weight-medium">{{ dev.name || dev.type_label }}</span>
                            <v-chip size="x-small" :color="dev.statusColor" variant="tonal" label>{{ dev.status_label }}</v-chip>
                          </div>
                          <div class="text-caption text-medium-emphasis">{{ dev.site ? `Site: ${dev.site}` : 'Site not recorded' }}<span v-if="dev.insert_date"> · Inserted {{ formatDate(dev.insert_date) }}</span></div>
                          <div class="text-caption text-medium-emphasis mt-1">Days in situ: <strong :class="dev.daysInSitu >= dev.maxDays ? 'text-error' : ''">{{ dev.daysInSitu }}d</strong><span v-if="dev.maxDays"> / {{ dev.maxDays }}d max</span></div>
                          <div class="cc-countdown-bar mt-2" style="max-width:220px">
                            <div class="cc-countdown-track cc-countdown-track-sm">
                              <div class="cc-countdown-fill" :style="{ width: deviceProgressPct(dev), background: deviceProgressColor(dev) }" />
                            </div>
                          </div>
                          <div class="d-flex ga-1 mt-2 flex-wrap">
                            <v-checkbox v-model="dev.dressing_intact" label="Dressing intact" density="compact" hide-details class="text-caption" />
                            <v-checkbox v-model="dev.site_clean" label="Site clean" density="compact" hide-details class="text-caption" />
                          </div>
                        </div>
                        <v-btn size="x-small" variant="text" icon="mdi-delete" color="error" @click="removeDevice(dev)" />
                      </div>
                    </v-card>
                  </div>
                  <div v-else class="text-center py-6 text-medium-emphasis">
                    <v-icon icon="mdi-medical-bag" size="48" class="mb-2" color="grey" />
                    <div class="font-weight-medium">No active devices</div>
                    <div class="text-caption">Register catheters, central lines, ventilators, and other devices.</div>
                  </div>
                </v-card>
              </v-col>
            </v-row>
            <v-dialog v-model="showAddDevice" max-width="520">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center"><v-icon icon="mdi-medical-bag" color="indigo" class="mr-2" />Register Drain / Line</v-card-title>
                <v-card-text>
                  <v-select v-model="newDevice.type" :items="DEVICE_TYPES" item-title="label" item-value="value"
                            label="Device type" variant="outlined" density="comfortable" class="mb-2" />
                  <v-text-field v-model="newDevice.name" label="Device name / ID" variant="outlined" density="comfortable" class="mb-2" />
                  <v-row dense>
                    <v-col cols="6"><v-text-field v-model="newDevice.site" label="Insertion site" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                    <v-col cols="6"><v-text-field v-model="newDevice.insert_date" type="date" label="Insertion date" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                  </v-row>
                  <v-textarea v-model="newDevice.indication" label="Indication" variant="outlined" density="comfortable" rows="2" class="mb-2" />
                </v-card-text>
                <v-card-actions><v-spacer /><v-btn variant="text" @click="showAddDevice=false">Cancel</v-btn>
                  <v-btn color="indigo" variant="flat" @click="addDevice" :loading="deviceSaving">Register</v-btn></v-card-actions>
              </v-card>
            </v-dialog>

            <!-- View Equipment Detail Dialog -->
            <v-dialog v-model="equipmentViewDialog" max-width="500">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-eye-outline" color="cyan" class="mr-2" />
                  Equipment/Device Details
                </v-card-title>
                <v-card-text v-if="equipmentViewItem">
                  <v-table density="compact" class="cc-bill-table">
                    <tbody>
                      <tr><td class="font-weight-medium">Device</td><td>{{ equipmentViewItem.device }}</td></tr>
                      <tr><td class="font-weight-medium">Hire Period</td><td>{{ equipmentViewItem.hire_period_label || 'Ad hoc' }}</td></tr>
                      <tr><td class="font-weight-medium">Hire Rate</td><td>{{ equipmentViewItem.hire_rate ? money(equipmentViewItem.hire_rate) : '—' }}</td></tr>
                      <tr><td class="font-weight-medium">Deposit</td><td>{{ equipmentViewItem.deposit ? money(equipmentViewItem.deposit) : '—' }}</td></tr>
                      <tr><td class="font-weight-medium">Total Charge</td><td>{{ money(equipmentViewItem.amount) }}</td></tr>
                      <tr><td class="font-weight-medium">Status</td><td>{{ equipmentViewItem.active ? 'Active' : 'Returned' }}</td></tr>
                      <tr><td class="font-weight-medium">Assigned Date</td><td>{{ formatDate(equipmentViewItem.assigned_at) }}</td></tr>
                      <tr v-if="equipmentViewItem.returned_at"><td class="font-weight-medium">Returned Date</td><td>{{ formatDate(equipmentViewItem.returned_at) }}</td></tr>
                    </tbody>
                  </v-table>
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="equipmentViewDialog = false">Close</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Edit Equipment Dialog -->
            <v-dialog v-model="equipmentEditDialog" max-width="540">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-pencil-outline" color="primary" class="mr-2" />
                  Edit Device Assignment
                </v-card-title>
                <v-card-text>
                  <v-text-field v-model="equipmentEditForm.device" label="Device name *" variant="outlined" density="comfortable" class="mb-2" />
                  <v-select v-model="equipmentEditForm.hire_period" :items="['daily','weekly','monthly','per_use']" label="Hire period" variant="outlined" density="comfortable" class="mb-2" clearable />
                  <v-row dense>
                    <v-col cols="6"><v-text-field v-model.number="equipmentEditForm.hire_rate" type="number" label="Hire rate" variant="outlined" density="comfortable" prefix="KSh" /></v-col>
                    <v-col cols="6"><v-text-field v-model.number="equipmentEditForm.deposit" type="number" label="Deposit" variant="outlined" density="comfortable" prefix="KSh" /></v-col>
                  </v-row>
                  <v-row dense>
                    <v-col cols="6"><v-text-field v-model="equipmentEditForm.assigned_at" type="date" label="Assigned date" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-text-field v-model="equipmentEditForm.returned_at" type="date" label="Returned date" variant="outlined" density="comfortable" clearable /></v-col>
                  </v-row>
                  <v-textarea v-model="equipmentEditForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="equipmentEditDialog = false">Cancel</v-btn>
                  <v-btn color="primary" variant="flat" :loading="equipmentEditSaving" @click="saveEquipmentEdit" prepend-icon="mdi-content-save">Save Changes</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Assign Equipment from Inventory Dialog -->
            <v-dialog v-model="showAssignEquipment" max-width="560">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center">
                  <v-icon icon="mdi-account-arrow-right" color="teal" class="mr-2" />
                  Assign Equipment to {{ patientName }}
                </v-card-title>
                <v-card-text>
                  <div class="text-caption text-medium-emphasis mb-3">
                    Assign a device from the
                    <a href="#" @click.prevent="navigateTo('/homecare/equipment')" class="text-teal font-weight-medium">Equipment Inventory</a>
                  </div>
                  <!-- Pre-populated, disabled patient field -->
                  <v-text-field :model-value="patientName" label="Patient" variant="outlined" density="comfortable" disabled class="mb-2" />
                  <!-- Device selector from inventory -->
                  <v-autocomplete v-model="assignEquipmentForm.device_id" :items="availableEquipmentList" item-title="title" item-value="value"
                    label="Select device *" variant="outlined" density="comfortable" :loading="equipmentLoading"
                    class="mb-2" placeholder="Search available devices…"
                    no-data-text="No available devices. Check the equipment inventory."
                  />
                  <v-select v-model="assignEquipmentForm.hire_period" :items="ASSIGN_HIRE_PERIODS" item-title="label" item-value="value"
                    label="Billing period" variant="outlined" density="comfortable" class="mb-2"
                    @update:model-value="assignSyncRate" />
                  <v-row dense>
                    <v-col cols="6">
                      <v-text-field v-model.number="assignEquipmentForm.hire_rate" type="number" label="Rate" variant="outlined" density="comfortable" prefix="KSh"
                        :suffix="`/ ${assignPeriodShort}`" />
                    </v-col>
                    <v-col cols="6">
                      <v-text-field v-model="assignEquipmentForm.assigned_at" type="date" label="Assignment date *" variant="outlined" density="comfortable"
                        @update:model-value="assignComputeReturn" />
                    </v-col>
                  </v-row>
                  <v-row dense>
                    <v-col cols="6">
                      <v-text-field v-model="assignEquipmentForm.expected_return_at" type="date" label="Expected return" variant="outlined" density="comfortable" />
                    </v-col>
                    <v-col cols="6">
                      <v-text-field v-model.number="assignEquipmentForm.deposit" type="number" label="Deposit (refundable)" variant="outlined" density="comfortable" prefix="KSh" />
                    </v-col>
                  </v-row>

                  <!-- Calculations sheet -->
                  <v-sheet rounded="lg" color="teal-lighten-5" class="pa-3 my-2" v-if="assignEquipmentForm.hire_rate && assignUnits > 0">
                    <div class="d-flex align-center justify-space-between">
                      <div class="text-body-2">
                        <v-icon icon="mdi-calculator-variant" size="16" class="mr-1" />
                        {{ assignUnits }} {{ assignUnitLabel }} × {{ money(assignEquipmentForm.hire_rate) }}
                      </div>
                      <div class="text-h6 font-weight-bold text-teal-darken-3">{{ money(assignEstimatedTotal) }}</div>
                    </div>
                    <div v-if="assignEquipmentForm.deposit" class="text-caption text-medium-emphasis mt-1">
                      + {{ money(assignEquipmentForm.deposit) }} refundable deposit ·
                      collect {{ money(assignEstimatedTotal + Number(assignEquipmentForm.deposit || 0)) }} up front
                    </div>
                    <div v-if="assignEquipmentForm.expected_return_at" class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-calendar-end" size="14" /> Expected return {{ formatDate(assignEquipmentForm.expected_return_at) }}
                    </div>
                  </v-sheet>

                  <v-textarea v-model="assignEquipmentForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
                </v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="showAssignEquipment = false">Cancel</v-btn>
                  <v-btn color="teal" variant="flat" :loading="assignEquipmentSaving" @click="confirmAssignEquipment" prepend-icon="mdi-check">Assign</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>
          </div>
        </v-window-item>

        <!-- ═══════════════ MEDICATION SCHEDULES ═══════════════ -->
        <v-window-item value="medications">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <v-icon icon="mdi-pill-multiple" color="pink-darken-1" size="24" />
              <span class="text-h6 font-weight-bold">Medication Schedule Monitoring</span>
              <v-chip size="small" color="pink" variant="tonal">{{ medicationList.length }} schedules</v-chip>
              <v-chip size="small" color="teal" variant="tonal">{{ money(summary.medication_total) }}</v-chip>
              <v-spacer />
              <v-btn color="pink-darken-1" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-open-in-new" to="/homecare/medications">Open Medications Module</v-btn>
            </div>

            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="pink">
                  <v-icon icon="mdi-pill" color="pink-darken-1" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-pink-darken-1">{{ activeMedicationCount }}</div>
                  <div class="text-caption text-medium-emphasis">Active schedules</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="success">
                  <v-icon icon="mdi-check-decagram" color="success" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-success">{{ takenMedicationCount }}</div>
                  <div class="text-caption text-medium-emphasis">Doses taken</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-clock-outline" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ pendingMedicationCount }}</div>
                  <div class="text-caption text-medium-emphasis">Pending doses</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" :color="missedMedicationCount > 0 ? 'error' : 'grey'">
                  <v-icon icon="mdi-alert-circle-outline" :color="missedMedicationCount > 0 ? 'error' : 'grey'" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold" :class="missedMedicationCount > 0 ? 'text-error' : 'text-grey'">{{ missedMedicationCount }}</div>
                  <div class="text-caption text-medium-emphasis">Missed doses</div>
                </v-card>
              </v-col>
            </v-row>

            <v-row dense>
              <v-col cols="12" lg="8">
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-format-list-bulleted-square" color="pink-darken-1" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Therapy Schedule Board</span>
                    <v-spacer />
                    <span class="text-caption text-medium-emphasis">Administration workload, adherence and accrued cost</span>
                  </div>
                  <v-table density="comfortable" class="cc-table">
                    <thead><tr><th>Medication</th><th>Dose / Route</th><th>Status</th><th class="text-center">Taken</th><th class="text-center">Pending</th><th class="text-center">Missed</th><th class="text-right">Cost</th></tr></thead>
                    <tbody>
                      <tr v-for="m in medicationList" :key="m.id">
                        <td>
                          <div class="font-weight-medium">{{ m.medication_name }}</div>
                          <div v-if="m.instructions" class="text-caption text-medium-emphasis">{{ m.instructions }}</div>
                        </td>
                        <td class="text-caption">{{ m.dose }} · {{ m.route_label }}</td>
                        <td><v-chip size="x-small" :color="m.is_active ? 'teal' : 'grey'" variant="tonal" label>{{ m.is_active ? 'Active' : 'Completed' }}</v-chip></td>
                        <td class="text-center"><v-chip size="x-small" color="success" variant="tonal" label>{{ m.doses_taken }}</v-chip></td>
                        <td class="text-center"><v-chip size="x-small" color="warning" variant="tonal" label>{{ m.doses_pending }}</v-chip></td>
                        <td class="text-center"><v-chip size="x-small" :color="Number(m.doses_missed) > 0 ? 'error' : 'grey'" variant="tonal" label>{{ m.doses_missed }}</v-chip></td>
                        <td class="text-right font-weight-medium">{{ m.amount ? money(m.amount) : '—' }}</td>
                      </tr>
                      <tr v-if="!medicationList.length"><td colspan="7" class="text-center text-medium-emphasis py-4">No medication schedules recorded for this patient.</td></tr>
                    </tbody>
                  </v-table>
                </v-card>
              </v-col>

              <v-col cols="12" lg="4">
                <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" :color="missedMedicationCount > 0 ? 'error' : 'info'">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-stethoscope" :color="missedMedicationCount > 0 ? 'error' : 'info'" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Clinical Attention</span>
                  </div>
                  <div v-if="medicationAttentionList.length" class="d-flex flex-column ga-2">
                    <div v-for="m in medicationAttentionList" :key="`med-${m.id}`" class="pa-3 rounded-lg" style="background: rgba(255,255,255,0.72)">
                      <div class="d-flex align-center ga-2">
                        <span class="font-weight-medium flex-grow-1">{{ m.medication_name }}</span>
                        <v-chip size="x-small" :color="Number(m.doses_missed) > 0 ? 'error' : 'warning'" variant="tonal" label>{{ Number(m.doses_missed) > 0 ? `${m.doses_missed} missed` : `${m.doses_pending} pending` }}</v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis mt-1">{{ m.dose }} · {{ m.route_label }}<span v-if="m.unit_cost"> · unit {{ money(m.unit_cost) }}</span></div>
                    </div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis">No medication schedules currently need intervention.</div>
                </v-card>

                <v-card variant="outlined" rounded="xl" class="pa-4">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-finance" color="teal" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Medication Costing</span>
                  </div>
                  <div class="d-flex flex-column ga-3">
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Accrued medication cost</span>
                      <span class="font-weight-bold text-teal">{{ money(summary.medication_total) }}</span>
                    </div>
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Schedules with unit cost</span>
                      <span class="font-weight-bold">{{ medicationList.filter(m => m.unit_cost).length }}</span>
                    </div>
                    <div class="d-flex justify-space-between align-center">
                      <span class="text-caption text-medium-emphasis">Adherence signal</span>
                      <span class="font-weight-bold">{{ takenMedicationCount + missedMedicationCount > 0 ? Math.round((takenMedicationCount / (takenMedicationCount + missedMedicationCount)) * 100) : 100 }}%</span>
                    </div>
                    <v-btn block color="teal" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-calculator-variant" @click="tab='billing'">Open Billing Console</v-btn>
                  </div>
                </v-card>
              </v-col>
            </v-row>
          </div>
        </v-window-item>

        <!-- ═══════════════ DOSES ═══════════════ -->
        <v-window-item value="doses">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <v-icon icon="mdi-pill-multiple" color="teal" size="24" />
              <span class="text-h6 font-weight-bold">Dose Administration Record</span>
              <v-chip size="small" color="teal" variant="tonal">{{ dosesFilteredCount }} dose{{ dosesFilteredCount !== 1 ? 's' : '' }}</v-chip>
              <v-spacer />
              <v-btn color="teal" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-open-in-new" to="/homecare/doses">Open Doses Module</v-btn>
            </div>

            <!-- Filters -->
            <v-row dense class="mb-4">
              <v-col cols="12" md="3">
                <v-text-field
                  v-model="doseSearch" prepend-inner-icon="mdi-magnify"
                  placeholder="Search medication…" density="compact"
                  variant="outlined" hide-details rounded="lg" clearable
                  class="cc-field"
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-select
                  v-model="doseFilterStatus" :items="doseStatusFilterOptions"
                  label="Status" density="compact" variant="outlined"
                  hide-details clearable rounded="lg"
                  prepend-inner-icon="mdi-filter-variant"
                  class="cc-field"
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-select
                  v-model="doseFilterDate" :items="doseDateFilterOptions"
                  label="Date range" density="compact" variant="outlined"
                  hide-details rounded="lg"
                  prepend-inner-icon="mdi-calendar-range"
                  class="cc-field"
                />
              </v-col>
              <v-col v-if="doseFilterDate === 'custom'" cols="12" md="3">
                <v-row dense>
                  <v-col cols="6">
                    <v-text-field v-model="doseCustomFrom" type="date" label="From"
                                  density="compact" variant="outlined" hide-details rounded="lg" class="cc-field" />
                  </v-col>
                  <v-col cols="6">
                    <v-text-field v-model="doseCustomTo" type="date" label="To"
                                  density="compact" variant="outlined" hide-details rounded="lg" class="cc-field" />
                  </v-col>
                </v-row>
              </v-col>
            </v-row>

            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="success">
                  <v-icon icon="mdi-check-circle" color="success" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-success">{{ dosesFilteredTaken }}</div>
                  <div class="text-caption text-medium-emphasis">Taken</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="info">
                  <v-icon icon="mdi-clock-outline" color="info" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-info">{{ dosesFilteredPending }}</div>
                  <div class="text-caption text-medium-emphasis">Pending</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" :color="dosesFilteredMissed > 0 ? 'error' : 'grey'">
                  <v-icon icon="mdi-alert-circle-outline" :color="dosesFilteredMissed > 0 ? 'error' : 'grey'" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold" :class="dosesFilteredMissed > 0 ? 'text-error' : 'text-grey'">{{ dosesFilteredMissed }}</div>
                  <div class="text-caption text-medium-emphasis">Missed</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-skip-next-circle" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ dosesFilteredSkipped }}</div>
                  <div class="text-caption text-medium-emphasis">Skipped</div>
                </v-card>
              </v-col>
            </v-row>

            <!-- Dose cards -->
            <div v-if="dosesFilteredList.length">
              <div v-for="d in dosesFilteredList" :key="d.id" class="cc-dose-card mb-3">
                <div class="cc-dose-card-band" :style="{ background: doseColor(d.status).hex }" />
                <div class="pa-4 pl-5">
                  <div class="d-flex align-center ga-3 flex-wrap">
                    <v-avatar size="42" class="cc-dose-card-avatar" :class="'cc-dose-card-avatar--' + d.status">
                      <v-icon :icon="doseIcon(d.status)" size="20" />
                    </v-avatar>
                    <div class="flex-grow-1 min-w-0">
                      <div class="d-flex align-center ga-2 flex-wrap mb-1">
                        <div class="text-subtitle-2 font-weight-bold cc-dose-card-title">
                          {{ d.medication_name || d.schedule_medication || 'Medication' }}
                        </div>
                        <v-chip size="x-small" class="cc-dose-card-status font-weight-bold"
                                :class="'cc-dose-card-status--' + d.status" variant="flat">
                          <v-icon :icon="doseIcon(d.status)" size="12" start />
                          {{ doseDisplay(d.status) }}
                        </v-chip>
                        <v-chip v-if="d.auto_missed" size="x-small" class="cc-dose-card-auto" variant="tonal">
                          <v-icon icon="mdi-robot" size="12" start />Auto
                        </v-chip>
                        <v-chip v-if="d.dose" size="x-small" variant="text" class="cc-dose-card-dose">
                          <v-icon icon="mdi-pill" size="12" start /> {{ d.dose }} {{ d.dose_unit }}
                        </v-chip>
                      </div>
                      <div class="d-flex flex-wrap ga-x-4 ga-y-1 cc-dose-card-meta">
                        <span class="cc-dose-card-meta-item">
                          <v-icon icon="mdi-calendar" size="13" />
                          Scheduled {{ formatFullDateTime(d.scheduled_at) }}
                        </span>
                        <span v-if="d.administered_at" class="cc-dose-card-meta-item cc-dose-card-meta-item--taken">
                          <v-icon icon="mdi-check" size="13" />
                          Given {{ formatFullDateTime(d.administered_at) }}
                        </span>
                        <span v-if="d.administered_by_name" class="cc-dose-card-meta-item">
                          <v-icon icon="mdi-account-check" size="13" />
                          by <strong>{{ d.administered_by_name }}</strong>
                        </span>
                      </div>
                      <div v-if="d.reason" class="mt-1 cc-dose-card-reason">
                        <v-icon icon="mdi-message-alert" size="12" />
                        <span>Reason: {{ d.reason }}</span>
                      </div>
                    </div>
                    <div class="d-flex ga-1 flex-wrap justify-end" style="min-width:160px;">
                      <template v-if="d.status === 'pending' || d.status === 'overdue'">
                        <v-btn size="small" class="text-none" color="success" variant="flat" rounded="lg"
                               prepend-icon="mdi-clipboard-check"
                               @click="openDoseAction(d, 'document')">Document</v-btn>
                        <v-btn size="small" class="text-none" color="warning" variant="tonal" rounded="lg"
                               prepend-icon="mdi-skip-next"
                               @click="openDoseAction(d, 'skip')">Skip</v-btn>
                        <v-btn size="small" class="text-none" color="error" variant="tonal" rounded="lg"
                               prepend-icon="mdi-cancel"
                               @click="openDoseAction(d, 'not_given')">Not given</v-btn>
                        <v-btn size="small" class="text-none" color="primary" variant="tonal" rounded="lg"
                               prepend-icon="mdi-pencil-box"
                               @click="openDoseAction(d, 'edit')">Edit</v-btn>
                      </template>
                      <template v-else>
                        <v-btn size="small" class="text-none" color="primary" variant="tonal" rounded="lg"
                               prepend-icon="mdi-pencil-box"
                               @click="openDoseAction(d, 'edit')">Edit assessment</v-btn>
                      </template>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <EmptyState v-else icon="mdi-pill-multiple" title="No doses found" message="Try a different filter or date range." />
          </div>
        </v-window-item>

        <!-- Dose Action Dialog -->
        <v-dialog v-model="doseActionDialog" max-width="560" persistent scrollable>
          <v-card v-if="doseActionTarget" rounded="xl" elevation="8">
            <div class="cc-dose-action-hero pa-5 d-flex align-center ga-4"
                 :style="{ background: `linear-gradient(135deg, ${doseActionMeta.bg} 0%, ${doseActionMeta.bg2} 100%)` }">
              <div class="cc-dose-action-hero-icon">
                <v-icon :icon="doseActionMeta.icon" size="30" color="white" />
              </div>
              <div class="text-white flex-grow-1">
                <div class="text-caption font-weight-bold text-uppercase" style="opacity:.75;">{{ doseActionMeta.eyebrow }}</div>
                <div class="text-h6 font-weight-bold">{{ doseActionMeta.title }}</div>
                <div class="text-body-2 mt-1" style="opacity:.9;">
                  {{ doseActionTarget.medication_name }}
                  <span v-if="doseActionTarget.dose"> · {{ doseActionTarget.dose }}</span>
                </div>
              </div>
            </div>
            <v-card-text class="pa-5">
              <div class="cc-dose-action-info d-flex align-center ga-2 pa-3 rounded-lg mb-4">
                <v-icon icon="mdi-information" size="18" color="teal" />
                <div class="text-caption">
                  Scheduled: <strong>{{ formatFullDateTime(doseActionTarget.scheduled_at) }}</strong>
                  <span class="mx-1">·</span>
                  Acting as <strong>{{ auth.fullName || auth.user?.email }}</strong>
                </div>
              </div>

              <div v-if="doseActionType === 'edit'" class="mb-4">
                <div class="text-overline font-weight-bold text-medium-emphasis mb-2">CHANGE STATUS</div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="opt in doseEditStatusOptions" :key="opt.value"
                          :color="doseActionStatus === opt.value ? doseColor(opt.value).vuetify : undefined"
                          :variant="doseActionStatus === opt.value ? 'flat' : 'tonal'"
                          size="small" class="text-none"
                          @click="doseActionStatus = opt.value">
                    <v-icon start :icon="doseIcon(opt.value)" size="12" />
                    {{ opt.title }}
                  </v-chip>
                </div>
              </div>

              <v-text-field v-if="doseActionType === 'edit'"
                            v-model="doseActionDose" label="Dose" density="comfortable"
                            variant="outlined" rounded="lg" prepend-inner-icon="mdi-pill"
                            :placeholder="doseActionTarget.dose || 'e.g. 500 mg'"
                            hide-details class="mb-4" />

              <v-text-field v-if="doseActionType === 'document' || (doseActionType === 'edit' && doseActionStatus === 'taken')"
                            v-model="doseActionTime" type="datetime-local"
                            label="Time given" density="comfortable" variant="outlined"
                            rounded="lg" prepend-inner-icon="mdi-clock-outline"
                            hide-details class="mb-4" />

              <v-textarea v-if="doseActionType === 'skip' || doseActionType === 'not_given' || doseActionType === 'edit'"
                          v-model="doseActionReason" label="Reason" rows="2" auto-grow
                          density="comfortable" variant="outlined" rounded="lg"
                          prepend-inner-icon="mdi-message-alert"
                          class="mb-4" />

              <v-textarea v-model="doseActionNotes" label="Notes (optional)" rows="2" auto-grow
                          density="comfortable" variant="outlined" rounded="lg"
                          prepend-inner-icon="mdi-note-text" hide-details class="mb-4" />

              <v-divider class="mb-4" />
              <div class="text-overline font-weight-bold text-medium-emphasis mb-2">VERIFY IDENTITY</div>
              <v-text-field v-model="doseActionPin" label="Your staff PIN"
                            type="password" inputmode="numeric" maxlength="12"
                            density="comfortable" variant="outlined" rounded="lg"
                            prepend-inner-icon="mdi-key"
                            @keyup.enter="submitDoseAction" hide-details />
            </v-card-text>
            <v-card-actions class="pa-5 pt-0">
              <v-spacer />
              <v-btn variant="text" rounded="lg" class="text-none font-weight-medium"
                     :disabled="doseActionBusy" @click="doseActionDialog = false">Cancel</v-btn>
              <v-btn :color="doseActionMeta.color" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                     :prepend-icon="doseActionMeta.icon" :loading="doseActionBusy"
                     @click="submitDoseAction">{{ doseActionMeta.cta }}</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <!-- ═══════════════ BILLING ═══════════════ -->
        <v-window-item value="billing">
          <div class="pa-4">
            <!-- Top KPIs -->
            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="teal">
                  <v-icon icon="mdi-cash-multiple" color="teal" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold">{{ money(summary.subtotal) }}</div>
                  <div class="text-caption text-medium-emphasis">Cost to date</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="green">
                  <v-icon icon="mdi-cash-check" color="green" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-success">{{ money(summary.total_paid) }}</div>
                  <div class="text-caption text-medium-emphasis">Total paid</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" :color="Number(summary.balance) > 0 ? 'red' : 'grey'">
                  <v-icon icon="mdi-scale-balance" :color="Number(summary.balance) > 0 ? 'error' : 'grey'" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold" :class="Number(summary.balance) > 0 ? 'text-error' : ''">{{ money(summary.balance) }}</div>
                  <div class="text-caption text-medium-emphasis">Balance</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="purple">
                  <v-icon icon="mdi-calendar-clock" color="purple" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-purple">{{ billingPlanLabel }}</div>
                  <div class="text-caption text-medium-emphasis">Plan</div>
                </v-card>
              </v-col>
            </v-row>

            <!-- Quick actions + Date filters -->
            <div class="d-flex ga-2 mb-4 flex-wrap align-center">
              <v-btn color="teal" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-receipt-text-plus" @click="openGenerateBill">Generate Bill</v-btn>
              <v-btn color="success" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-cash-plus" @click="openRecordPayment()">Record Payment</v-btn>
              <v-btn color="purple" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-calendar-clock" @click="openPlanDialog">{{ carePlanData ? 'Change Plan' : 'Set Plan' }}</v-btn>
              <v-btn color="deep-purple" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-download" @click="printCostBreakdown">Download Summary</v-btn>
              <v-spacer />
              <!-- Date filters -->
              <v-btn-toggle v-model="billDateFilter" density="compact" rounded="lg" color="teal" variant="outlined" mandatory class="cc-date-toggle">
                <v-btn value="all" size="x-small" class="text-none px-2">All</v-btn>
                <v-btn value="today" size="x-small" class="text-none px-2">Today</v-btn>
                <v-btn value="yesterday" size="x-small" class="text-none px-2">Yesterday</v-btn>
                <v-btn value="7d" size="x-small" class="text-none px-2">7 Days</v-btn>
                <v-btn value="30d" size="x-small" class="text-none px-2">30 Days</v-btn>
                <v-btn value="custom" size="x-small" class="text-none px-2">Custom</v-btn>
              </v-btn-toggle>
              <v-btn size="small" variant="text" color="teal" class="text-none" :loading="billingRefreshing" @click="refreshBilling" prepend-icon="mdi-refresh">Refresh</v-btn>
            </div>

            <!-- Custom date range -->
            <div v-if="billDateFilter === 'custom'" class="d-flex align-center ga-3 mb-4 flex-wrap">
              <v-text-field v-model="billDateFrom" type="date" label="From" density="compact" variant="outlined" hide-details style="max-width:180px" />
              <v-text-field v-model="billDateTo" type="date" label="To" density="compact" variant="outlined" hide-details style="max-width:180px" />
              <v-btn size="small" color="teal" variant="tonal" class="text-none" @click="applyCustomDateFilter">Apply</v-btn>
            </div>

            <v-row dense>
              <!-- LEFT: Bills + Line Items -->
              <v-col cols="12" md="8">
                <!-- Cost Breakdown Card -->
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-chart-pie" color="teal" size="18" class="mr-1" />
                    <span class="text-subtitle-2 font-weight-bold">Cost Breakdown</span>
                    <v-spacer />
                    <v-btn size="x-small" variant="text" color="deep-purple" class="text-none" prepend-icon="mdi-download" @click="printCostBreakdown">Download</v-btn>
                  </div>
                  <v-table density="compact" class="cc-bill-table">
                    <thead><tr><th>Category</th><th class="text-right">Amount</th><th class="text-right">%</th></tr></thead>
                    <tbody>
                      <tr><td><v-icon icon="mdi-hand-heart" size="14" class="mr-2 text-teal" />Care Plan</td><td class="text-right">{{ money(summary.care_total) }}</td><td class="text-right">{{ billingPct(summary.care_total) }}%</td></tr>
                      <tr v-if="Number(summary.equipment_total) > 0"><td><v-icon icon="mdi-medical-bag" size="14" class="mr-2 text-indigo" />Equipment</td><td class="text-right">{{ money(summary.equipment_total) }}</td><td class="text-right">{{ billingPct(summary.equipment_total) }}%</td></tr>
                      <tr v-if="Number(summary.supplies_total) > 0"><td><v-icon icon="mdi-package-variant" size="14" class="mr-2 text-orange" />Supplies</td><td class="text-right">{{ money(summary.supplies_total) }}</td><td class="text-right">{{ billingPct(summary.supplies_total) }}%</td></tr>
                      <tr v-if="Number(summary.medication_total) > 0"><td><v-icon icon="mdi-pill" size="14" class="mr-2 text-pink" />Medications</td><td class="text-right">{{ money(summary.medication_total) }}</td><td class="text-right">{{ billingPct(summary.medication_total) }}%</td></tr>
                      <tr class="font-weight-bold"><td>Subtotal</td><td class="text-right">{{ money(summary.subtotal) }}</td><td class="text-right">100%</td></tr>
                      <tr class="text-success"><td>Paid</td><td class="text-right">{{ money(summary.total_paid) }}</td><td class="text-right">{{ billingPct(summary.total_paid, summary.subtotal) }}%</td></tr>
                      <tr class="font-weight-bold" :class="Number(summary.balance) > 0 ? 'text-error' : 'text-success'">
                        <td>Balance</td><td class="text-right">{{ money(summary.balance) }}</td><td class="text-right">{{ billingPct(summary.balance, summary.subtotal) }}%</td>
                      </tr>
                    </tbody>
                  </v-table>
                </v-card>

                <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" color="blue-grey">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-view-grid-plus" color="blue-grey-darken-1" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Clinical Resource Ledgers</span>
                  </div>
                  <div class="text-caption text-medium-emphasis mb-3">Detailed operational and billing views for supplies, equipment/devices, and medication schedules now live in their own tabs.</div>
                  <div class="d-flex ga-2 flex-wrap">
                    <v-btn size="small" color="orange-darken-2" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-package-variant" @click="tab='supplies'">Supplies</v-btn>
                    <v-btn size="small" color="indigo" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-medical-bag" @click="tab='equipment'">Equipment</v-btn>
                    <v-btn size="small" color="pink-darken-1" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-pill" @click="tab='medications'">Medications</v-btn>
                  </div>
                </v-card>

                <!-- Bills List (Expandable) -->
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-receipt-text" color="cyan-darken-2" size="18" class="mr-1" />
                    <span class="text-subtitle-2 font-weight-bold">Bills</span>
                    <v-spacer />
                    <v-chip size="x-small" color="cyan-darken-2" variant="tonal">{{ filteredBills.length }}</v-chip>
                  </div>
                  <div v-if="filteredBills.length" class="d-flex flex-column ga-2">
                    <div v-for="b in filteredBills" :key="b.id">
                      <!-- Bill Row -->
                      <div class="d-flex align-center ga-2 pa-3 rounded-lg cc-bill-row" @click="toggleBillExpand(b.id)" style="cursor:pointer">
                        <v-btn size="x-small" variant="text" :icon="expandedBillId === b.id ? 'mdi-chevron-up' : 'mdi-chevron-down'" class="mr-1" />
                        <div class="flex-grow-1">
                          <div class="text-body-2 font-weight-medium">{{ b.bill_number }}</div>
                          <div class="text-caption text-medium-emphasis">{{ formatDate(b.as_of) }} · {{ b.status_label || b.status }}</div>
                        </div>
                        <div class="text-right mr-3">
                          <div class="font-weight-bold">{{ money(b.total) }}</div>
                          <div class="text-caption" :class="Number(b.balance) > 0 ? 'text-error' : 'text-success'">bal {{ money(b.balance) }}</div>
                        </div>
                        <v-chip size="x-small" :color="b.status === 'paid' ? 'success' : b.status === 'void' ? 'grey' : 'warning'" variant="tonal" label>{{ b.status_label || b.status }}</v-chip>
                        <v-btn size="x-small" variant="text" icon="mdi-eye" color="cyan-darken-2" @click.stop="viewBillDetail(b)" />
                        <v-btn size="x-small" variant="text" icon="mdi-download" color="deep-purple" @click.stop="printBill(b)" />
                      </div>
                      <!-- Expanded Detail -->
                      <div v-if="expandedBillId === b.id" class="cc-bill-expand pa-4 mt-1 mb-2 rounded-lg">
                        <div class="d-flex flex-wrap ga-4 mb-3">
                          <div><div class="text-caption text-medium-emphasis">Bill Number</div><div class="font-weight-medium">{{ b.bill_number }}</div></div>
                          <div><div class="text-caption text-medium-emphasis">Date</div><div class="font-weight-medium">{{ formatDate(b.as_of) }}</div></div>
                          <div><div class="text-caption text-medium-emphasis">Status</div><v-chip size="x-small" :color="b.status==='paid'?'success':b.status==='void'?'grey':'warning'" variant="tonal" label>{{ b.status_label || b.status }}</v-chip></div>
                          <div><div class="text-caption text-medium-emphasis">Subtotal</div><div class="font-weight-medium">{{ money(b.subtotal) }}</div></div>
                          <div v-if="Number(b.discount) > 0"><div class="text-caption text-medium-emphasis">Discount</div><div class="font-weight-medium text-error">-{{ money(b.discount) }}</div></div>
                          <div v-if="Number(b.tax) > 0"><div class="text-caption text-medium-emphasis">Tax</div><div class="font-weight-medium">{{ money(b.tax) }}</div></div>
                          <div><div class="text-caption text-medium-emphasis">Total</div><div class="font-weight-bold">{{ money(b.total) }}</div></div>
                          <div><div class="text-caption text-medium-emphasis">Paid</div><div class="font-weight-bold text-success">{{ money(b.amount_paid) }}</div></div>
                          <div><div class="text-caption text-medium-emphasis">Balance</div><div class="font-weight-bold" :class="Number(b.balance) > 0 ? 'text-error' : 'text-success'">{{ money(b.balance) }}</div></div>
                        </div>
                        <!-- Bill line items if available -->
                        <div v-if="(b.line_items || []).length" class="mb-3">
                          <div class="text-caption font-weight-bold mb-1">Line Items</div>
                          <v-table density="compact">
                            <thead><tr><th>Description</th><th class="text-center">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr></thead>
                            <tbody>
                              <tr v-for="(li, i) in b.line_items" :key="i">
                                <td class="text-body-2">{{ li.label }}</td>
                                <td class="text-center text-caption">{{ li.qty }} {{ li.unit || '' }}</td>
                                <td class="text-right text-caption">{{ li.rate ? money(li.rate) : '—' }}</td>
                                <td class="text-right font-weight-medium">{{ money(li.amount) }}</td>
                              </tr>
                            </tbody>
                          </v-table>
                        </div>
                        <!-- Payments applied -->
                        <div v-if="(b.payments || []).length">
                          <div class="text-caption font-weight-bold mb-1">Payments Applied ({{ b.payments.length }})</div>
                          <div v-for="p in b.payments" :key="p.id" class="d-flex align-center ga-2 pa-2 rounded-lg cc-payment-row mb-1">
                            <v-icon icon="mdi-cash" color="success" size="16" />
                            <span class="font-weight-medium text-success">{{ money(p.amount) }}</span>
                            <v-chip size="x-small" color="success" variant="tonal" label>{{ p.method_label }}</v-chip>
                            <span class="text-caption text-medium-emphasis">{{ formatDate(p.paid_at) }}</span>
                            <span v-if="p.reference" class="text-caption text-medium-emphasis">Ref: {{ p.reference }}</span>
                          </div>
                        </div>
                        <div v-if="b.notes" class="text-caption mt-2"><v-icon icon="mdi-note-text" size="14" class="mr-1" />{{ b.notes }}</div>
                        <div class="d-flex ga-2 mt-3">
                          <v-btn v-if="b.status !== 'paid' && b.status !== 'void'" size="small" color="success" variant="tonal" class="text-none" prepend-icon="mdi-cash-plus" @click="openRecordPayment(b)">Record Payment</v-btn>
                          <v-btn size="small" color="deep-purple" variant="tonal" class="text-none" prepend-icon="mdi-download" @click="printBill(b)">Download</v-btn>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis py-2">No bills {{ billDateFilter !== 'all' ? 'in selected period' : 'generated yet' }}.</div>
                </v-card>

                <!-- Line Items with summary -->
                <v-card v-if="(summary.line_items || []).length" variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-format-list-bulleted" color="teal" size="18" class="mr-1" />
                    <span class="text-subtitle-2 font-weight-bold">Line Items</span>
                    <span class="text-caption text-medium-emphasis ml-2">({{ summary.line_items.length }} items)</span>
                    <v-spacer />
                    <v-btn size="x-small" variant="text" color="deep-purple" class="text-none" prepend-icon="mdi-download" @click="printLineItems">Download</v-btn>
                  </div>
                  <v-table density="compact">
                    <thead><tr><th>Description</th><th class="text-center">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr></thead>
                    <tbody>
                      <tr v-for="(li, idx) in summary.line_items" :key="idx">
                        <td class="text-body-2">{{ li.label }}</td>
                        <td class="text-center text-caption">{{ li.qty }} {{ li.unit || '' }}</td>
                        <td class="text-right text-caption">{{ li.rate ? money(li.rate) : '—' }}</td>
                        <td class="text-right font-weight-medium">{{ money(li.amount) }}</td>
                      </tr>
                    </tbody>
                  </v-table>
                  <div class="d-flex justify-end mt-2">
                    <div class="text-body-1 font-weight-bold">Subtotal: {{ money(summary.subtotal) }}</div>
                  </div>
                </v-card>
              </v-col>

              <!-- RIGHT: Payment Plan + Payments -->
              <v-col cols="12" md="4">
                <!-- Payment Plan -->
                <v-card variant="outlined" rounded="xl" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-calendar-clock" color="purple" size="18" class="mr-1" />
                    <span class="text-subtitle-2 font-weight-bold">Payment Plan</span>
                    <v-spacer />
                    <v-btn size="small" variant="text" color="purple" class="text-none" @click="openPlanDialog">{{ carePlanData ? 'Edit' : 'Set' }}</v-btn>
                  </div>
                  <div v-if="carePlanData" class="d-flex flex-wrap ga-4">
                    <div><div class="text-caption text-medium-emphasis">Type</div><div class="font-weight-bold">{{ carePlanData.plan_type_label }}</div></div>
                    <div><div class="text-caption text-medium-emphasis">Rate</div><div class="font-weight-bold">{{ money(carePlanData.rate) }}</div></div>
                    <div><div class="text-caption text-medium-emphasis">Units</div><div class="font-weight-bold">{{ carePlanData.units }}</div></div>
                    <div><div class="text-caption text-medium-emphasis">Cost to date</div><div class="font-weight-bold text-teal-darken-2">{{ money(carePlanData.cost) }}</div></div>
                    <div><div class="text-caption text-medium-emphasis">Auto-bill</div>
                      <v-chip size="x-small" :color="carePlanData.auto_bill ? 'teal' : 'grey'" variant="tonal" label>{{ carePlanData.auto_bill ? 'ON' : 'PAUSED' }}</v-chip>
                    </div>
                    <div><div class="text-caption text-medium-emphasis">Since</div><div class="font-weight-medium">{{ formatDate(carePlanData.start_date) }}</div></div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis py-2">No payment plan set. A plan is required for auto-billing.</div>
                </v-card>

                <!-- Payments List -->
                <v-card variant="outlined" rounded="xl" class="pa-4">
                  <div class="d-flex align-center mb-2">
                    <v-icon icon="mdi-cash-check" color="success" size="18" class="mr-1" />
                    <span class="text-subtitle-2 font-weight-bold">Recent Payments</span>
                    <v-spacer />
                    <v-chip size="x-small" color="success" variant="tonal">{{ (summary.payments || []).length }}</v-chip>
                  </div>
                  <div v-if="(summary.payments || []).length" class="d-flex flex-column ga-2">
                    <div v-for="p in (summary.payments || []).slice(0, 8)" :key="p.id" class="d-flex align-center ga-2 pa-2 rounded-lg cc-payment-row">
                      <v-avatar size="32" color="success" variant="tonal"><v-icon icon="mdi-cash" size="16" /></v-avatar>
                      <div class="flex-grow-1">
                        <div class="text-body-2 font-weight-medium text-success">{{ money(p.amount) }}</div>
                        <div class="text-caption text-medium-emphasis">{{ formatDate(p.paid_at) }} · {{ p.method_label }}</div>
                      </div>
                      <span class="text-caption text-medium-emphasis">{{ p.reference || '' }}</span>
                    </div>
                  </div>
                  <div v-else class="text-caption text-medium-emphasis py-2">No payments recorded yet.</div>
                </v-card>
              </v-col>
            </v-row>
          </div>
        </v-window-item>

        <!-- ═══════════════ NOTES ═══════════════ -->
        <v-window-item value="notes">
          <div class="pa-4">
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <div class="d-flex align-center ga-3 flex-grow-1">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#6366f1,#4f46e5);">
                  <v-icon icon="mdi-note-edit" size="18" />
                </div>
                <div>
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Care Notes</h3>
                  <div class="text-caption text-medium-emphasis">Doctor & Nurse/HCA notes for this patient</div>
                </div>
              </div>
              <v-btn color="indigo" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                     prepend-icon="mdi-plus" @click="navigateTo('/homecare/notes/new')">New Note</v-btn>
            </div>

            <v-row dense>
              <v-col cols="12" md="6">
                <v-card rounded="xl" variant="tonal" color="deep-purple" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-doctor" color="deep-purple" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Doctor Notes</span>
                    <v-spacer />
                    <v-chip size="x-small" color="deep-purple" variant="tonal" label>{{ doctorNotes.length }}</v-chip>
                  </div>
                  <div v-if="doctorNotes.length" class="d-flex flex-column ga-2" style="max-height:500px; overflow-y:auto;">
                    <v-card v-for="n in doctorNotes" :key="n.id" variant="outlined" rounded="lg" class="pa-3">
                      <div class="d-flex align-center ga-2 mb-1">
                        <v-icon icon="mdi-doctor" size="16" color="deep-purple" />
                        <span class="text-caption font-weight-medium">{{ n.caregiver_name || 'Doctor' }}</span>
                        <v-spacer />
                        <span class="text-caption text-medium-emphasis">{{ formatShortDateTime(n.recorded_at) }}</span>
                      </div>
                      <div class="text-body-2 mb-2" v-html="renderNoteHtml(n.content)"></div>
                      <div class="d-flex ga-1 flex-wrap" v-if="n.vitals && Object.keys(n.vitals).length">
                        <v-chip v-for="(v,k) in n.vitals" :key="k" size="x-small" variant="tonal" color="grey" label>{{ k }}: {{ v }}</v-chip>
                      </div>
                    </v-card>
                  </div>
                  <div v-else class="text-center py-6 text-medium-emphasis">
                    <v-icon icon="mdi-doctor" size="40" class="mb-2" color="grey" />
                    <div class="font-weight-medium">No doctor notes</div>
                    <div class="text-caption">Doctor notes for this patient will appear here.</div>
                  </div>
                </v-card>
              </v-col>
              <v-col cols="12" md="6">
                <v-card rounded="xl" variant="tonal" color="teal" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-nurse" color="teal" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Nurse / HCA Notes</span>
                    <v-spacer />
                    <v-chip size="x-small" color="teal" variant="tonal" label>{{ nurseNotes.length }}</v-chip>
                  </div>
                  <div v-if="nurseNotes.length" class="d-flex flex-column ga-2" style="max-height:500px; overflow-y:auto;">
                    <v-card v-for="n in nurseNotes" :key="n.id" variant="outlined" rounded="lg" class="pa-3">
                      <div class="d-flex align-center ga-2 mb-1">
                        <v-icon icon="mdi-nurse" size="16" color="teal" />
                        <span class="text-caption font-weight-medium">{{ n.caregiver_name || 'Nurse/HCA' }}</span>
                        <v-spacer />
                        <span class="text-caption text-medium-emphasis">{{ formatShortDateTime(n.recorded_at) }}</span>
                      </div>
                      <div class="text-body-2 mb-2" v-html="renderNoteHtml(n.content)"></div>
                      <div class="d-flex ga-1 flex-wrap" v-if="n.vitals && Object.keys(n.vitals).length">
                        <v-chip v-for="(v,k) in n.vitals" :key="k" size="x-small" variant="tonal" color="grey" label>{{ k }}: {{ v }}</v-chip>
                      </div>
                    </v-card>
                  </div>
                  <div v-else class="text-center py-6 text-medium-emphasis">
                    <v-icon icon="mdi-nurse" size="40" class="mb-2" color="grey" />
                    <div class="font-weight-medium">No nurse/HCA notes</div>
                    <div class="text-caption">Nurse & HCA notes for this patient will appear here.</div>
                  </div>
                </v-card>
              </v-col>
            </v-row>
          </div>
        </v-window-item>

        <!-- ═══════════════ TREATMENT PLAN ═══════════════ -->
        <v-window-item value="treatment-plan">
          <div class="pa-4">
            <!-- Header -->
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <div class="d-flex align-center ga-3 flex-grow-1">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#7c3aed,#6d28d9);">
                  <v-icon icon="mdi-clipboard-text-outline" size="18" />
                </div>
                <div>
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Treatment Plan</h3>
                  <div class="text-caption text-medium-emphasis">Diagnosis, goals, medications, and progress tracking</div>
                </div>
              </div>
              <v-btn color="purple" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                     prepend-icon="mdi-plus" @click="openTpCreateDialog">
                New Plan
              </v-btn>
            </div>

            <!-- Stats cards -->
            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="success">
                  <v-icon icon="mdi-check-circle" color="success" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-success">{{ activeTreatmentPlans.length }}</div>
                  <div class="text-caption text-medium-emphasis">Active Plans</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-pause-circle" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ pausedTreatmentPlans.length }}</div>
                  <div class="text-caption text-medium-emphasis">Paused</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="teal">
                  <v-icon icon="mdi-pill" color="teal" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-teal">{{ totalMedicationSchedules }}</div>
                  <div class="text-caption text-medium-emphasis">Medication Schedules</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="grey">
                  <v-icon icon="mdi-flag-checkered" color="grey-darken-1" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-grey-darken-1">{{ completedTreatmentPlans.length }}</div>
                  <div class="text-caption text-medium-emphasis">Completed</div>
                </v-card>
              </v-col>
            </v-row>

            <v-row dense>
              <!-- Plan list -->
              <v-col cols="12" lg="7">
                <v-card rounded="xl" variant="outlined" class="pa-4 mb-3">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-clipboard-list" color="purple" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Treatment Plans</span>
                    <v-spacer />
                    <v-btn size="x-small" variant="text" color="purple" class="text-none" @click="loadTreatmentPlans" :loading="treatmentPlansLoading">
                      <v-icon icon="mdi-refresh" size="16" class="mr-1" />Refresh
                    </v-btn>
                  </div>

                  <div v-if="treatmentPlans.length" class="d-flex flex-column ga-3">
                    <v-card v-for="plan in treatmentPlans" :key="plan.id" variant="tonal" rounded="lg" class="pa-4" color="purple">
                      <div class="d-flex align-start ga-3">
                        <v-avatar size="48" color="purple" variant="tonal" rounded="lg">
                          <v-icon icon="mdi-clipboard-text" size="24" />
                        </v-avatar>
                        <div class="flex-grow-1">
                          <div class="d-flex align-center ga-2 flex-wrap mb-1">
                            <span class="text-subtitle-2 font-weight-bold">{{ plan.title }}</span>
                            <v-chip size="x-small" :color="tpStatusColor(plan.status)" variant="flat" class="font-weight-bold text-white">
                              {{ tpStatusLabel(plan.status) }}
                            </v-chip>
                            <v-chip v-if="plan.medication_count" size="x-small" color="purple" variant="tonal" label>
                              <v-icon icon="mdi-pill" start size="12" />{{ plan.medication_count }} meds
                            </v-chip>
                          </div>
                          <div v-if="plan.diagnosis" class="text-body-2 text-medium-emphasis mb-1">{{ plan.diagnosis }}</div>

                          <!-- Dates row -->
                          <div class="d-flex align-center ga-4 flex-wrap text-caption text-medium-emphasis mb-2">
                            <span><v-icon icon="mdi-calendar-start" size="14" class="mr-1" />{{ formatDate(plan.start_date) }}</span>
                            <span v-if="plan.end_date"><v-icon icon="mdi-calendar-end" size="14" class="mr-1" />{{ formatDate(plan.end_date) }}</span>
                          </div>

                          <!-- Goals -->
                          <div v-if="plan.goals && plan.goals.length" class="mb-2">
                            <div class="text-caption font-weight-bold mb-1">Goals</div>
                            <div class="d-flex flex-wrap ga-1">
                              <v-chip v-for="(g, gi) in plan.goals" :key="gi" size="x-small" variant="tonal" color="teal" label>
                                <v-icon icon="mdi-target" start size="10" />{{ typeof g === 'string' ? g : g.text || g.goal || '' }}
                              </v-chip>
                            </div>
                          </div>

                          <!-- Expandable medications -->
                          <v-expansion-panels v-if="tpMedicationsMap[plan.id] && tpMedicationsMap[plan.id].length" variant="accordion" class="mt-2">
                            <v-expansion-panel rounded="lg" color="purple-lighten-5">
                              <v-expansion-panel-title class="text-caption font-weight-bold">
                                <v-icon icon="mdi-pill" size="14" class="mr-1" color="purple" />
                                Medication Schedules ({{ tpMedicationsMap[plan.id].length }})
                              </v-expansion-panel-title>
                              <v-expansion-panel-text>
                                <div class="d-flex flex-column ga-2">
                                  <div v-for="med in tpMedicationsMap[plan.id]" :key="med.id"
                                       class="d-flex align-center justify-space-between ga-2 pa-2 rounded-lg"
                                       style="background:rgba(124,58,237,0.06);">
                                    <div>
                                      <div class="text-body-2 font-weight-medium">{{ med.medication_name }}</div>
                                      <div class="text-caption text-medium-emphasis">
                                        {{ med.dose }} · {{ med.route }} ·
                                        {{ med.frequency_cron || (med.times_of_day || []).join(', ') || 'As needed' }}
                                      </div>
                                    </div>
                                    <div class="d-flex align-center ga-2 flex-shrink-0">
                                      <v-chip size="x-small" :color="med.is_active ? 'success' : 'grey'" variant="tonal" label>
                                        {{ med.is_active ? 'Active' : 'Inactive' }}
                                      </v-chip>
                                      <span class="text-caption text-medium-emphasis">{{ med.upcoming_doses || 0 }} pending</span>
                                    </div>
                                  </div>
                                </div>
                              </v-expansion-panel-text>
                            </v-expansion-panel>
                          </v-expansion-panels>

                          <div class="d-flex ga-2 mt-3">
                            <v-btn size="x-small" color="purple" variant="flat" rounded="lg" class="text-none"
                                   @click="openTpViewDialog(plan)">View</v-btn>
                            <v-btn size="x-small" color="purple" variant="tonal" rounded="lg" class="text-none"
                                   @click="openTpEditDialog(plan)">Edit</v-btn>
                          </div>
                        </div>
                      </div>
                    </v-card>
                  </div>

                  <div v-else class="text-center py-8 text-medium-emphasis">
                    <v-icon icon="mdi-clipboard-text-outline" size="48" class="mb-3" color="grey" />
                    <div class="font-weight-medium">No treatment plans</div>
                    <div class="text-caption mb-3">Create a treatment plan to define care goals and medication schedules.</div>
                    <v-btn color="purple" variant="tonal" rounded="lg" class="text-none"
                           @click="navigateTo('/homecare/treatment-plans/new')">
                      <v-icon icon="mdi-plus" start size="16" />Create First Plan
                    </v-btn>
                  </div>
                </v-card>
              </v-col>

              <!-- Side panel -->
              <v-col cols="12" lg="5">
                <!-- Active medications overview -->
                <v-card rounded="xl" variant="tonal" class="pa-4 mb-3" color="purple">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-pill-multiple" color="purple" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Active Medications</span>
                    <v-spacer />
                    <v-chip size="x-small" color="purple" variant="tonal" label>{{ activeMedicationSchedules.length }} active</v-chip>
                  </div>
                  <div v-if="activeMedicationSchedules.length" class="d-flex flex-column ga-2">
                    <div v-for="med in activeMedicationSchedules.slice(0, 8)" :key="med.id"
                         class="d-flex align-center ga-3 pa-3 rounded-lg" style="background:rgba(124,58,237,0.06);">
                      <v-avatar size="36" color="purple" variant="tonal">
                        <v-icon icon="mdi-pill" size="18" />
                      </v-avatar>
                      <div class="flex-grow-1 min-w-0">
                        <div class="text-body-2 font-weight-medium text-truncate">{{ med.medication_name }}</div>
                        <div class="text-caption text-medium-emphasis">{{ med.dose }} · {{ med.route_label || med.route }}</div>
                      </div>
                      <div class="text-right flex-shrink-0">
                        <div class="text-caption font-weight-bold" :class="med.is_active ? 'text-success' : 'text-grey'">
                          {{ med.upcoming_doses || 0 }} due
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          {{ med.frequency_cron || (med.times_of_day || []).slice(0, 2).join(', ') }}
                        </div>
                      </div>
                    </div>
                  </div>
                  <div v-else class="text-center py-3 text-medium-emphasis text-caption">No active medication schedules.</div>
                </v-card>

                <!-- Quick plan stats -->
                <v-card rounded="xl" variant="outlined" class="pa-4">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-chart-box-outline" color="purple" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Plan Summary</span>
                  </div>
                  <div class="d-flex flex-column ga-2">
                    <div class="d-flex justify-space-between text-body-2">
                      <span class="text-medium-emphasis">Total plans</span>
                      <span class="font-weight-bold">{{ treatmentPlans.length }}</span>
                    </div>
                    <div class="d-flex justify-space-between text-body-2">
                      <span class="text-medium-emphasis">Active medication schedules</span>
                      <span class="font-weight-bold text-success">{{ activeMedicationSchedules.length }}</span>
                    </div>
                    <div class="d-flex justify-space-between text-body-2">
                      <span class="text-medium-emphasis">Pending doses</span>
                      <span class="font-weight-bold text-warning">{{ totalPendingDoses }}</span>
                    </div>
                    <v-divider class="my-1" />
                    <div class="d-flex justify-space-between text-body-2">
                      <span class="text-medium-emphasis">Caregivers assigned</span>
                      <span class="font-weight-bold">{{ summary?.caregivers?.primary?.name || '—' }}</span>
                    </div>
                  </div>
                  <v-btn block color="purple" variant="tonal" rounded="lg" class="text-none mt-3"
                         @click="navigateTo('/homecare/treatment-plans')">
                    <v-icon icon="mdi-open-in-new" start size="16" />Open Treatment Plans
                  </v-btn>
                </v-card>
              </v-col>
            </v-row>
          </div>
        </v-window-item>

        <!-- ═══════════════ TREATMENT PLAN VIEW / EDIT DIALOG ═══════════════ -->
        <v-dialog v-model="tpViewDialog" max-width="800" scrollable>
          <v-card rounded="xl">
            <v-card-title class="d-flex align-center" style="background:linear-gradient(135deg,#7c3aed,#6d28d9);">
              <v-icon icon="mdi-clipboard-text-outline" color="white" class="mr-2" />
              <span class="text-white font-weight-bold">{{ tpSelected?.title || 'Treatment Plan' }}</span>
              <v-spacer />
              <v-chip v-if="tpSelected" size="x-small" :color="tpStatusColor(tpSelected.status)" variant="flat" class="font-weight-bold text-white">
                {{ tpStatusLabel(tpSelected.status) }}
              </v-chip>
              <v-btn icon="mdi-close" variant="text" color="white" class="ml-2" @click="tpViewDialog = false" />
            </v-card-title>
            <v-card-text class="pa-0" v-if="tpSelected">
              <v-tabs v-model="tpDetailTab" color="purple" grow>
                <v-tab value="overview"><v-icon icon="mdi-view-dashboard" class="mr-1" size="16" />Overview</v-tab>
                <v-tab value="meds"><v-icon icon="mdi-pill" class="mr-1" size="16" />Medications</v-tab>
                <v-tab value="goals"><v-icon icon="mdi-target" class="mr-1" size="16" />Goals</v-tab>
                <v-tab value="edit" v-if="tpEditMode"><v-icon icon="mdi-pencil" class="mr-1" size="16" />Edit Plan</v-tab>
              </v-tabs>
              <v-divider />

              <v-window v-model="tpDetailTab" class="pa-5">
                <!-- Overview -->
                <v-window-item value="overview">
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" color="purple" variant="tonal">
                      <v-icon icon="mdi-calendar-start" size="14" class="mr-1" />{{ formatDate(tpSelected.start_date) }}
                    </v-chip>
                    <v-chip v-if="tpSelected.end_date" size="small" color="purple" variant="tonal">
                      <v-icon icon="mdi-calendar-end" size="14" class="mr-1" />{{ formatDate(tpSelected.end_date) }}
                    </v-chip>
                    <v-chip size="small" color="purple" variant="tonal">
                      <v-icon icon="mdi-pill" size="14" class="mr-1" />{{ (tpMedicationsMap[tpSelected.id] || []).length }} medications
                    </v-chip>
                    <v-chip size="small" color="purple" variant="tonal">
                      <v-icon icon="mdi-target" size="14" class="mr-1" />{{ (tpSelected.goals || []).length }} goals
                    </v-chip>
                  </div>
                  <v-row dense>
                    <v-col cols="12" md="6">
                      <div class="text-caption text-medium-emphasis">Diagnosis</div>
                      <div class="text-body-2 font-weight-bold mb-3">{{ tpSelected.diagnosis || '—' }}</div>
                      <div class="text-caption text-medium-emphasis">Status</div>
                      <v-chip size="small" :color="tpStatusColor(tpSelected.status)" variant="tonal" class="mb-3">
                        {{ tpStatusLabel(tpSelected.status) }}
                      </v-chip>
                    </v-col>
                    <v-col cols="12" md="6">
                      <div class="text-caption text-medium-emphasis">Start Date</div>
                      <div class="text-body-2 font-weight-bold mb-3">{{ formatDate(tpSelected.start_date) }}</div>
                      <div class="text-caption text-medium-emphasis">Target End</div>
                      <div class="text-body-2 font-weight-bold mb-3">{{ tpSelected.end_date ? formatDate(tpSelected.end_date) : 'Open-ended' }}</div>
                    </v-col>
                  </v-row>
                  <v-divider class="my-3" />
                  <div class="d-flex flex-wrap ga-2">
                    <v-btn v-for="tr in tpTransitionsFor(tpSelected)" :key="tr.value"
                           :prepend-icon="tr.icon" :color="tr.color" variant="tonal" rounded="lg"
                           size="small" class="text-none" @click="tpChangeStatus(tpSelected, tr.value)">
                      {{ tr.label }}
                    </v-btn>
                    <v-spacer />
                    <v-btn variant="tonal" rounded="lg" color="purple" class="text-none" size="small"
                           prepend-icon="mdi-pencil" @click="tpEditMode = true; tpDetailTab = 'edit'">Edit Plan</v-btn>
                  </div>
                </v-window-item>

                <!-- Medications -->
                <v-window-item value="meds">
                  <div v-if="(tpMedicationsMap[tpSelected.id] || []).length" class="d-flex flex-column ga-2">
                    <div v-for="med in tpMedicationsMap[tpSelected.id]" :key="med.id"
                         class="d-flex align-center ga-3 pa-3 rounded-lg" style="background:rgba(124,58,237,0.06);">
                      <v-avatar size="40" color="purple" variant="tonal">
                        <v-icon icon="mdi-pill" size="20" />
                      </v-avatar>
                      <div class="flex-grow-1">
                        <div class="text-body-2 font-weight-bold">{{ med.medication_name }} · {{ med.dose }}</div>
                        <div class="text-caption text-medium-emphasis">
                          {{ med.route_label || med.route }} ·
                          {{ med.frequency_cron || (med.times_of_day || []).join(', ') || 'As needed' }}
                          <span v-if="med.instructions"> · {{ med.instructions }}</span>
                        </div>
                      </div>
                      <v-chip size="x-small" :color="med.is_active ? 'success' : 'grey'" variant="tonal" label>
                        {{ med.is_active ? 'Active' : 'Stopped' }}
                      </v-chip>
                    </div>
                  </div>
                  <div v-else class="text-center py-8 text-medium-emphasis">
                    <v-icon icon="mdi-pill-off" size="40" class="mb-2" color="grey" />
                    <div class="font-weight-medium">No medications scheduled</div>
                  </div>
                </v-window-item>

                <!-- Goals -->
                <v-window-item value="goals">
                  <div v-if="(tpSelected.goals || []).length" class="d-flex flex-column ga-3">
                    <div v-for="(g, gi) in tpSelected.goals" :key="gi"
                         class="d-flex align-start ga-3 pa-3 rounded-lg" style="background:rgba(124,58,237,0.06);">
                      <v-avatar size="32" color="teal" variant="tonal">
                        <v-icon icon="mdi-target" size="16" />
                      </v-avatar>
                      <div>
                        <div class="text-caption text-medium-emphasis">Goal {{ gi + 1 }}</div>
                        <div class="text-body-2">{{ typeof g === 'string' ? g : g.text || g.goal || '' }}</div>
                      </div>
                    </div>
                  </div>
                  <div v-else class="text-center py-8 text-medium-emphasis">
                    <v-icon icon="mdi-target" size="40" class="mb-2" color="grey" />
                    <div class="font-weight-medium">No goals defined</div>
                  </div>
                </v-window-item>

                <!-- Edit Plan -->
                <v-window-item value="edit">
                  <v-row dense>
                    <v-col cols="12"><v-text-field v-model="tpEditForm.title" label="Plan title *" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                    <v-col cols="12"><v-text-field v-model="tpEditForm.diagnosis" label="Diagnosis" variant="outlined" density="comfortable" class="mb-2" /></v-col>
                    <v-col cols="6"><v-text-field v-model="tpEditForm.start_date" type="date" label="Start date" variant="outlined" density="comfortable" /></v-col>
                    <v-col cols="6"><v-text-field v-model="tpEditForm.end_date" type="date" label="End date" variant="outlined" density="comfortable" clearable /></v-col>
                    <v-col cols="12">
                      <v-select v-model="tpEditForm.status" :items="tpStatusOptions" item-title="label" item-value="value"
                                label="Status" variant="outlined" density="comfortable" class="mb-2" />
                    </v-col>
                    <v-col cols="12">
                      <v-combobox v-model="tpEditGoals" :items="[]" label="Goals (type and press Enter)" variant="outlined"
                                  density="comfortable" multiple chips closable clearable class="mb-2" hint="Add SMART goals for this treatment plan." persistent-hint />
                    </v-col>
                    <v-col cols="12"><v-textarea v-model="tpEditForm.notes" label="Clinical notes" rows="3" variant="outlined" density="comfortable" /></v-col>
                  </v-row>
                  <div class="d-flex ga-2">
                    <v-spacer />
                    <v-btn variant="text" @click="tpEditMode = false; tpDetailTab = 'overview'">Cancel</v-btn>
                    <v-btn color="purple" variant="flat" :loading="tpSaving" @click="tpSaveEdit">Save Changes</v-btn>
                  </div>
                </v-window-item>
              </v-window>
            </v-card-text>
          </v-card>
        </v-dialog>

        <!-- ═══════════════ CREATE TREATMENT PLAN DIALOG ═══════════════ -->
        <v-dialog v-model="tpCreateDialog" max-width="640" scrollable>
          <v-card rounded="xl" class="overflow-hidden">
            <div class="pa-5" style="background:linear-gradient(135deg,#7c3aed,#6d28d9);">
              <div class="d-flex align-center ga-3 text-white">
                <v-avatar size="48" color="white" variant="flat">
                  <v-icon icon="mdi-clipboard-edit" color="purple" />
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="text-overline" style="opacity:.85;">NEW PLAN</div>
                  <h3 class="text-h6 ma-0">{{ tpCreateForm.title || 'Create treatment plan' }}</h3>
                </div>
                <v-btn icon="mdi-close" variant="text" color="white" @click="tpCreateDialog = false" />
              </div>
            </div>
            <v-card-text class="pa-5">
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-combobox v-model="tpCreateForm.title" :items="PLAN_TITLE_OPTIONS"
                              label="Plan title *" hint="Pick a template or type your own"
                              persistent-hint variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-format-title" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="tpCreateForm.diagnosis" label="Primary diagnosis"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-stethoscope" readonly
                                hint="Auto-filled from patient record" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="tpCreateForm.start_date" type="date" label="Start date *"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-calendar-start" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="tpCreateForm.end_date" type="date" label="Target end date"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-calendar-end" />
                </v-col>
                <v-col cols="12">
                  <v-combobox v-model="tpCreateGoals" :items="tpSmartGoalOptions"
                              label="Care goals" multiple chips closable-chips clearable
                              hint="Add SMART goals. Type and press Enter."
                              persistent-hint variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-target" />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="tpCreateForm.notes" label="Clinical notes"
                              rows="3" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-note-text" />
                </v-col>
              </v-row>
            </v-card-text>
            <v-divider />
            <v-card-actions class="pa-4">
              <v-spacer />
              <v-btn variant="text" rounded="lg" class="text-none" @click="tpCreateDialog = false">Cancel</v-btn>
              <v-btn color="purple" variant="flat" rounded="lg" class="text-none"
                     :loading="tpCreateSaving" prepend-icon="mdi-content-save" @click="tpCreateSave">
                Create Plan
              </v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>

        <!-- ═══════════════ DOCUMENTS ═══════════════ -->
        <v-window-item value="documents">
          <div class="pa-4">
            <!-- Header -->
            <div class="d-flex align-center mb-4 flex-wrap ga-3">
              <div class="d-flex align-center ga-3 flex-grow-1">
                <div class="hc-dose-panel-icon" style="background:linear-gradient(135deg,#0d9488,#0f766e);">
                  <v-icon icon="mdi-file-document-multiple" size="18" />
                </div>
                <div>
                  <h3 class="text-subtitle-1 font-weight-bold ma-0">Document Management</h3>
                  <div class="text-caption text-medium-emphasis">Insurance cards, lab reports, imaging, prescriptions, consents & more</div>
                </div>
              </div>
              <v-btn color="teal" variant="flat" rounded="lg" class="text-none font-weight-bold px-5"
                     prepend-icon="mdi-upload" @click="openDocUploadDialog">Upload Document</v-btn>
            </div>

            <!-- KPI Row -->
            <v-row dense class="mb-4">
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="teal">
                  <v-icon icon="mdi-file-multiple" color="teal" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-teal">{{ patientDocs.length }}</div>
                  <div class="text-caption text-medium-emphasis">Total documents</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="error">
                  <v-icon icon="mdi-shield-lock" color="error" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-error">{{ docRestrictedCount }}</div>
                  <div class="text-caption text-medium-emphasis">Restricted</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="warning">
                  <v-icon icon="mdi-alert" color="warning" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-warning">{{ docExpiringCount }}</div>
                  <div class="text-caption text-medium-emphasis">Expiring</div>
                </v-card>
              </v-col>
              <v-col cols="6" md="3">
                <v-card rounded="xl" variant="tonal" class="pa-4 text-center" color="purple">
                  <v-icon icon="mdi-database" color="purple" size="22" class="mb-1" />
                  <div class="text-h6 font-weight-bold text-purple">{{ docStorageUsed }}</div>
                  <div class="text-caption text-medium-emphasis">Storage (MB)</div>
                </v-card>
              </v-col>
            </v-row>

            <v-row dense>
              <!-- Categories sidebar -->
              <v-col cols="12" lg="3">
                <v-card variant="outlined" rounded="xl" class="pa-3">
                  <div class="d-flex align-center mb-2 px-1">
                    <v-icon icon="mdi-folder-multiple" color="teal" size="18" class="mr-2" />
                    <span class="text-subtitle-2 font-weight-bold">Categories</span>
                  </div>
                  <v-list density="compact" class="bg-transparent pa-0" v-model:selected="docSelectedCategory">
                    <v-list-item value="" rounded="lg" class="mb-1">
                      <template #prepend><v-icon icon="mdi-file-multiple" /></template>
                      <v-list-item-title>All documents</v-list-item-title>
                      <template #append><v-chip size="x-small" variant="tonal">{{ patientDocs.length }}</v-chip></template>
                    </v-list-item>
                    <v-list-item v-for="c in docCategories" :key="c.value" :value="c.value" rounded="lg" class="mb-1">
                      <template #prepend><v-icon :icon="c.icon" :color="c.color" /></template>
                      <v-list-item-title>{{ c.label }}</v-list-item-title>
                      <template #append><v-chip size="x-small" variant="tonal" :color="c.color">{{ docCountByCategory(c.value) }}</v-chip></template>
                    </v-list-item>
                  </v-list>
                </v-card>
              </v-col>

              <!-- Document library -->
              <v-col cols="12" lg="9">
                <v-card variant="outlined" rounded="xl" class="pa-4">
                  <div class="d-flex align-center mb-3">
                    <v-icon icon="mdi-file-document" color="teal" class="mr-2" />
                    <span class="text-subtitle-1 font-weight-bold">Document Library</span>
                    <v-spacer />
                    <span class="text-caption text-medium-emphasis">{{ filteredPatientDocs.length }} of {{ patientDocs.length }}</span>
                  </div>
                  <!-- Filters -->
                  <v-row dense class="mb-2">
                    <v-col cols="12" md="6">
                      <v-text-field v-model="docSearch" prepend-inner-icon="mdi-magnify" placeholder="Search documents…"
                                    density="compact" variant="outlined" hide-details clearable />
                    </v-col>
                    <v-col cols="12" md="6">
                      <v-select v-model="docFilterAccess" :items="docAccessLevels" item-title="label" item-value="value"
                                label="Access level" density="compact" variant="outlined" hide-details clearable />
                    </v-col>
                  </v-row>

                  <!-- Data table -->
                  <v-data-table :headers="docHeaders" :items="filteredPatientDocs" :loading="docLoading"
                                 item-value="id" class="cc-table" density="comfortable">
                    <template #[`item.name`]="{ item }">
                      <div class="d-flex align-center">
                        <v-avatar size="32" :color="docCatColor(item.category)" variant="tonal" class="mr-2">
                          <v-icon :icon="docCatIcon(item.category)" size="16" />
                        </v-avatar>
                        <div>
                          <div class="font-weight-medium text-body-2">{{ item.name }}</div>
                          <div class="text-caption text-medium-emphasis">{{ item.file_type || 'file' }} · {{ docFormatSize(item.file_size) }}</div>
                        </div>
                      </div>
                    </template>
                    <template #[`item.category`]="{ item }">
                      <v-chip size="small" variant="tonal" :color="docCatColor(item.category)">{{ docCatLabel(item.category) }}</v-chip>
                    </template>
                    <template #[`item.access_level`]="{ item }">
                      <v-chip size="small" variant="tonal" :color="docAccessColor(item.access_level)" prepend-icon="mdi-shield">
                        {{ docAccessLabel(item.access_level) }}
                      </v-chip>
                    </template>
                    <template #[`item.expiry_date`]="{ item }">
                      <span v-if="item.expiry_date" :class="docExpiryClass(item.expiry_date)">{{ formatDate(item.expiry_date) }}</span>
                      <span v-else class="text-medium-emphasis">—</span>
                    </template>
                    <template #[`item.uploaded_at`]="{ item }">{{ formatDate(item.uploaded_at) }}</template>
                    <template #[`item.actions`]="{ item }">
                      <v-menu location="bottom end">
                        <template #activator="{ props }">
                          <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
                        </template>
                        <v-list density="compact" min-width="200">
                          <v-list-item v-if="docPreviewType(item)" prepend-icon="mdi-eye-outline" title="View document" @click="openDocViewer(item)" />
                          <v-list-item prepend-icon="mdi-download" title="Download" @click="downloadPatientDoc(item)" />
                          <v-list-item prepend-icon="mdi-eye" title="View details" @click="viewDocDetail(item)" />
                          <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="openDocEditDialog(item)" />
                          <v-divider />
                          <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error" @click="confirmDeleteDoc(item)" />
                        </v-list>
                      </v-menu>
                    </template>
                  </v-data-table>
                </v-card>
              </v-col>
            </v-row>

            <!-- Upload dialog -->
            <v-dialog v-model="docUploadDialog" max-width="560" scrollable>
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center"><v-icon icon="mdi-upload" color="teal" class="mr-2" />Upload Document</v-card-title>
                <v-divider />
                <v-card-text style="max-height:72vh">
                  <v-text-field v-model="docUploadForm.name" label="Document name *" density="comfortable" variant="outlined" class="mb-2" />
                  <v-select v-model="docUploadForm.category" :items="docCategories" item-title="label" item-value="value"
                            label="Category *" density="comfortable" variant="outlined" class="mb-2" />
                  <v-select v-model="docUploadForm.access_level" :items="docAccessLevels" item-title="label" item-value="value"
                            label="Access level" density="comfortable" variant="outlined" class="mb-2" />
                  <v-text-field v-model="docUploadForm.expiry_date" label="Expiry date (optional)" type="date"
                                density="comfortable" variant="outlined" class="mb-2" />
                  <v-file-input v-model="docUploadForm.file" label="Select file *" prepend-icon="mdi-paperclip"
                                density="comfortable" variant="outlined" show-size class="mb-2" />
                  <v-textarea v-model="docUploadForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
                </v-card-text>
                <v-divider />
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="docUploadDialog = false">Cancel</v-btn>
                  <v-btn color="teal" variant="flat" :loading="docSaving" @click="uploadPatientDoc">Upload</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Edit dialog -->
            <v-dialog v-model="docEditDialog" max-width="560" scrollable>
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center"><v-icon icon="mdi-pencil" color="teal" class="mr-2" />Edit Document</v-card-title>
                <v-divider />
                <v-card-text style="max-height:72vh">
                  <v-text-field v-model="docEditForm.name" label="Document name *" density="comfortable" variant="outlined" class="mb-2" />
                  <v-select v-model="docEditForm.category" :items="docCategories" item-title="label" item-value="value"
                            label="Category *" density="comfortable" variant="outlined" class="mb-2" />
                  <v-select v-model="docEditForm.access_level" :items="docAccessLevels" item-title="label" item-value="value"
                            label="Access level" density="comfortable" variant="outlined" class="mb-2" />
                  <v-text-field v-model="docEditForm.expiry_date" label="Expiry date (optional)" type="date"
                                density="comfortable" variant="outlined" class="mb-2" />
                  <v-file-input v-model="docEditForm.file" label="Replace file (optional)" prepend-icon="mdi-paperclip"
                                density="comfortable" variant="outlined" show-size clearable class="mb-2" />
                  <div v-if="docEditItem && docEditItem.file_url && !docEditForm.file" class="text-caption text-medium-emphasis mb-2">
                    <v-icon icon="mdi-paperclip" size="14" class="mr-1" />Current: {{ docEditItem.file_type || 'file' }} · {{ docFormatSize(docEditItem.file_size) }}
                  </div>
                  <v-textarea v-model="docEditForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
                </v-card-text>
                <v-divider />
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="docEditDialog = false">Cancel</v-btn>
                  <v-btn color="teal" variant="flat" :loading="docSaving" @click="saveDocEdit">Save changes</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Detail dialog -->
            <v-dialog v-model="docDetailDialog" max-width="480">
              <v-card rounded="xl">
                <v-card-title class="d-flex align-center"><v-icon icon="mdi-file-document" color="teal" class="mr-2" />Document Details</v-card-title>
                <v-divider />
                <v-card-text v-if="docDetailItem">
                  <v-row dense>
                    <v-col cols="12"><div class="text-caption text-medium-emphasis">Name</div><div class="font-weight-medium">{{ docDetailItem.name }}</div></v-col>
                    <v-col cols="6"><div class="text-caption text-medium-emphasis">Category</div><div class="font-weight-medium">{{ docCatLabel(docDetailItem.category) }}</div></v-col>
                    <v-col cols="6"><div class="text-caption text-medium-emphasis">Access</div><div class="font-weight-medium">{{ docAccessLabel(docDetailItem.access_level) }}</div></v-col>
                    <v-col cols="6"><div class="text-caption text-medium-emphasis">Size</div><div class="font-weight-medium">{{ docFormatSize(docDetailItem.file_size) }}</div></v-col>
                    <v-col cols="6"><div class="text-caption text-medium-emphasis">Uploaded</div><div class="font-weight-medium">{{ formatDate(docDetailItem.uploaded_at) }}</div></v-col>
                    <v-col cols="6"><div class="text-caption text-medium-emphasis">Expires</div><div class="font-weight-medium">{{ docDetailItem.expiry_date ? formatDate(docDetailItem.expiry_date) : '—' }}</div></v-col>
                    <v-col v-if="docDetailItem.description" cols="12"><div class="text-caption text-medium-emphasis">Description</div><div>{{ docDetailItem.description }}</div></v-col>
                  </v-row>
                </v-card-text>
                <v-divider />
                <v-card-actions>
                  <v-btn v-if="docDetailItem && docPreviewType(docDetailItem)" variant="flat" color="teal" prepend-icon="mdi-eye-outline" @click="openDocViewer(docDetailItem)">View</v-btn>
                  <v-btn variant="text" prepend-icon="mdi-pencil" @click="openDocEditDialog(docDetailItem)">Edit</v-btn>
                  <v-btn variant="text" prepend-icon="mdi-download" @click="downloadPatientDoc(docDetailItem)">Download</v-btn>
                  <v-spacer />
                  <v-btn variant="text" @click="docDetailDialog = false">Close</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>

            <!-- Premium document viewer -->
            <v-dialog v-model="docViewerDialog" fullscreen transition="dialog-bottom-transition" scrollable
                      content-class="cc-viewer-dialog">
              <v-card rounded="0" class="d-flex flex-column cc-viewer-root">
                <!-- Top toolbar -->
                <v-toolbar flat density="compact" class="cc-viewer-toolbar flex-grow-0">
                  <v-icon icon="mdi-file-eye-outline" class="ml-4 mr-2" color="white" />
                  <v-toolbar-title class="text-white text-body-1 font-weight-medium" style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">
                    {{ docViewerItem?.name }}
                  </v-toolbar-title>
                  <v-chip v-if="docViewerItem" size="x-small" variant="flat" color="white" class="mr-2 d-none d-sm-inline-flex text-teal-darken-2 font-weight-bold">
                    {{ (docViewerItem.file_type || 'file').toUpperCase() }}
                  </v-chip>
                  <v-spacer />
                  <v-btn icon variant="text" color="white" @click="closeDocViewer">
                    <v-icon icon="mdi-close" />
                    <v-tooltip activator="parent" location="bottom">Close (Esc)</v-tooltip>
                  </v-btn>
                </v-toolbar>

                <!-- Controls bar for images -->
                <div v-if="docViewerItem && docPreviewType(docViewerItem) === 'image'" class="cc-viewer-controls flex-grow-0">
                  <div class="cc-viewer-ctrl-group">
                    <v-btn icon variant="text" size="small" color="teal-darken-2" @click="docZoomOut" :disabled="docViewerZoom <= 0.2">
                      <v-icon icon="mdi-magnify-minus" />
                      <v-tooltip activator="parent" location="bottom">Zoom out (-)</v-tooltip>
                    </v-btn>
                    <span class="cc-viewer-zoom-label">{{ Math.round(docViewerZoom * 100) }}%</span>
                    <v-btn icon variant="text" size="small" color="teal-darken-2" @click="docZoomIn" :disabled="docViewerZoom >= 5">
                      <v-icon icon="mdi-magnify-plus" />
                      <v-tooltip activator="parent" location="bottom">Zoom in (+)</v-tooltip>
                    </v-btn>
                  </div>
                  <v-divider vertical class="mx-2" />
                  <div class="cc-viewer-ctrl-group">
                    <v-btn icon variant="text" size="small" color="teal-darken-2" @click="docFitToScreen">
                      <v-icon icon="mdi-fit-to-screen" />
                      <v-tooltip activator="parent" location="bottom">Fit to screen (0)</v-tooltip>
                    </v-btn>
                    <v-btn icon variant="text" size="small" color="teal-darken-2" @click="docActualSize">
                      <v-icon icon="mdi-arrow-expand-all" />
                      <v-tooltip activator="parent" location="bottom">Actual size (1)</v-tooltip>
                    </v-btn>
                  </div>
                  <v-divider vertical class="mx-2" />
                  <div class="cc-viewer-ctrl-group">
                    <v-btn icon variant="text" size="small" color="blue-darken-2" @click="docRotateLeft">
                      <v-icon icon="mdi-rotate-left" />
                      <v-tooltip activator="parent" location="bottom">Rotate left (L)</v-tooltip>
                    </v-btn>
                    <v-btn icon variant="text" size="small" color="blue-darken-2" @click="docRotateRight">
                      <v-icon icon="mdi-rotate-right" />
                      <v-tooltip activator="parent" location="bottom">Rotate right (R)</v-tooltip>
                    </v-btn>
                    <span class="cc-viewer-zoom-label">{{ docViewerRotation }}°</span>
                  </div>
                  <v-divider vertical class="mx-2" />
                  <div class="cc-viewer-ctrl-group">
                    <v-btn icon variant="text" size="small" color="teal-darken-2" @click="docResetView">
                      <v-icon icon="mdi-refresh" />
                      <v-tooltip activator="parent" location="bottom">Reset view</v-tooltip>
                    </v-btn>
                  </div>
                  <v-spacer />
                  <div class="cc-viewer-ctrl-group">
                    <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" @click="downloadPatientDoc(docViewerItem)">Download</v-btn>
                  </div>
                </div>

                <!-- PDF controls bar -->
                <div v-else-if="docViewerItem && docPreviewType(docViewerItem) === 'pdf'" class="cc-viewer-controls flex-grow-0">
                  <v-icon icon="mdi-file-pdf-box" color="red" class="ml-2" />
                  <span class="cc-viewer-zoom-label ml-2">PDF Document</span>
                  <v-spacer />
                  <v-progress-circular v-if="docPdfLoading" indeterminate size="16" width="2" color="teal" class="mr-3" />
                  <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-open-in-new" @click="downloadPatientDoc(docViewerItem)">Open in new tab</v-btn>
                  <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" class="ml-2" @click="downloadPatientDoc(docViewerItem)">Download</v-btn>
                </div>

                <!-- Office controls bar -->
                <div v-else-if="docViewerItem && docPreviewType(docViewerItem) === 'office'" class="cc-viewer-controls flex-grow-0">
                  <v-icon icon="mdi-file-word-box" color="blue" class="ml-2" />
                  <span class="cc-viewer-zoom-label ml-2">{{ (docViewerItem.file_type || 'doc').toUpperCase() }} Document</span>
                  <v-spacer />
                  <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-open-in-new" @click="downloadPatientDoc(docViewerItem)">Open in new tab</v-btn>
                  <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" class="ml-2" @click="downloadPatientDoc(docViewerItem)">Download</v-btn>
                </div>

                <!-- Viewer canvas -->
                <div ref="docViewerCanvas" class="cc-viewer-canvas"
                     @mousedown="onDocDragStart" @mousemove="onDocDragMove" @mouseup="onDocDragEnd" @mouseleave="onDocDragEnd"
                     @wheel.prevent="onDocWheel" @dblclick="onDocDoubleClick"
                     :class="{ 'cc-grab': docPreviewType(docViewerItem) === 'image' && !docIsDragging, 'cc-grabbing': docIsDragging }">
                  <!-- Image -->
                  <img v-if="docViewerItem && docPreviewType(docViewerItem) === 'image'"
                       :src="docViewerItem.file_url"
                       :alt="docViewerItem.name"
                       :style="docImageStyle"
                       class="cc-viewer-image"
                       @load="onDocImageLoad"
                       draggable="false" />
                  <!-- PDF -->
                  <div v-else-if="docViewerItem && docPreviewType(docViewerItem) === 'pdf'" class="cc-viewer-pdf-wrap">
                    <div v-if="docPdfLoading" class="cc-viewer-loading">
                      <v-progress-circular indeterminate size="48" width="4" color="teal" />
                      <div class="text-teal-darken-2 mt-3 text-body-2">Loading PDF…</div>
                    </div>
                    <iframe v-else-if="docPdfBlobUrl" :src="docPdfBlobUrl" class="cc-viewer-pdf" frameborder="0" />
                    <div v-else class="cc-viewer-fallback">
                      <v-icon icon="mdi-file-pdf-box" size="72" color="red-lighten-2" />
                      <div class="text-h6 text-teal-darken-2 mt-4 font-weight-medium">PDF could not be loaded inline</div>
                      <v-btn variant="flat" color="teal" prepend-icon="mdi-open-in-new" class="mt-4" @click="downloadPatientDoc(docViewerItem)">Open in new tab</v-btn>
                    </div>
                  </div>
                  <!-- Office documents (Google Docs viewer) -->
                  <iframe v-else-if="docViewerItem && docPreviewType(docViewerItem) === 'office'"
                          :src="docOfficeViewerUrl(docViewerItem)"
                          class="cc-viewer-pdf"
                          frameborder="0" />
                  <!-- Not previewable -->
                  <div v-else class="cc-viewer-fallback">
                    <v-icon icon="mdi-file-question-outline" size="72" color="teal-lighten-2" />
                    <div class="text-h6 text-teal-darken-2 mt-4 font-weight-medium">Preview not available for this file type</div>
                    <div class="text-body-2 text-blue-grey-lighten-1 mt-1">{{ docViewerItem?.file_type || 'file' }} · {{ docFormatSize(docViewerItem?.file_size) }}</div>
                    <v-btn variant="flat" color="teal" prepend-icon="mdi-download" class="mt-5" @click="downloadPatientDoc(docViewerItem)">Download file</v-btn>
                  </div>
                </div>

                <!-- Bottom status bar -->
                <div v-if="docViewerItem && docPreviewType(docViewerItem) === 'image'" class="cc-viewer-status-bar flex-grow-0">
                  <v-icon icon="mdi-gesture-tap" size="14" class="mr-1" color="teal-darken-1" />
                  <span class="text-caption">Double-click to zoom · Drag to pan · Scroll to zoom · Keyboard: +/− zoom · R rotate · 0 fit · Esc close</span>
                </div>
              </v-card>
            </v-dialog>

            <!-- Delete confirm -->
            <v-dialog v-model="docDeleteDialog" max-width="420">
              <v-card rounded="xl">
                <v-card-title>Delete document?</v-card-title>
                <v-card-text>This permanently removes <b>{{ docDeleteTarget?.name }}</b>.</v-card-text>
                <v-card-actions>
                  <v-spacer />
                  <v-btn variant="text" @click="docDeleteDialog = false">Cancel</v-btn>
                  <v-btn color="error" variant="flat" :loading="docSaving" @click="doDeleteDoc">Delete</v-btn>
                </v-card-actions>
              </v-card>
            </v-dialog>
          </div>
        </v-window-item>

      </v-window>
    </v-card>

    <!-- ═══════════════ QUICK VITALS DIALOG ═══════════════ -->
    <v-dialog v-model="quickVitalsDialog" max-width="760" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pe-3 py-3">
          <v-icon color="teal" class="me-2">mdi-heart-pulse</v-icon>
          <div><div class="font-weight-bold">Record Vitals</div><div class="text-caption text-medium-emphasis">{{ patientName }} · NEWS2</div></div>
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="quickVitalsDialog=false" />
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-row>
            <v-col cols="12" md="7">
              <v-row dense>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.rr" type="number" label="Respiratory rate (/min)" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.rr}`" persistent-hint /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.spo2" type="number" label="SpO₂ (%)" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.spo2}`" persistent-hint /></v-col>
                <v-col cols="12"><v-switch v-model="quickVitalsForm.scale2" color="teal" hide-details density="compact" label="SpO₂ Scale 2 (hypercapnic / COPD target 88–92%)" /></v-col>
                <v-col cols="6"><v-select v-model="quickVitalsForm.oxygen" :items="['Room air','Supplemental O₂']" label="Oxygen" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.oxygen}`" persistent-hint /></v-col>
                <v-col v-if="quickVitalsForm.oxygen==='Supplemental O₂'" cols="6"><v-select v-model="quickVitalsForm.oxygen_delivery" :items="OXYGEN_DELIVERY_MODES" label="Mode of delivery" variant="outlined" density="comfortable" /></v-col>
                <v-col cols="6"><v-select v-model="quickVitalsForm.consciousness" :items="[{title:'A - Alert',value:'A'},{title:'C - New confusion',value:'C'},{title:'V - Voice',value:'V'},{title:'P - Pain',value:'P'},{title:'U - Unresponsive',value:'U'}]" label="ACVPU" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.consciousness}`" persistent-hint /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.systolic" type="number" label="Systolic BP" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.sbp}`" persistent-hint suffix="mmHg" /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.diastolic" type="number" label="Diastolic BP" variant="outlined" density="comfortable" hint="Recorded (not scored)" persistent-hint suffix="mmHg" /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.pulse" type="number" label="Heart rate (bpm)" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.hr}`" persistent-hint /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.temperature" type="number" label="Temperature (°C)" variant="outlined" density="comfortable" :hint="`Score: ${quickNews2Scores.temp}`" persistent-hint /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.glucose" type="number" label="Glucose (mmol/L)" variant="outlined" density="comfortable" hint="Optional" persistent-hint /></v-col>
                <v-col cols="6"><v-text-field v-model.number="quickVitalsForm.weight" type="number" label="Weight (kg)" variant="outlined" density="comfortable" hint="Optional" persistent-hint /></v-col>
              </v-row>
            </v-col>
            <v-col cols="12" md="5">
              <div class="news2-panel" :style="{ background: `linear-gradient(135deg, ${quickNews2Risk.hex}22, ${quickNews2Risk.hex}0d)`, borderColor: `${quickNews2Risk.hex}55` }">
                <div class="text-caption text-uppercase font-weight-bold" :style="{ color: quickNews2Risk.hex }">Aggregate NEWS2</div>
                <div class="news2-total" :style="{ color: quickNews2Risk.hex }">{{ quickNews2Total }}</div>
                <v-chip :color="quickNews2Risk.color" variant="flat" class="font-weight-bold mb-2">{{ quickNews2Risk.label }} risk</v-chip>
                <v-divider class="mb-2" />
                <div v-for="b in quickNews2Breakdown" :key="b.key" class="news2-row">
                  <v-icon size="16" class="me-2" :color="b.score>=3?'error':(b.score>0?'warning':'grey')">{{ b.icon }}</v-icon>
                  <span class="text-caption flex-grow-1">{{ b.label }}</span>
                  <span class="text-caption text-medium-emphasis me-2">{{ b.value }}</span>
                  <v-chip size="x-small" variant="tonal" :color="b.score>=3?'error':(b.score>0?'warning':'success')">{{ b.score }}</v-chip>
                </div>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions><v-spacer /><v-btn variant="text" @click="quickVitalsDialog=false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="savingVitals" @click="saveQuickVitals" prepend-icon="mdi-content-save">Save Vitals</v-btn></v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ GENERATE BILL DIALOG ═══════════════ -->
    <v-dialog v-model="billGenDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-receipt-text-plus" color="teal" class="mr-2" />Generate Bill</v-card-title>
        <v-card-text>
          <v-table density="compact" class="mb-3">
            <tbody>
              <tr><td>Care Plan</td><td class="text-right">{{ money(summary.care_total) }}</td></tr>
              <tr v-if="Number(summary.equipment_total) > 0"><td>Equipment</td><td class="text-right">{{ money(summary.equipment_total) }}</td></tr>
              <tr v-if="Number(summary.supplies_total) > 0"><td>Supplies</td><td class="text-right">{{ money(summary.supplies_total) }}</td></tr>
              <tr v-if="Number(summary.medication_total) > 0"><td>Medications</td><td class="text-right">{{ money(summary.medication_total) }}</td></tr>
              <tr class="font-weight-bold"><td>Subtotal</td><td class="text-right">{{ money(summary.subtotal) }}</td></tr>
            </tbody>
          </v-table>
          <v-row dense>
            <v-col cols="6"><v-text-field v-model.number="billGenForm.discount" type="number" min="0" label="Discount" prefix="KSh" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="billGenForm.tax" type="number" min="0" label="Tax" prefix="KSh" variant="outlined" density="comfortable" /></v-col>
          </v-row>
          <div class="d-flex justify-space-between text-h6 font-weight-bold my-2 px-1">
            <span>Total</span><span class="text-teal-darken-2">{{ money(billGenTotal) }}</span>
          </div>
          <v-textarea v-model="billGenForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn variant="text" @click="billGenDialog=false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="billingSaving" @click="generateBill">Generate</v-btn></v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ RECORD PAYMENT DIALOG ═══════════════ -->
    <v-dialog v-model="paymentDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-cash-plus" color="success" class="mr-2" />Record Payment</v-card-title>
        <v-card-text>
          <v-select v-model="paymentForm.bill_id" :items="billSelectOptions" item-title="title" item-value="value"
                    label="Apply to bill (optional)" variant="outlined" density="comfortable" clearable class="mb-2"
                    hint="Leave empty to auto-apply to oldest open bill" persistent-hint />
          <v-row dense>
            <v-col cols="7"><v-text-field v-model.number="paymentForm.amount" type="number" min="0" label="Amount" prefix="KSh" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="5"><v-select v-model="paymentForm.method" :items="PAYMENT_METHODS" item-title="label" item-value="value" label="Method" variant="outlined" density="comfortable" /></v-col>
          </v-row>
          <v-text-field v-model="paymentForm.reference" label="Reference (optional)" variant="outlined" density="comfortable" placeholder="M-Pesa code, cheque #, …" />
          <v-text-field v-model="paymentForm.paid_at" type="datetime-local" label="Paid at" variant="outlined" density="comfortable" />
          <v-textarea v-model="paymentForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn variant="text" @click="paymentDialog=false">Cancel</v-btn>
          <v-btn color="success" variant="flat" :loading="billingSaving" @click="savePayment">Save Payment</v-btn></v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ PAYMENT PLAN DIALOG ═══════════════ -->
    <v-dialog v-model="planDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-calendar-clock" color="purple" class="mr-2" />Payment Plan</v-card-title>
        <v-card-text>
          <v-select v-model="planForm.plan_type" :items="PLAN_TYPES" item-title="title" item-value="value" label="Plan type" variant="outlined" density="comfortable" class="mb-2" />
          <v-row dense>
            <v-col cols="7"><v-text-field v-model.number="planForm.rate" type="number" min="0" label="Rate" prefix="KSh" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="5"><v-text-field v-model="planForm.currency" label="Currency" variant="outlined" density="comfortable" /></v-col>
          </v-row>
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="planForm.start_date" type="date" label="Start date" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6"><v-text-field v-model="planForm.end_date" type="date" label="End date (optional)" variant="outlined" density="comfortable" clearable /></v-col>
          </v-row>
          <v-textarea v-model="planForm.notes" label="Notes" rows="2" variant="outlined" density="comfortable" />
          <v-switch v-model="planForm.auto_bill" color="purple" label="Auto-generate bills" density="compact" hide-details class="mt-1" />
        </v-card-text>
        <v-card-actions><v-spacer /><v-btn variant="text" @click="planDialog=false">Cancel</v-btn>
          <v-btn color="purple" variant="flat" :loading="billingSaving" @click="savePlan">Save Plan</v-btn></v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ BILL DETAIL DIALOG ═══════════════ -->
    <v-dialog v-model="billDetailDialog" max-width="700">
      <v-card v-if="billDetailItem" rounded="xl">
        <v-card-title class="d-flex align-center flex-wrap ga-2">
          <v-icon icon="mdi-receipt-text" color="cyan-darken-2" class="mr-1" />
          <span>Bill {{ billDetailItem.bill_number }}</span>
          <v-chip size="x-small" :color="billDetailItem.status==='paid'?'success':billDetailItem.status==='void'?'grey':'warning'" variant="tonal" label>{{ billDetailItem.status_label || billDetailItem.status }}</v-chip>
          <v-spacer />
          <v-btn size="small" variant="text" icon="mdi-close" @click="billDetailDialog=false" />
        </v-card-title>
        <v-card-text>
          <div class="d-flex flex-wrap ga-4 mb-3">
            <div><div class="text-caption text-medium-emphasis">Patient</div><div class="font-weight-medium">{{ patientName }}</div></div>
            <div><div class="text-caption text-medium-emphasis">Date</div><div class="font-weight-medium">{{ formatDate(billDetailItem.as_of) }}</div></div>
            <div v-if="billDetailItem.generated_by_name"><div class="text-caption text-medium-emphasis">Generated by</div><div class="font-weight-medium">{{ billDetailItem.generated_by_name }}</div></div>
          </div>
          <!-- Summary -->
          <v-table density="compact" class="mb-3">
            <tbody>
              <tr><td>Subtotal</td><td class="text-right">{{ money(billDetailItem.subtotal) }}</td></tr>
              <tr v-if="Number(billDetailItem.discount) > 0"><td>Discount</td><td class="text-right text-error">-{{ money(billDetailItem.discount) }}</td></tr>
              <tr v-if="Number(billDetailItem.tax) > 0"><td>Tax</td><td class="text-right">{{ money(billDetailItem.tax) }}</td></tr>
              <tr class="font-weight-bold"><td>Total</td><td class="text-right">{{ money(billDetailItem.total) }}</td></tr>
              <tr class="text-success"><td>Paid</td><td class="text-right">{{ money(billDetailItem.amount_paid) }}</td></tr>
              <tr class="font-weight-bold" :class="Number(billDetailItem.balance) > 0 ? 'text-error' : 'text-success'">
                <td>Balance</td><td class="text-right">{{ money(billDetailItem.balance) }}</td>
              </tr>
            </tbody>
          </v-table>
          <!-- Line items -->
          <div v-if="(billDetailItem.line_items || []).length" class="mb-3">
            <div class="text-caption font-weight-bold mb-1">Line Items</div>
            <v-table density="compact">
              <thead><tr><th>Description</th><th class="text-center">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr></thead>
              <tbody>
                <tr v-for="(li, i) in billDetailItem.line_items" :key="i">
                  <td>{{ li.label }}</td><td class="text-center">{{ li.qty }} {{ li.unit||'' }}</td>
                  <td class="text-right">{{ li.rate ? money(li.rate) : '—' }}</td><td class="text-right">{{ money(li.amount) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>
          <div v-if="billDetailItem.notes" class="text-caption mt-2"><v-icon icon="mdi-note-text" size="14" class="mr-1" />{{ billDetailItem.notes }}</div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="billDetailDialog=false">Close</v-btn>
          <v-btn v-if="billDetailItem.status !== 'paid' && billDetailItem.status !== 'void'" color="success" variant="tonal" prepend-icon="mdi-cash-plus" @click="billDetailDialog=false; openRecordPayment(billDetailItem)">Record Payment</v-btn>
          <v-btn color="deep-purple" variant="tonal" prepend-icon="mdi-download" @click="printBill(billDetailItem)">Download</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ PRINTABLE BILL / SUMMARY TEMPLATE (hidden) ═══════════════ -->
    <div ref="printArea" class="cc-print-area" style="display:none">
      <div v-if="printContent" class="print-document">
        <div class="print-top-accent" />

        <div class="print-header">
          <div class="print-provider-card">
            <div class="print-provider-brand">
              <img :src="printContent.providerLogo" alt="Homecare logo" class="print-provider-logo" />
              <div>
                <div class="print-eyebrow">Homecare Provider</div>
                <h1 class="print-provider-name">{{ printContent.providerName }}</h1>
                <p v-if="printContent.providerLocation" class="print-provider-sub">{{ printContent.providerLocation }}</p>
              </div>
            </div>
            <div class="print-provider-details">
              <div v-if="printContent.providerAddress">{{ printContent.providerAddress }}</div>
              <div v-if="printContent.providerPhone">{{ printContent.providerPhone }}</div>
              <div v-if="printContent.providerEmail">{{ printContent.providerEmail }}</div>
            </div>
          </div>

          <div class="print-platform-card">
            <div class="print-platform-row">
              <img :src="printContent.platformLogo" alt="AdhereMed logo" class="print-platform-logo" />
              <div class="print-platform-copy">
                <div class="print-platform-name">{{ printContent.platformName }}</div>
                <div class="print-platform-email">{{ printContent.platformEmail }}</div>
              </div>
            </div>
            <div class="print-doc-chip">{{ printContent.title || 'Statement' }}</div>
          </div>
        </div>

        <div class="print-meta-grid">
          <div class="print-meta-card">
            <div class="print-card-title">Patient Details</div>
            <div class="print-detail-grid">
              <div class="print-detail-item">
                <span class="print-detail-label">Patient</span>
                <span class="print-detail-value">{{ patientName }}</span>
              </div>
              <div class="print-detail-item" v-if="patientMrn">
                <span class="print-detail-label">MRN</span>
                <span class="print-detail-value">{{ patientMrn }}</span>
              </div>
              <div class="print-detail-item" v-if="careSummaryPatient?.address">
                <span class="print-detail-label">Address</span>
                <span class="print-detail-value">{{ careSummaryPatient.address }}</span>
              </div>
              <div class="print-detail-item" v-if="careSummaryPatient?.phone">
                <span class="print-detail-label">Phone</span>
                <span class="print-detail-value">{{ careSummaryPatient.phone }}</span>
              </div>
            </div>
          </div>

          <div class="print-meta-card">
            <div class="print-card-title">Document Details</div>
            <div class="print-detail-grid">
              <div class="print-detail-item">
                <span class="print-detail-label">Date</span>
                <span class="print-detail-value">{{ printContent.dateLabel }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.billNumber">
                <span class="print-detail-label">Bill Number</span>
                <span class="print-detail-value">{{ printContent.billNumber }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.status">
                <span class="print-detail-label">Status</span>
                <span class="print-detail-value" :style="{ color: printContent.statusColor, fontWeight: '700' }">{{ printContent.status }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.generatedBy">
                <span class="print-detail-label">Generated By</span>
                <span class="print-detail-value">{{ printContent.generatedBy }}</span>
              </div>
            </div>
          </div>
        </div>

        <div v-if="printContent.lineItems && printContent.lineItems.length" class="print-section print-section-spaced">
          <div class="print-section-head">
            <h3 class="print-section-title">Line Items</h3>
            <span class="print-section-caption">Detailed billable items and charges</span>
          </div>
          <table class="print-table">
            <thead>
              <tr><th>Description</th><th class="text-center">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr>
            </thead>
            <tbody>
              <tr v-for="(li, i) in printContent.lineItems" :key="i">
                <td>{{ li.label }}</td>
                <td class="text-center">{{ li.qty }} {{ li.unit || '' }}</td>
                <td class="text-right">{{ li.rate || '—' }}</td>
                <td class="text-right">{{ li.amount }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="print-bottom-row">
          <div class="print-note-card">
            <div class="print-card-title">Notes</div>
            <p class="print-note-copy">{{ printContent.notes || 'This billing document was generated from the AdhereMed homecare command centre.' }}</p>
          </div>

          <div class="print-summary-card">
            <div class="print-card-title">Financial Summary</div>
            <table class="print-summary-table">
              <tbody>
                <tr v-for="(r, i) in printContent.summary" :key="i" :class="{ 'print-summary-total': r.bold }">
                  <td class="print-summary-label">{{ r.label }}</td>
                  <td class="print-summary-value" :style="r.color ? 'color:' + r.color : ''">{{ r.value }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="print-footer">
          <p>{{ printContent.footer || '' }}</p>
          <p class="print-footer-powered">Powered by AdhereMed · info@adheremed.co</p>
        </div>
      </div>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="4000" location="top">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import adhereMedLogoUrl from '~/assets/images/logo.png'
import defaultLogoUrl from '~/assets/images/hos_default.png'
import { calcNews2, OXYGEN_DELIVERY_MODES, scoreRR, scoreSpO2Scale1, scoreSpO2Scale2, scoreOxygen, scoreSBP, scoreHR, scoreTemp, scoreConsciousness } from '~/composables/useAssessmentScoring'

const { $api } = useNuxtApp()
const route = useRoute()
const id = route.params.id
const auth = useAuthStore()

const tab = ref('overview')
const pageLoading = ref(true)
const savingVitals = ref(false)
const careSummaryData = ref(null)
const vitalsData = ref([])
const assessmentData = ref([])
// Per-type assessment scale histories (strictly-separate models, one list per scale)
const bradenAssessments = ref([])
const capriniAssessments = ref([])
const morseAssessments = ref([])
const mustAssessments = ref([])
const camAssessments = ref([])
const painAssessments = ref([])
const skinCareAssessments = ref([])
const gcsAssessments = ref([])
const diabetesBundleAssessments = ref([])
const hfBundleAssessments = ref([])
const pivcAssessments = ref([])
const enteralFeedingAssessments = ref([])
const urinaryCatheterAssessments = ref([])
const artificialAirwayAssessments = ref([])
const ASSESSMENT_TYPE_REFS = {
  braden: bradenAssessments, caprini: capriniAssessments, morse: morseAssessments,
  must: mustAssessments, cam: camAssessments, pain_reassess: painAssessments,
  skin_care: skinCareAssessments, gcs: gcsAssessments,
  diabetes_bundle: diabetesBundleAssessments, hf_bundle: hfBundleAssessments,
  pivc: pivcAssessments,
  enteral_feeding: enteralFeedingAssessments,
  urinary_catheter: urinaryCatheterAssessments,
  artificial_airway: artificialAirwayAssessments,
}
const ASSESSMENT_TYPE_ENDPOINTS = {
  braden: '/homecare/braden-assessments/', caprini: '/homecare/caprini-assessments/',
  morse: '/homecare/morse-assessments/', must: '/homecare/must-assessments/',
  cam: '/homecare/cam-assessments/', pain_reassess: '/homecare/pain-assessments/',
  skin_care: '/homecare/skin-care-assessments/', gcs: '/homecare/gcs-assessments/',
  diabetes_bundle: '/homecare/diabetes-bundle-assessments/', hf_bundle: '/homecare/hf-bundle-assessments/',
  pivc: '/homecare/pivc-assessments/',
  enteral_feeding: '/homecare/enteral-feeding-assessments/',
  urinary_catheter: '/homecare/urinary-catheter-assessments/',
  artificial_airway: '/homecare/artificial-airway-assessments/',
}
const patientNotes = ref([])
const treatmentPlans = ref([])
const tpMedications = ref([])
const treatmentPlansLoading = ref(false)
const companyProfile = ref(null)
const snack = reactive({ show: false, text: '', color: 'success' })

// --- Derived from care-summary ---
const careSummaryPatient = computed(() => careSummaryData.value?.patient || {})
const summary = computed(() => careSummaryData.value || {})
const patientName = computed(() => careSummaryPatient.value?.name || '—')
const patientMrn = computed(() => careSummaryPatient.value?.medical_record_number || '—')

// --- Derived from vitals ---
const latestVitals = computed(() => vitalsData.value.length ? vitalsData.value[0] : null)
const latestNews2 = computed(() => latestVitals.value?.news2 ?? null)
const lastVitalsTime = computed(() => latestVitals.value ? formatDateTime(latestVitals.value.recorded_at) : 'Never')
const lastVitalsTimeShort = computed(() => latestVitals.value ? formatShortDateTime(latestVitals.value.recorded_at) : '—')
const patientVitals = computed(() => vitalsData.value.slice(0, 20))

const riskLabel = computed(() => { const n = latestNews2.value; if (n == null) return 'LOW'; if (n >= 7) return 'HIGH'; if (n >= 5) return 'MEDIUM'; if (n > 0) return 'LOW-MED'; return 'LOW' })
const riskColor = computed(() => { const n = latestNews2.value; if (n == null) return 'teal'; if (n >= 7) return 'error'; if (n >= 5) return 'warning'; if (n > 0) return 'info'; return 'success' })
const riskHex = computed(() => ({ teal: '#0d9488', error: '#b91c1c', warning: '#d97706', info: '#0284c7', success: '#059669' })[riskColor.value] || '#0d9488')
const heroGradient = computed(() => `linear-gradient(135deg, #0c3d3a 0%, ${riskHex.value} 50%, #0ea5a4 80%)`)

const kpiCards = computed(() => [
  { label: 'NEWS2', value: latestNews2.value ?? '—', icon: 'mdi-alert', color: riskHex.value, valueClass: `text-${riskColor.value}` },
  { label: 'Braden', value: latestBraden.value?.total ?? '—', icon: 'mdi-human', color: '#d97706', valueClass: '' },
  { label: 'Vitals due', value: vitalsUrgencyText.value, icon: 'mdi-clock', color: parseFloat(vitalsProgressPct.value) >= 90 ? '#ef4444' : '#059669', valueClass: vitalsUrgencyClass.value },
  { label: 'Skin care', value: skinCareActive.value ? 'ACTIVE' : 'Standby', icon: 'mdi-bandage', color: skinCareActive.value ? '#ef4444' : '#64748b', valueClass: skinCareActive.value ? 'text-error' : '' },
  { label: 'Devices', value: activeDevices.value.length, icon: 'mdi-medical-bag', color: '#4f46e5', valueClass: '' },
  { label: 'Fluid Bal', value: fluidBalance.value + 'ml', icon: 'mdi-water', color: '#0891b2', valueClass: fluidBalanceClass.value },
])

// --- Notes ---
const doctorNotes = computed(() => patientNotes.value.filter(n => n.category === 'doctor'))
const nurseNotes = computed(() => patientNotes.value.filter(n => n.category === 'nurse_hca'))

function renderNoteHtml(content) {
  if (!content) return ''
  if (/<\/?(p|div|span|ul|ol|li|h[1-6]|br|strong|em|a|blockquote)\b/i.test(content)) return content
  const lines = String(content).split('\n')
  const out = []
  for (const line of lines) {
    if (/^\s*$/.test(line)) continue
    let escaped = String(line).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    escaped = escaped.replace(/`([^`]+)`/g, '<code>$1</code>')
    escaped = escaped.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    escaped = escaped.replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')
    out.push(`<p>${escaped}</p>`)
  }
  return out.join('\n')
}

// --- Treatment Plans ---
const activeTreatmentPlans = computed(() => treatmentPlans.value.filter(p => p.status === 'active'))
const pausedTreatmentPlans = computed(() => treatmentPlans.value.filter(p => p.status === 'paused'))
const completedTreatmentPlans = computed(() => treatmentPlans.value.filter(p => p.status === 'completed'))
const totalMedicationSchedules = computed(() => Object.values(tpMedicationsMap.value).reduce((s, m) => s + m.length, 0))
const activeMedicationSchedules = computed(() => {
  const all = []
  Object.values(tpMedicationsMap.value).forEach(meds => {
    meds.forEach(m => { if (m.is_active) all.push(m) })
  })
  return all
})
const totalPendingDoses = computed(() => activeMedicationSchedules.value.reduce((s, m) => s + (m.upcoming_doses || 0), 0))
const tpMedicationsMap = computed(() => {
  const map = {}
  tpMedications.value.forEach(m => {
    const planId = m.treatment_plan
    if (!map[planId]) map[planId] = []
    map[planId].push(m)
  })
  return map
})

function tpStatusColor(status) {
  return { active: 'success', paused: 'warning', completed: 'teal', cancelled: 'grey' }[status] || 'grey'
}
function tpStatusLabel(status) {
  return { active: 'Active', paused: 'Paused', completed: 'Completed', cancelled: 'Cancelled' }[status] || status
}

async function loadTreatmentPlans() {
  treatmentPlansLoading.value = true
  try {
    const [plansRes, medsRes] = await Promise.all([
      $api.get('/homecare/treatment-plans/', { params: { patient: id, page_size: 50 } }),
      $api.get('/homecare/medication-schedules/', { params: { patient: id, page_size: 200, is_active: true } }),
    ])
    treatmentPlans.value = plansRes.data?.results || (Array.isArray(plansRes.data) ? plansRes.data : [])
    tpMedications.value = medsRes.data?.results || (Array.isArray(medsRes.data) ? medsRes.data : [])
  } catch (e) {
    treatmentPlans.value = []
    tpMedications.value = []
  } finally {
    treatmentPlansLoading.value = false
  }
}

// --- Treatment Plan View/Edit Dialog ---
const tpViewDialog = ref(false)
const tpEditMode = ref(false)
const tpSaving = ref(false)
const tpSelected = ref(null)
const tpDetailTab = ref('overview')
const tpEditForm = reactive({ title: '', diagnosis: '', start_date: '', end_date: '', status: 'active', notes: '' })
const tpEditGoals = ref([])

// --- Treatment Plan Create Dialog ---
const tpCreateDialog = ref(false)
const tpCreateSaving = ref(false)
const tpCreateForm = reactive({ title: '', diagnosis: '', start_date: new Date().toISOString().slice(0, 10), end_date: '', status: 'active', notes: '' })
const tpCreateGoals = ref([])

const PLAN_TITLE_OPTIONS = [
  'Diabetes Management Plan', 'Hypertension Care Plan', 'Post-Surgical Recovery Plan',
  'Wound Care Plan', 'Palliative Care Plan', 'Stroke Rehabilitation Plan',
  'Chronic Kidney Disease Plan', 'COPD Management Plan', 'Heart Failure Care Plan',
  'Dementia Support Plan', 'Elderly Daily Living Support', 'Maternal & Newborn Care Plan',
  'Paediatric Home Care Plan', 'Mental Health Support Plan', 'Physiotherapy & Mobility Plan',
  'Nutritional Support Plan', 'Medication Adherence Plan',
]

const tpSmartGoalOptions = computed(() => {
  const dx = (tpCreateForm.diagnosis || '').toLowerCase().trim()
  const goals = []
  // Generic goals always available
  goals.push(
    '100% medication adherence verified weekly',
    'No hospital readmission within 30 days of discharge',
    'Independent in activities of daily living (ADLs) within 8 weeks',
    'Pain score =3/10 within 2 weeks',
    'Achieve restful sleep =6 hours/night within 4 weeks',
  )
  if (dx) {
    if (dx.includes('diabetes') || dx.includes('dm')) goals.push('Achieve HbA1c <7.0% within 3 months', 'Daily blood glucose monitoring logged for 90 days')
    if (dx.includes('hypertension') || dx.includes('htn')) goals.push('Reduce blood pressure to <130/80 mmHg within 8 weeks', 'Daily home BP readings logged for 12 weeks')
    if (dx.includes('heart') || dx.includes('cardiac')) goals.push('No hospital readmission for cardiac cause within 30 days', 'NYHA class improved by 1 grade within 12 weeks')
    if (dx.includes('copd') || dx.includes('asthma')) goals.push('Improve oxygen saturation to =95% on room air within 4 weeks', 'Smoking cessation maintained for 90 days')
    if (dx.includes('stroke') || dx.includes('cva')) goals.push('Walk independently for 15 minutes daily within 6 weeks', 'Improve Barthel Index score by 20 points within 12 weeks')
    if (dx.includes('wound') || dx.includes('ulcer')) goals.push('Achieve full wound closure within 4 weeks', 'No signs of wound infection over 30 days')
  }
  return [...new Set(goals)]
})
const tpStatusOptions = [
  { label: 'Active', value: 'active' },
  { label: 'Paused', value: 'paused' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]
const TRANSTIONS = {
  active: [
    { value: 'paused', label: 'Pause', icon: 'mdi-pause', color: 'warning' },
    { value: 'completed', label: 'Complete', icon: 'mdi-check', color: 'success' },
    { value: 'cancelled', label: 'Cancel', icon: 'mdi-cancel', color: 'grey' },
  ],
  paused: [
    { value: 'active', label: 'Resume', icon: 'mdi-play', color: 'success' },
    { value: 'cancelled', label: 'Cancel', icon: 'mdi-cancel', color: 'grey' },
  ],
  completed: [],
  cancelled: [{ value: 'active', label: 'Reactivate', icon: 'mdi-restart', color: 'success' }],
}

function openTpViewDialog(plan) {
  tpSelected.value = plan
  tpEditMode.value = false
  tpDetailTab.value = 'overview'
  tpViewDialog.value = true
}

function openTpEditDialog(plan) {
  tpSelected.value = plan
  tpEditMode.value = true
  tpDetailTab.value = 'edit'
  tpEditForm.title = plan.title || ''
  tpEditForm.diagnosis = plan.diagnosis || ''
  tpEditForm.start_date = plan.start_date || ''
  tpEditForm.end_date = plan.end_date || ''
  tpEditForm.status = plan.status || 'active'
  tpEditForm.notes = plan.notes || ''
  tpEditGoals.value = Array.isArray(plan.goals) ? [...plan.goals] : []
  tpViewDialog.value = true
}

function tpTransitionsFor(plan) {
  return TRANSTIONS[plan?.status] || []
}

async function tpChangeStatus(plan, newStatus) {
  tpSaving.value = true
  try {
    await $api.patch(`/homecare/treatment-plans/${plan.id}/`, { status: newStatus })
    plan.status = newStatus
    notify(`Plan ${tpStatusLabel(newStatus).toLowerCase()} successfully`, 'success')
    await loadTreatmentPlans()
  } catch (e) {
    notify('Failed: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    tpSaving.value = false
  }
}

async function tpSaveEdit() {
  if (!tpEditForm.title) return notify('Plan title is required', 'warning')
  tpSaving.value = true
  try {
    const payload = { ...tpEditForm, goals: tpEditGoals.value }
    await $api.patch(`/homecare/treatment-plans/${tpSelected.value.id}/`, payload)
    Object.assign(tpSelected.value, payload)
    notify('Plan updated successfully', 'success')
    tpEditMode.value = false
    tpDetailTab.value = 'overview'
    await loadTreatmentPlans()
  } catch (e) {
    notify('Save failed: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    tpSaving.value = false
  }
}

function openTpCreateDialog() {
  tpCreateForm.title = ''
  tpCreateForm.diagnosis = (summary.value?.patient?.primary_diagnosis)
    || (typeof careSummaryPatient.value?.primary_diagnosis === 'string' ? careSummaryPatient.value.primary_diagnosis : '')
    || ''
  tpCreateForm.start_date = new Date().toISOString().slice(0, 10)
  tpCreateForm.end_date = ''
  tpCreateForm.status = 'active'
  tpCreateForm.notes = ''
  tpCreateGoals.value = []
  tpCreateDialog.value = true
}

async function tpCreateSave() {
  if (!tpCreateForm.title || !tpCreateForm.title.trim()) return notify('Plan title is required', 'warning')
  tpCreateSaving.value = true
  try {
    await $api.post('/homecare/treatment-plans/', {
      patient: Number(id),
      title: tpCreateForm.title.trim(),
      diagnosis: tpCreateForm.diagnosis || '',
      start_date: tpCreateForm.start_date,
      end_date: tpCreateForm.end_date || null,
      status: tpCreateForm.status,
      goals: tpCreateGoals.value,
      notes: tpCreateForm.notes,
    })
    notify('Treatment plan created successfully', 'success')
    tpCreateDialog.value = false
    await loadTreatmentPlans()
  } catch (e) {
    notify('Failed to create: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    tpCreateSaving.value = false
  }
}

// --- NEWS2 ---
const news2GaugePct = computed(() => Math.min((latestNews2.value || 0) / 20 * 100, 100))
const gaugeDasharray = computed(() => `${(news2GaugePct.value / 100) * 326.7} 326.7`)
const news2Breakdown = computed(() => {
  const v = latestVitals.value
  if (!v) return []
  return calcNews2({
    respiratory_rate: v.rr, spo2: v.spo2, scale2: v.scale2,
    oxygen: v.oxygen || 'Room air', systolic_bp: v.systolic,
    heart_rate: v.pulse, temperature: v.temperature,
    consciousness: v.consciousness || 'A'
  }).breakdown
})

// --- Vitals schedule ---
const vitalsFrequency = computed(() => { const n = latestNews2.value; if (n == null) return 'q4h (default)'; if (n >= 7) return 'Continuous'; if (n >= 5) return 'Hourly'; if (n >= 3) return 'q2h'; return 'q4h' })
const vitalsIntervalMs = computed(() => { const n = latestNews2.value; if (n == null) return 4*3600*1000; if (n >= 7) return 15*60*1000; if (n >= 5) return 1*3600*1000; if (n >= 3) return 2*3600*1000; return 4*3600*1000 })
const nextVitalsDue = computed(() => { if (!latestVitals.value) return 'Now'; const next = new Date(new Date(latestVitals.value.recorded_at).getTime() + vitalsIntervalMs.value); return formatDateTime(next.toISOString()) })
const nextVitalsTimeShort = computed(() => { if (!latestVitals.value) return 'Now'; const next = new Date(new Date(latestVitals.value.recorded_at).getTime() + vitalsIntervalMs.value); return formatTime(next.toISOString()) })
const vitalsProgressPct = computed(() => { if (!latestVitals.value) return '100%'; const last = new Date(latestVitals.value.recorded_at).getTime(); const elapsed = Date.now() - last; return Math.round(Math.min((elapsed / vitalsIntervalMs.value) * 100, 100)) + '%' })
const vitalsProgressColor = computed(() => { const pct = parseFloat(vitalsProgressPct.value); if (pct >= 90) return '#ef4444'; if (pct >= 70) return '#f59e0b'; if (pct >= 50) return '#0ea5e9'; return '#059669' })
const vitalsUrgencyClass = computed(() => { const pct = parseFloat(vitalsProgressPct.value); if (pct >= 90) return 'text-error'; if (pct >= 70) return 'text-warning'; return 'text-success' })
const vitalsUrgencyText = computed(() => { const pct = parseFloat(vitalsProgressPct.value); if (pct >= 100) return 'OVERDUE!'; if (pct >= 90) return 'Due now'; if (pct >= 70) return 'Due soon'; return 'On schedule' })

// --- Braden ---
const latestBraden = computed(() => {
  const b = bradenAssessments.value[0]
  if (!b) return null
  return { total: b.total, risk_level: b.risk_level || bradenRiskLabel(b.total) }
})
const latestBradenSubs = computed(() => {
  const b = bradenAssessments.value[0]
  if (!b) return {}
  return extractBradenSubscales(b)
})
const bradenColor = computed(() => { const t = latestBraden.value?.total; if (t == null) return '#64748b'; if (t <= 9) return '#b91c1c'; if (t <= 12) return '#ef4444'; if (t <= 18) return '#d97706'; return '#059669' })
const bradenChipColor = computed(() => { const t = latestBraden.value?.total; if (t == null) return 'grey'; if (t <= 9) return 'error'; if (t <= 12) return 'error'; if (t <= 18) return 'warning'; return 'success' })
const bradenGaugePct = computed(() => Math.min(((latestBraden.value?.total || 0) / 23) * 100, 100))
const bradenDasharray = computed(() => `${(bradenGaugePct.value / 100) * 326.7} 326.7`)
const bradenLowAlert = computed(() => latestBraden.value?.total != null && latestBraden.value.total <= 13)
const lastBradenAssessment = computed(() => bradenAssessments.value[0] || null)
const lastBradenTimeShort = computed(() => lastBradenAssessment.value ? formatShortDateTime(lastBradenAssessment.value.assessed_at) : '—')
const nextBradenDue = computed(() => { if (!lastBradenAssessment.value) return 'Now'; const next = new Date(new Date(lastBradenAssessment.value.assessed_at).getTime() + 12*3600*1000); return formatDateTime(next.toISOString()) })
const nextBradenTimeShort = computed(() => { if (!lastBradenAssessment.value) return 'Now'; const next = new Date(new Date(lastBradenAssessment.value.assessed_at).getTime() + 12*3600*1000); return formatTime(next.toISOString()) })
const bradenProgressPct = computed(() => { if (!lastBradenAssessment.value) return '100%'; const elapsed = Date.now() - new Date(lastBradenAssessment.value.assessed_at).getTime(); return Math.round(Math.min((elapsed / (12*3600*1000)) * 100, 100)) + '%' })
const bradenProgressColor = computed(() => { const pct = parseFloat(bradenProgressPct.value); if (pct >= 90) return '#ef4444'; if (pct >= 70) return '#f59e0b'; return '#059669' })
const bradenUrgencyClass = computed(() => { const pct = parseFloat(bradenProgressPct.value); if (pct >= 90) return 'text-error'; if (pct >= 70) return 'text-warning'; return 'text-success' })
const bradenUrgencyText = computed(() => { const pct = parseFloat(bradenProgressPct.value); if (pct >= 100) return 'OVERDUE!'; if (pct >= 90) return 'Due now'; if (pct >= 70) return 'Due soon'; return 'On schedule' })

// --- Morse (latest, used in KPI/quick-score/worklist strips) ---
const latestMorse = computed(() => morseAssessments.value[0] || null)

// --- Braden history helpers ---
function bradenScoreColor(total) { if (total == null) return '#64748b'; if (total <= 9) return '#b91c1c'; if (total <= 12) return '#ef4444'; if (total <= 18) return '#d97706'; return '#059669' }
function bradenScoreChipColor(total) { if (total == null) return 'grey'; if (total <= 9) return 'error'; if (total <= 12) return 'error'; if (total <= 18) return 'warning'; return 'success' }
function extractBradenSubscales(braden) {
  if (!braden) return {}
  const { sensory, moisture, activity, mobility, nutrition, friction } = braden
  const subs = { sensory, moisture, activity, mobility, nutrition, friction }
  Object.keys(subs).forEach(k => { if (subs[k] == null) delete subs[k] })
  return subs
}
function bradenSubscaleLabel(key) { return BRADEN_FIELD_DEFS[key]?.title || key }

// --- Skin care ---
const skinCareActive = computed(() => bradenLowAlert.value)
const skinCareItems = ref([
  { key: 'reposition', label: 'Reposition patient (q2h)', icon: 'mdi-arrow-decision', done: false, doneTime: '' },
  { key: 'surface', label: 'Specialty support surface check', icon: 'mdi-mattress', done: false, doneTime: '' },
  { key: 'moisture', label: 'Skin moisture management', icon: 'mdi-water-percent', done: false, doneTime: '' },
  { key: 'nutrition', label: 'Nutritional consult / intake', icon: 'mdi-food-apple', done: false, doneTime: '' },
  { key: 'heels', label: 'Heel protection devices', icon: 'mdi-shoe-sneaker', done: false, doneTime: '' },
  { key: 'inspect', label: 'Full skin inspection', icon: 'mdi-magnify', done: false, doneTime: '' },
])
const lastSkinCareTime = ref(null)
const lastSkinCareTimeShort = computed(() => lastSkinCareTime.value ? formatTime(lastSkinCareTime.value) : '—')
const nextSkinCareTimeShort = computed(() => { if (!lastSkinCareTime.value) return 'Now'; return formatTime(new Date(new Date(lastSkinCareTime.value).getTime() + 4*3600*1000).toISOString()) })
const skinCareProgressPct = computed(() => { if (!lastSkinCareTime.value) return '100%'; const elapsed = Date.now() - new Date(lastSkinCareTime.value).getTime(); return Math.round(Math.min((elapsed / (4*3600*1000)) * 100, 100)) + '%' })
const skinCareProgressColor = computed(() => { const pct = parseFloat(skinCareProgressPct.value); if (pct >= 90) return '#ef4444'; if (pct >= 70) return '#f59e0b'; return '#059669' })
const skinCareUrgencyClass = computed(() => { const pct = parseFloat(skinCareProgressPct.value); if (pct >= 90) return 'text-error'; if (pct >= 70) return 'text-warning'; return 'text-success' })
const skinCareUrgencyText = computed(() => { if (!skinCareActive.value) return 'Inactive — Braden > 12'; const pct = parseFloat(skinCareProgressPct.value); if (pct >= 100) return 'OVERDUE!'; if (pct >= 90) return 'Due now'; if (pct >= 70) return 'Due soon'; return 'On schedule' })

function toggleSkinCareItem(key, val) { const item = skinCareItems.value.find(i => i.key === key); if (item) item.doneTime = val ? formatTime(new Date().toISOString()) : '' }
function completeSkinCare() { lastSkinCareTime.value = new Date().toISOString(); skinCareItems.value.forEach(i => { i.done = false; i.doneTime = '' }); notify('Skin care bundle completed!', 'success') }

// --- Clinical ---
const allClinicalDefs = [
  { key: 'neuro', label: 'Neurological Check', icon: 'mdi-brain', type: 'select', options: ['Alert', 'Drowsy', 'Confused', 'Unresponsive'], value: 'Alert', description: 'GCS / AVPU assessment' },
  { key: 'cardio', label: 'Cardiovascular', icon: 'mdi-heart', type: 'select', options: ['Normal', 'Irregular', 'Tachycardic', 'Bradycardic'], value: 'Normal', description: 'Heart sounds and rhythm' },
  { key: 'resp', label: 'Respiratory', icon: 'mdi-lungs', type: 'select', options: ['Clear', 'Crackles', 'Wheezes', 'Diminished'], value: 'Clear', description: 'Breath sounds assessment' },
  { key: 'gi', label: 'Gastrointestinal', icon: 'mdi-stomach', type: 'select', options: ['Normal', 'Distended', 'Tender', 'No BS'], value: 'Normal', description: 'Abdominal assessment' },
  { key: 'wound', label: 'Wound Assessment', icon: 'mdi-bandage', type: 'text', value: '', description: 'Wound location, size, drainage' },
  { key: 'pain', label: 'Pain Reassessment', icon: 'mdi-pain', type: 'number', unit: '/10', value: null, description: 'Pain score 0-10 post-intervention' },
  { key: 'mobility', label: 'Mobility', icon: 'mdi-walk', type: 'select', options: ['Independent', 'Assisted', 'Bedbound'], value: 'Independent', description: 'Patient mobility status' },
]
const clinicalComponents = ref(allClinicalDefs.slice(0, 3).map(d => ({ ...d, active: true, lastDone: '' })).concat(allClinicalDefs.slice(3).map(d => ({ ...d, active: false, lastDone: '' }))))
const activeClinicalComponents = computed(() => clinicalComponents.value.filter(c => c.active))
const showAddClinical = ref(false)
const newClinical = reactive({ key: '' })
const availableClinicals = computed(() => allClinicalDefs.filter(d => !clinicalComponents.value.find(cc => cc.key === d.key && cc.active)))
function removeClinical(key) { const c = clinicalComponents.value.find(cc => cc.key === key); if (c) c.active = false }
function markClinicalDone(key) { const c = clinicalComponents.value.find(cc => cc.key === key); if (c) c.lastDone = formatTime(new Date().toISOString()); notify(`${c?.label || key} marked done`, 'success') }
function addClinical() { if (!newClinical.key) return; const c = clinicalComponents.value.find(cc => cc.key === newClinical.key); if (c) { c.active = true; showAddClinical.value = false; return }; showAddClinical.value = false }

// --- Fluid Balance ---
const fluidEntries = ref([])
const INTAKE_TYPES = ['Oral fluids', 'IV fluids', 'Enteral feed', 'Blood products', 'TPN', 'Flushes']
const OUTPUT_TYPES = ['Urine', 'Drain', 'Vomit', 'Diarrhea', 'NG aspirate', 'Blood loss', 'Other']
const FLUID_ROUTES = ['Oral', 'IV peripheral', 'IV central', 'NG tube', 'PEG tube', 'Other']
const fluidIntake = computed(() => fluidEntries.value.filter(f => f.type === 'intake').reduce((s, f) => s + (f.amount || 0), 0))
const fluidOutput = computed(() => fluidEntries.value.filter(f => f.type === 'output').reduce((s, f) => s + (f.amount || 0), 0))
const fluidBalance = computed(() => fluidIntake.value - fluidOutput.value)
const fluidBalanceClass = computed(() => fluidBalance.value > 500 ? 'text-blue' : fluidBalance.value < -500 ? 'text-error' : fluidBalance.value < 0 ? 'text-warning' : 'text-success')
const fluidDialog = reactive({ show: false, type: 'intake', subtype: '', route: 'Oral', amount: null })
function openFluidEntry(type) { fluidDialog.type = type; fluidDialog.subtype = ''; fluidDialog.route = 'Oral'; fluidDialog.amount = null; fluidDialog.show = true }
function saveFluidEntry() {
  if (!fluidDialog.amount) return notify('Enter an amount', 'warning')
  fluidEntries.value.unshift({ id: Date.now(), type: fluidDialog.type, subtype: fluidDialog.subtype || (fluidDialog.type==='intake'?INTAKE_TYPES[0]:OUTPUT_TYPES[0]), route: fluidDialog.type==='intake'?fluidDialog.route:null, amount: fluidDialog.amount, timestamp: new Date().toISOString() })
  fluidDialog.show = false; notify('Fluid entry saved', 'success')
}
function deleteFluidEntry(f) { fluidEntries.value = fluidEntries.value.filter(e => e.id !== f.id); notify('Entry deleted', 'info') }

// --- Assessment Worklist ---
const ASSESSMENT_TYPES = [
  { key: 'initial', label: 'Initial Assessment', description: 'Baseline patient evaluation', icon: 'mdi-clipboard-pulse', color: 'teal', frequency: 'once', freqOptions: ['once'], bgColor: '#f0fdfa', avatarBg: 'rgba(13,148,136,0.12)', avatarColor: '#0f766e' },
  { key: 'braden', label: 'Braden Scale', description: 'Pressure injury risk', icon: 'mdi-human', color: 'warning', frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#fffbeb', avatarBg: 'rgba(217,119,6,0.12)', avatarColor: '#b45309' },
  { key: 'caprini', label: 'Caprini Score', description: 'VTE risk assessment', icon: 'mdi-heart-flash', color: 'error', frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs','Every 24 hrs','Every 48 hrs'], bgColor: '#fef2f2', avatarBg: 'rgba(185,28,28,0.12)', avatarColor: '#b91c1c' },
  { key: 'morse', label: 'Morse Fall Scale', description: 'Fall risk screening', icon: 'mdi-walk', color: 'orange', frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs','Every 24 hrs','Every 48 hrs'], bgColor: '#fff7ed', avatarBg: 'rgba(234,88,12,0.12)', avatarColor: '#c2410c' },
  { key: 'must', label: 'MUST', description: 'Malnutrition screening', icon: 'mdi-scale-bathroom', color: 'lime', frequency: 'Every 24 hrs', freqOptions: ['Every 24 hrs','Every 48 hrs','Every week'], bgColor: '#f7fee7', avatarBg: 'rgba(77,124,15,0.12)', avatarColor: '#4d7c0f' },
  { key: 'cam', label: 'CAM (Confusion)', description: 'Delirium assessment', icon: 'mdi-brain', color: 'deep-purple', frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs','Every 24 hrs','Every 48 hrs'], bgColor: '#faf5ff', avatarBg: 'rgba(107,33,168,0.12)', avatarColor: '#6b21a8' },
  { key: 'diabetes_bundle', label: 'Diabetes Bundle', description: 'Glucose monitoring & insulin', icon: 'mdi-water-opacity', color: 'blue', frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#eff6ff', avatarBg: 'rgba(37,99,235,0.12)', avatarColor: '#1d4ed8' },
  { key: 'hf_bundle', label: 'Heart Failure Bundle', description: 'Fluid status, weight, BNP', icon: 'mdi-heart-circle', color: 'pink', frequency: 'Every 12 hrs', freqOptions: ['Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#fdf2f8', avatarBg: 'rgba(190,24,93,0.12)', avatarColor: '#9d174d' },
  { key: 'skin_care', label: 'Skin Care Bundle', description: 'q4h pressure care protocol', icon: 'mdi-bandage', color: 'red-darken-2', frequency: 'Every 4 hrs', freqOptions: ['Every 2 hrs','Every 4 hrs','Every 6 hrs','Every 8 hrs'], bgColor: '#fef2f2', avatarBg: 'rgba(225,29,72,0.12)', avatarColor: '#e11d48' },
  { key: 'pain_reassess', label: 'Pain Reassessment', description: 'Post-intervention pain score', icon: 'mdi-pain', color: 'red', frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs'], bgColor: '#fff1f2', avatarBg: 'rgba(190,18,60,0.12)', avatarColor: '#9f1239' },
  { key: 'gcs', label: 'GCS', description: 'Level of consciousness', icon: 'mdi-eye-refresh', color: 'indigo', frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#eef2ff', avatarBg: 'rgba(67,56,202,0.12)', avatarColor: '#4338ca' },
  { key: 'pivc', label: 'PIVC Assessment', description: 'Peripheral IV catheter — VIP score & maintenance', icon: 'mdi-needle', color: 'cyan', frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#ecfeff', avatarBg: 'rgba(6,182,212,0.12)', avatarColor: '#0891b2' },
  { key: 'enteral_feeding', label: 'Enteral Feeding', description: 'Enteral access device maintenance bundle', icon: 'mdi-food-tube', color: 'amber', frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#fffbeb', avatarBg: 'rgba(217,119,6,0.12)', avatarColor: '#b45309' },
  { key: 'urinary_catheter', label: 'Urinary Catheter', description: 'CAUTI prevention maintenance bundle', icon: 'mdi-water-pipe', color: 'teal-darken-1', frequency: 'Every 24 hrs', freqOptions: ['Every 8 hrs','Every 12 hrs','Every 24 hrs','Every 48 hrs'], bgColor: '#f0fdfa', avatarBg: 'rgba(13,148,136,0.12)', avatarColor: '#0f766e' },
  { key: 'artificial_airway', label: 'Artificial Airway', description: 'Tracheostomy & VAP prevention bundle', icon: 'mdi-air-humidifier', color: 'cyan-darken-1', frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs','Every 6 hrs','Every 8 hrs','Every 12 hrs','Every 24 hrs'], bgColor: '#ecfeff', avatarBg: 'rgba(6,182,212,0.12)', avatarColor: '#0891b2' },
]

const assessmentWorklistEntries = ref([])
const showAddAssessmentDialog = ref(false)
const showAddSingleDialog = ref(false)
const showRecordDialog = ref(false)
const showAssessmentHistoryDialog = ref(false)
const addSingleType = ref(null)
const addSingleStartTime = ref('')
const addSingleFrequency = ref('')
const addSingleCustomFreq = ref('')
const recordTypeKey = ref(null)
const assessmentHistoryTypeKey = ref(null)
const selectedAssessmentKey = ref(null)
const expandedHistoryIds = ref(new Set())
const recordForm = reactive({
  assessed_at: new Date().toISOString().slice(0, 16), notes: '',
  must_height: null, must_weight: null, must_bmi: null, must_bmi_score: null,
  must_weight_loss_pct: null, must_loss_score: null, must_acute_none: false, must_acute_score: null,
  braden_sensory: null, braden_moisture: null, braden_activity: null, braden_mobility: null,
  braden_nutrition: null, braden_friction: null,
  morse_history_falls: false, morse_secondary_dx: false, morse_ambulatory_aid: '', morse_iv_lock: false,
  morse_gait: '', morse_mental_status: '',
  caprini_points: null,
  cam_acute_onset: false, cam_inattention: false, cam_disorganized: false, cam_altered: false,
  skin_reposition: false, skin_surface: false, skin_moisture: false,
  skin_nutrition: false, skin_heels: false, skin_inspect: false,
  gcs_eyes: null, gcs_verbal: null, gcs_motor: null,
  pain_score: null,
  db_glucose: null, db_ketones: null,
  hf_weight: null, hf_fluid_balance: null, hf_spo2: null,
})
// ── Comprehensive Pain Assessment form ──
const painForm = reactive({
  tool_type: 'nrs', score: null, worst_pain_24h: null, least_pain_24h: null,
  average_pain: null, acceptable_pain_goal: null,
  vas_mm: null, faces_choice: null, faces_description: '',
  flacc_face: null, flacc_legs: null, flacc_activity: null, flacc_cry: null, flacc_consolability: null,
  painad_breathing: null, painad_negative_vocal: null, painad_facial: null, painad_body_language: null, painad_consolability: null,
  provocation_factors: [], palliation_factors: [], quality_descriptors: [], quality_other: '',
  pain_locations: [], has_radiation: null, radiation_pathway: '',
  onset_type: '', pain_pattern: '', pain_duration: '', pain_frequency: '',
  impact_sleep: null, impact_adl: null, impact_mood: null, impact_appetite: null, impact_other: '',
  pre_treatment_score: null, post_treatment_score: null, treatment_given: '',
})
const painPqrstPanel = ref([])
// Pain tool options
const painToolOptions = [
  { title: 'Numeric Rating Scale (0–10)', value: 'nrs' },
  { title: 'Visual Analog Scale', value: 'vas' },
  { title: 'Wong-Baker FACES', value: 'faces' },
  { title: 'FLACC (Face, Legs, Activity, Cry, Consolability)', value: 'flacc' },
  { title: 'PAINAD (Pain in Advanced Dementia)', value: 'painad' },
]
const painNrsLevels = [
  { label: 'None', range: '0', icon: 'mdi-emoticon-happy', color: '#059669' },
  { label: 'Mild', range: '1–3', icon: 'mdi-emoticon-neutral', color: '#65a30d' },
  { label: 'Moderate', range: '4–6', icon: 'mdi-emoticon-sad', color: '#d97706' },
  { label: 'Severe', range: '7–10', icon: 'mdi-emoticon-cry', color: '#b91c1c' },
]
const painFacesOptions = [
  { value: 0, emoji: '😀', label: 'No Hurt' },
  { value: 2, emoji: '🙂', label: 'Little Bit' },
  { value: 4, emoji: '😐', label: 'Little More' },
  { value: 6, emoji: '😟', label: 'Even More' },
  { value: 8, emoji: '😢', label: 'Whole Lot' },
  { value: 10, emoji: '😭', label: 'Worst' },
]
const painBodyRegions = ['Head','Neck','Shoulder','Chest','Abdomen','Lower back','Hip','Knee','Foot','Arm','Hand','Leg','Ankle','Elbow','Wrist','Other']
const painProvocationOptions = ['Movement','Coughing','Eating','Breathing','Walking','Dressing change','Touch','Cold','Heat','Stress','Unknown','Other']
const painPalliationOptions = ['Rest','Medication','Position change','Ice','Heat','Massage','Relaxation','Elevation','Other']
const painQualityOptions = ['Sharp','Dull','Aching','Burning','Stabbing','Crushing','Pressure','Cramping','Throbbing','Shooting','Electric','Tingling','Squeezing','Constant','Intermittent']
// FLACC item options
function flaccItems(category) {
  const m = {
    'Face': [{title:'0 – No expression',value:0},{title:'1 – Occasional grimace',value:1},{title:'2 – Frequent frown/clenched jaw',value:2}],
    'Legs': [{title:'0 – Relaxed',value:0},{title:'1 – Uneasy/restless',value:1},{title:'2 – Kicking or drawn up',value:2}],
    'Activity': [{title:'0 – Quiet',value:0},{title:'1 – Squirming',value:1},{title:'2 – Arched/rigid',value:2}],
    'Cry': [{title:'0 – None',value:0},{title:'1 – Moans',value:1},{title:'2 – Crying steadily',value:2}],
    'Consolability': [{title:'0 – Content',value:0},{title:'1 – Reassured by touching/talking',value:1},{title:'2 – Difficult to console',value:2}],
  }
  return m[category] || [{title:'0',value:0},{title:'1',value:1},{title:'2',value:2}]
}
function painadItems(cat) {
  const m = {
    'Breathing': [{title:'0 – Normal',value:0},{title:'1 – Occasional labored',value:1},{title:'2 – Noisy labored / Cheyne-Stokes',value:2}],
    'Vocalisation': [{title:'0 – None',value:0},{title:'1 – Occasional moan/groan',value:1},{title:'2 – Repeated calling out / loud moaning',value:2}],
    'Facial': [{title:'0 – Smiling/inexpressive',value:0},{title:'1 – Sad/frightened/frowning',value:1},{title:'2 – Grimacing',value:2}],
    'Body Language': [{title:'0 – Relaxed',value:0},{title:'1 – Tense/distressed',value:1},{title:'2 – Rigid/fists clenched',value:2}],
    'Consolability': [{title:'0 – No need',value:0},{title:'1 – Distracted/reassured by voice/touch',value:1},{title:'2 – Unable to console',value:2}],
  }
  return m[cat] || [{title:'0',value:0},{title:'1',value:1},{title:'2',value:2}]
}
const flaccTotal = computed(() => ['flacc_face','flacc_legs','flacc_activity','flacc_cry','flacc_consolability'].reduce((s,k)=>s+(Number(painForm[k])||0),0))
const painadTotal = computed(() => ['painad_breathing','painad_negative_vocal','painad_facial','painad_body_language','painad_consolability'].reduce((s,k)=>s+(Number(painForm[k])||0),0))
const painScoreChipColor = computed(() => { const s=painForm.score; return s==null?'grey':s===0?'success':s<=3?'#65a30d':s<=6?'warning':'error' })
const painScoreSliderColor = computed(() => { const s=painForm.score; return s==null?'#059669':s<=3?'#65a30d':s<=6?'#d97706':s<=10?'#b91c1c':'#059669' })
function painCategoryLabel(score) { if(score==null)return'';if(score===0)return'None';if(score<=3)return'Mild';if(score<=6)return'Moderate';return'Severe' }
function painScoreChipColorFor(score) { if(score==null)return'grey';if(score===0)return'teal';if(score<=3)return'#65a30d';if(score<=6)return'warning';return'error' }
function resetPainForm() {
  Object.assign(painForm, { tool_type:'nrs',score:null,worst_pain_24h:null,least_pain_24h:null,average_pain:null,acceptable_pain_goal:null,
    vas_mm:null,faces_choice:null,faces_description:'',flacc_face:null,flacc_legs:null,flacc_activity:null,flacc_cry:null,flacc_consolability:null,
    painad_breathing:null,painad_negative_vocal:null,painad_facial:null,painad_body_language:null,painad_consolability:null,
    provocation_factors:[],palliation_factors:[],quality_descriptors:[],quality_other:'',pain_locations:[],has_radiation:null,radiation_pathway:'',
    onset_type:'',pain_pattern:'',pain_duration:'',pain_frequency:'',impact_sleep:null,impact_adl:null,impact_mood:null,impact_appetite:null,impact_other:'',
    pre_treatment_score:null,post_treatment_score:null,treatment_given:'' })
  painPqrstPanel.value = []
}
// ── PIVC Assessment form ──
const pivcForm = reactive({
  assessment_type: 'routine', catheter_id: '',
  catheter_site: '', vein: '', gauge: '', insertion_date: null,
  current_infusion: '', previous_vip_score: null,
  last_flush: null, last_dressing_change: null,
  pain_level: '', pain_score_nrs: null,
  pain_quality: '', pain_onset: '', pain_duration: '',
  erythema: '', swelling: '', swelling_circumference_cm: null,
  warmth: '', induration: '',
  palpable_cord: '', drainage_type: '', drainage_quantity: '',
  skin_integrity: '', leakage: '',
  catheter_patency: '', blood_return: '',
  limb_colour: '', limb_temperature: '', capillary_refill: '',
  distal_pulses: '', limb_sensation: '', limb_movement: '',
  bundle_hand_hygiene_before: '', bundle_hand_hygiene_after: '',
  bundle_gloves: '', bundle_additional_ppe: '',
  bundle_antt_key_parts: '', bundle_antt_sterile: '', bundle_antt_aseptic: '',
  bundle_catheter_necessary: '',
  bundle_dressing_clean: '', bundle_dressing_dry: '', bundle_dressing_intact: '',
  bundle_dressing_transparent: '', bundle_dressing_label: '',
  bundle_dressing_date_visible: '', bundle_dressing_time_visible: '',
  bundle_dressing_edges_secure: '', bundle_dressing_no_blood: '', bundle_dressing_no_moisture: '',
  bundle_securement: '', bundle_stabilization_intact: '',
  bundle_tubing_supported: '', bundle_no_tension: '',
  bundle_site_no_redness: '', bundle_site_no_swelling: '', bundle_site_no_pain: '',
  bundle_site_no_warmth: '', bundle_site_no_discharge: '',
  bundle_vip_completed: '',
  bundle_hub_scrubbed: '', bundle_hub_antiseptic: '',
  bundle_hub_contact_time: '', bundle_hub_dried: '',
  bundle_flush_syringe: '', bundle_flush_solution: '',
  bundle_flush_before: '', bundle_flush_after: '',
  bundle_flush_push_pause: '', bundle_flush_positive_pressure: '',
  bundle_med_five_rights: '', bundle_med_compatibility: '', bundle_med_flush_between: '',
  bundle_tubing_dated: '', bundle_tubing_interval: '',
  bundle_tubing_secure: '', bundle_tubing_no_air: '', bundle_tubing_no_kinks: '',
  catheter_removed: false, removal_reason: '',
})
const pivcVipPreview = computed(() => {
  const vip = calcPivcScore(pivcForm)
  return vip != null ? vip : null
})
const pivcVipPreviewLabel = computed(() => {
  const v = pivcVipPreview.value
  const map = {0:'Healthy site',1:'Possible first signs',2:'Early phlebitis',3:'Medium phlebitis',4:'Advanced phlebitis',5:'Advanced thrombophlebitis'}
  return v != null ? (map[v] || '') : ''
})
const pivcVipPreviewColour = computed(() => {
  const v = pivcVipPreview.value
  const map = {0:'green',1:'yellow',2:'orange',3:'red',4:'dark red',5:'critical'}
  return v != null ? (map[v] || 'grey') : 'grey'
})
const pivcVipPreviewColor = computed(() => {
  const v = pivcVipPreview.value
  const map = {0:'#059669',1:'#ca8a04',2:'#d97706',3:'#dc2626',4:'#991b1b',5:'#7f1d1d'}
  return v != null ? (map[v] || '#64748b') : 'transparent'
})
const pivcVipPreviewHex = computed(() => pivcVipPreviewColor.value)
const pivcAssessmentTypeOptions = [
  {title:'Initial',value:'initial'},{title:'Routine',value:'routine'},
  {title:'PRN',value:'prn'},{title:'Post Medication',value:'post_medication'},{title:'Reassessment',value:'reassessment'},
]
const pivcPainOptions = [
  {title:'None',value:''},{title:'Pain on palpation',value:'palpation'},{title:'Pain during infusion',value:'during_infusion'},
  {title:'Constant pain',value:'constant'},{title:'Severe pain',value:'severe'},
]
const pivcErythemaOptions = [
  {title:'None',value:''},{title:'Localized (<1 cm)',value:'localized_lt_1cm'},
  {title:'Moderate (>1 cm)',value:'moderate_gt_1cm'},{title:'Along vein',value:'along_vein'},{title:'Extensive',value:'extensive'},
]
const pivcSwellingOptions = [
  {title:'None',value:''},{title:'Mild',value:'mild'},{title:'Moderate',value:'moderate'},{title:'Severe',value:'severe'},{title:'Entire limb',value:'entire_limb'},
]
const pivcWarmthOptions = [
  {title:'Normal',value:''},{title:'Slightly warm',value:'slightly_warm'},{title:'Moderately warm',value:'moderately_warm'},{title:'Very warm',value:'very_warm'},
]
const pivcIndurationOptions = [
  {title:'None',value:''},{title:'Localized',value:'localized'},{title:'Along vein',value:'along_vein'},{title:'Extensive',value:'extensive'},
]
const pivcCordOptions = [
  {title:'No',value:''},{title:'<2.5 cm',value:'lt_2.5cm'},{title:'>2.5 cm',value:'gt_2.5cm'},
]
const pivcDrainageOptions = [
  {title:'None',value:''},{title:'Serous',value:'serous'},{title:'Blood',value:'blood'},{title:'Purulent',value:'purulent'},
]
const pivcSkinIntegrityOptions = [
  {title:'Intact',value:''},{title:'Fragile',value:'fragile'},{title:'Skin Tear',value:'skin_tear'},{title:'Blister',value:'blister'},{title:'Breakdown',value:'breakdown'},
]
const pivcLeakageOptions = [
  {title:'None',value:''},{title:'Mild',value:'mild'},{title:'Moderate',value:'moderate'},{title:'Severe',value:'severe'},
]
const pivcPatencyOptions = [
  {title:'Flushes easily',value:''},{title:'Mild resistance',value:'mild_resistance'},{title:'Moderate resistance',value:'moderate_resistance'},{title:'Unable to flush',value:'unable_to_flush'},
]
const pivcBloodReturnOptions = [
  {title:'Present',value:''},{title:'Absent',value:'absent'},{title:'Not assessed',value:'not_assessed'},
]
// PIVC dropdown options for site, vein, gauge, infusion
const pivcSiteOptions = [
  'Left forearm','Right forearm','Left hand','Right hand','Left antecubital','Right antecubital',
  'Left upper arm','Right upper arm','Left wrist','Right wrist','Left foot','Right foot',
]
const pivcVeinOptions = [
  'Cephalic','Basilic','Median cubital','Metacarpal','Dorsal venous arch',
  'Accessory cephalic','Median antebrachial','Great saphenous','External jugular',
]
const pivcGaugeOptions = ['14G','16G','18G','20G','22G','24G']
const pivcInfusionOptions = [
  'Normal Saline 0.9%','Dextrose 5%','Ringer\'s Lactate','Dextrose Saline',
  'IV Antibiotics','IV Analgesics','Blood Products','Parenteral Nutrition','Medication infusion','TPN',
]
// Catheter IDs from Drain & Line Register
const pivcDeviceOptions = computed(() => {
  return (activeDevices.value || []).map(d => ({
    title: `${d.name}${d.serial_number ? ' (' + d.serial_number + ')' : ''}${d.asset_tag ? ' [#' + d.asset_tag + ']' : ''}`,
    value: d.serial_number || d.asset_tag || d.name,
    deviceId: d.id,
  }))
})
// Auto-populate previous VIP score from the latest PIVC assessment
const latestPivcAssessment = computed(() => pivcAssessments.value[0] || null)
const previousVipScoreAuto = computed(() => latestPivcAssessment.value?.vip_score ?? null)
// Client-side VIP score preview (mirrors backend calc_pivc logic)
function calcPivcScore(form) {
  const pain = form.pain_level || ''
  const erythema = form.erythema || ''
  const swelling = form.swelling || ''
  const induration = form.induration || ''
  const cord = form.palpable_cord || ''
  const drainage = form.drainage_type || ''
  const hasPain = pain && pain !== ''
  const hasExtensivePain = pain === 'constant' || pain === 'severe'
  const hasSlightPain = pain === 'palpation'
  const hasRedness = erythema && erythema !== ''
  const hasSlightRedness = erythema === 'localized_lt_1cm'
  const hasExtensiveRedness = erythema === 'along_vein' || erythema === 'extensive'
  const hasSwelling = swelling && swelling !== ''
  const hasInduration = induration && induration !== ''
  const hasCord = cord && cord !== ''
  const hasPurulent = drainage === 'purulent'
  if (!hasPain && !hasRedness && !hasSwelling) return 0
  if (hasExtensivePain && hasExtensiveRedness && hasCord && hasPurulent) return 5
  if (hasExtensivePain && hasExtensiveRedness && hasCord) return 4
  if (hasPain && hasRedness && hasInduration && !hasCord) return 3
  if (hasPain && hasRedness && hasSwelling && !hasInduration && !hasCord) return 2
  if ((hasSlightPain || hasSlightRedness) && !hasSwelling && !hasInduration) return 1
  return hasSwelling ? 2 : 1
}
const PIVC_BUNDLE_FIELDS = [
  'bundle_hand_hygiene_before','bundle_hand_hygiene_after','bundle_gloves','bundle_additional_ppe',
  'bundle_antt_key_parts','bundle_antt_sterile','bundle_antt_aseptic','bundle_catheter_necessary',
  'bundle_dressing_clean','bundle_dressing_dry','bundle_dressing_intact','bundle_dressing_transparent',
  'bundle_dressing_label','bundle_dressing_date_visible','bundle_dressing_time_visible',
  'bundle_dressing_edges_secure','bundle_dressing_no_blood','bundle_dressing_no_moisture',
  'bundle_securement','bundle_stabilization_intact','bundle_tubing_supported','bundle_no_tension',
  'bundle_site_no_redness','bundle_site_no_swelling','bundle_site_no_pain','bundle_site_no_warmth','bundle_site_no_discharge',
  'bundle_vip_completed',
  'bundle_hub_scrubbed','bundle_hub_antiseptic','bundle_hub_contact_time','bundle_hub_dried',
  'bundle_flush_syringe','bundle_flush_solution','bundle_flush_before','bundle_flush_after',
  'bundle_flush_push_pause','bundle_flush_positive_pressure',
  'bundle_med_five_rights','bundle_med_compatibility','bundle_med_flush_between',
  'bundle_tubing_dated','bundle_tubing_interval','bundle_tubing_secure','bundle_tubing_no_air','bundle_tubing_no_kinks',
]
const pivcResponseOptions = [{title:'Yes',value:'yes'},{title:'No',value:'no'},{title:'N/A',value:'na'}]
const pivcBundleCompliancePct = computed(() => {
  const answered = PIVC_BUNDLE_FIELDS.filter(k => ['yes','no','na'].includes(pivcForm[k]))
  if (!answered.length) return null
  return Math.round(answered.filter(k => pivcForm[k] === 'yes').length / answered.length * 100)
})
const pivcBundleComplianceColor = computed(() => {
  const p = pivcBundleCompliancePct.value
  return p == null ? 'transparent' : p >= 90 ? '#059669' : p >= 70 ? '#d97706' : '#b91c1c'
})
function resetPivcForm() {
  Object.assign(pivcForm, {
    assessment_type:'routine',catheter_id:'',catheter_site:'',vein:'',gauge:'',insertion_date:null,
    current_infusion:'',previous_vip_score:previousVipScoreAuto.value,
    last_flush:null,last_dressing_change:null,
    pain_level:'',pain_score_nrs:null,pain_quality:'',pain_onset:'',pain_duration:'',
    erythema:'',swelling:'',swelling_circumference_cm:null,warmth:'',induration:'',
    palpable_cord:'',drainage_type:'',drainage_quantity:'',
    skin_integrity:'',leakage:'',catheter_patency:'',blood_return:'',
    limb_colour:'',limb_temperature:'',capillary_refill:'',
    distal_pulses:'',limb_sensation:'',limb_movement:'',
    bundle_hand_hygiene_before:'',bundle_hand_hygiene_after:'',
    bundle_gloves:'',bundle_additional_ppe:'',
    bundle_antt_key_parts:'',bundle_antt_sterile:'',bundle_antt_aseptic:'',
    bundle_catheter_necessary:'',
    bundle_dressing_clean:'',bundle_dressing_dry:'',bundle_dressing_intact:'',
    bundle_dressing_transparent:'',bundle_dressing_label:'',
    bundle_dressing_date_visible:'',bundle_dressing_time_visible:'',
    bundle_dressing_edges_secure:'',bundle_dressing_no_blood:'',bundle_dressing_no_moisture:'',
    bundle_securement:'',bundle_stabilization_intact:'',
    bundle_tubing_supported:'',bundle_no_tension:'',
    bundle_site_no_redness:'',bundle_site_no_swelling:'',bundle_site_no_pain:'',
    bundle_site_no_warmth:'',bundle_site_no_discharge:'',
    bundle_vip_completed:'',
    bundle_hub_scrubbed:'',bundle_hub_antiseptic:'',
    bundle_hub_contact_time:'',bundle_hub_dried:'',
    bundle_flush_syringe:'',bundle_flush_solution:'',
    bundle_flush_before:'',bundle_flush_after:'',
    bundle_flush_push_pause:'',bundle_flush_positive_pressure:'',
    bundle_med_five_rights:'',bundle_med_compatibility:'',bundle_med_flush_between:'',
    bundle_tubing_dated:'',bundle_tubing_interval:'',
    bundle_tubing_secure:'',bundle_tubing_no_air:'',bundle_tubing_no_kinks:'',
    catheter_removed:false,removal_reason:'',
  })
}
// ── Enteral Feeding Assessment form ──
const enteralForm = reactive({
  device_type: '', tube_size: '', insertion_site: '', external_length_cm: null,
  device_removed: false, removal_reason: '',
  bundle_hand_hygiene: '', bundle_ppe: '', bundle_device_necessity: '',
  bundle_device_securement: '', bundle_tube_patency: '', bundle_water_flush_protocol: '',
  bundle_feeding_equipment_check: '', bundle_patient_positioning: '', bundle_oral_care: '',
  bundle_documentation_complete: '', bundle_position_verification: '',
  bundle_nare_care: '', bundle_skin_protection: '', bundle_nasal_pressure_prevention: '',
  bundle_stoma_care: '', bundle_external_fixation_check: '', bundle_external_length_verify: '',
  bundle_tube_rotation: '', bundle_dressing_management: '', bundle_buried_bumper: '',
  bundle_peristomal_care: '', bundle_med_safety_check: '', bundle_patient_education: '',
})
const enteralResponseOptions = [{title:'Yes',value:'yes'},{title:'No',value:'no'},{title:'N/A',value:'na'}]
const enteralNasalDevices = ['ngt','ogt','nj']
const enteralStomaDevices = ['peg','pej','gj','j_tube']
const isEnteralNasalDevice = computed(() => enteralNasalDevices.includes(enteralForm.device_type))
const isEnteralStomaDevice = computed(() => enteralStomaDevices.includes(enteralForm.device_type))
const enteralDeviceTypeOptions = [
  {title:'Nasogastric Tube (NGT)',value:'ngt'},{title:'Orogastric Tube (OGT)',value:'ogt'},
  {title:'PEG Tube',value:'peg'},{title:'PEJ Tube',value:'pej'},
  {title:'Gastrojejunostomy (GJ) Tube',value:'gj'},{title:'Jejunostomy (J-Tube)',value:'j_tube'},
  {title:'Nasojejunal (NJ) Tube',value:'nj'},{title:'Other',value:'other'},
]
// Enteral feeding combobox options (dropdown + manual entry)
const enteralTubeSizeOptions = ['Fr 6','Fr 8','Fr 10','Fr 12','Fr 14','Fr 16','Fr 18','Fr 20','Fr 22','Fr 24']
const enteralSiteOptions = [
  'Left naris','Right naris','Oral','Left upper quadrant','Right upper quadrant',
  'Midline epigastric','Left lower quadrant','Right lower quadrant','Jejunal','Gastric + Jejunal',
]
const enteralLengthOptions = ['20 cm','25 cm','30 cm','35 cm','40 cm','45 cm','50 cm','55 cm','60 cm','65 cm','70 cm','75 cm','80 cm','85 cm','90 cm','95 cm','100 cm']
const enteralCompliancePct = computed(() => {
  const keys = Object.keys(enteralForm).filter(k => k.startsWith('bundle_') && k !== 'bundle_compliance_pct')
  const answered = keys.filter(k => enteralForm[k] === 'yes' || enteralForm[k] === 'no' || enteralForm[k] === 'na')
  if (!answered.length) return null
  return Math.round((answered.filter(k => enteralForm[k] === 'yes').length / answered.length) * 100)
})
const enteralComplianceColor = computed(() => {
  const p = enteralCompliancePct.value
  return p == null ? 'transparent' : p >= 90 ? '#059669' : p >= 70 ? '#d97706' : '#b91c1c'
})
function resetEnteralForm() {
  Object.assign(enteralForm, {
    device_type:'',tube_size:'',insertion_site:'',external_length_cm:null,
    device_removed:false,removal_reason:'',
    bundle_hand_hygiene:'',bundle_ppe:'',bundle_device_necessity:'',
    bundle_device_securement:'',bundle_tube_patency:'',bundle_water_flush_protocol:'',
    bundle_feeding_equipment_check:'',bundle_patient_positioning:'',bundle_oral_care:'',
    bundle_documentation_complete:'',bundle_position_verification:'',
    bundle_nare_care:'',bundle_skin_protection:'',bundle_nasal_pressure_prevention:'',
    bundle_stoma_care:'',bundle_external_fixation_check:'',bundle_external_length_verify:'',
    bundle_tube_rotation:'',bundle_dressing_management:'',bundle_buried_bumper:'',
    bundle_peristomal_care:'',bundle_med_safety_check:'',bundle_patient_education:'',
  })
}
// ── Urinary Catheter Maintenance Bundle form ──
const ucForm = reactive({
  assessment_type: 'daily', catheter_type: 'foley', catheter_day: null,
  catheter_size_fr: null, balloon_volume_ml: null, current_indication: '',
  catheter_indicated: true,
  catheter_secure: null, correct_position: null, no_traction: null, no_leakage: null,
  no_obstruction: null, tubing_patent: null, no_dependent_loops: null,
  bag_below_bladder: null, closed_system_maintained: null,
  urine_colour: '', urine_clarity: '', urine_odour: '', urine_sediment: '', urine_blood: '', urine_output_ml: null,
  patient_fever: null, patient_chills: null, patient_dysuria: null,
  patient_abdominal_pain: null, patient_flank_pain: null, patient_confusion: null,
  patient_rigors: null, patient_malaise: null,
  bundle_necessity_reviewed: '', bundle_necessity_indicated: '',
  bundle_hand_hygiene_before: '', bundle_hand_hygiene_after: '', bundle_hand_hygiene_technique: '',
  bundle_ppe_gloves: '', bundle_ppe_additional: '',
  bundle_meatal_hygiene_done: '', bundle_meatal_cleansed: '', bundle_meatal_no_antiseptic: '',
  bundle_meatal_dried: '', bundle_meatal_skin_intact: '',
  bundle_securement_intact: '', bundle_securement_proper: '', bundle_securement_no_traction: '', bundle_securement_comfort: '',
  bundle_drain_closed: '', bundle_drain_no_disconnect: '', bundle_drain_secure: '', bundle_drain_no_leaks: '',
  bundle_bag_below_bladder: '', bundle_bag_not_floor: '', bundle_bag_tubing_unobstructed: '',
  bundle_bag_no_loops: '', bundle_bag_flow_adequate: '',
  bundle_empty_clean: '', bundle_empty_port_clean: '', bundle_empty_container: '', bundle_empty_output_doc: '',
  bundle_io_urine_recorded: '', bundle_io_intake_recorded: '', bundle_io_balance_reviewed: '',
  catheter_removed: false, removal_reason: '',
})
const ucCatheterTypeOptions = [
  {title:'Indwelling Urethral (Foley)',value:'foley'},{title:'Three-Way Irrigation',value:'three_way'},
  {title:'Suprapubic Catheter',value:'suprapubic'},{title:'Intermittent Catheter',value:'intermittent'},
  {title:'External Urinary Device',value:'external'},{title:'Other',value:'other'},
]
const ucAssessmentTypeOptions = [
  {title:'Initial',value:'initial'},{title:'Daily',value:'daily'},{title:'PRN',value:'prn'},
  {title:'Post-Insertion',value:'post_insertion'},{title:'Reassessment',value:'reassessment'},
]
const ucUrineColourOptions = ['straw','yellow','amber','pink','red','brown','green','cloudy','other']
const ucUrineClarityOptions = ['clear','slightly_cloudy','cloudy','turbid']
const ucUrineOdourOptions = ['normal','strong','foul']
const ucUrineSedimentOptions = ['none','mild','moderate','heavy']
const ucUrineBloodOptions = ['none','microscopic','visible']
// UC combobox options (dropdown + manual entry)
const ucDayOptions = ['1','2','3','4','5','7','10','14','21','30','60','90']
const ucSizeOptions = ['Fr 8','Fr 10','Fr 12','Fr 14','Fr 16','Fr 18','Fr 20','Fr 22','Fr 24','Fr 26','Fr 28','Fr 30']
const ucBalloonOptions = ['3 mL','5 mL','10 mL','15 mL','20 mL','30 mL','50 mL']
const ucCompliancePct = computed(() => {
  const keys = Object.keys(ucForm).filter(k => k.startsWith('bundle_') && k !== 'bundle_compliance_pct')
  const answered = keys.filter(k => ucForm[k] === 'yes' || ucForm[k] === 'no' || ucForm[k] === 'na')
  if (!answered.length) return null
  return Math.round((answered.filter(k => ucForm[k] === 'yes').length / answered.length) * 100)
})
const ucComplianceColor = computed(() => {
  const p = ucCompliancePct.value
  return p == null ? 'transparent' : p >= 90 ? '#059669' : p >= 70 ? '#d97706' : '#b91c1c'
})
function resetUcForm() {
  Object.assign(ucForm, {
    assessment_type:'daily',catheter_type:'foley',catheter_day:null,
    catheter_size_fr:null,balloon_volume_ml:null,current_indication:'',
    catheter_indicated:true,
    catheter_secure:null,correct_position:null,no_traction:null,no_leakage:null,
    no_obstruction:null,tubing_patent:null,no_dependent_loops:null,
    bag_below_bladder:null,closed_system_maintained:null,
    urine_colour:'',urine_clarity:'',urine_odour:'',urine_sediment:'',urine_blood:'',urine_output_ml:null,
    patient_fever:null,patient_chills:null,patient_dysuria:null,
    patient_abdominal_pain:null,patient_flank_pain:null,patient_confusion:null,
    patient_rigors:null,patient_malaise:null,
    bundle_necessity_reviewed:'',bundle_necessity_indicated:'',
    bundle_hand_hygiene_before:'',bundle_hand_hygiene_after:'',bundle_hand_hygiene_technique:'',
    bundle_ppe_gloves:'',bundle_ppe_additional:'',
    bundle_meatal_hygiene_done:'',bundle_meatal_cleansed:'',bundle_meatal_no_antiseptic:'',
    bundle_meatal_dried:'',bundle_meatal_skin_intact:'',
    bundle_securement_intact:'',bundle_securement_proper:'',bundle_securement_no_traction:'',bundle_securement_comfort:'',
    bundle_drain_closed:'',bundle_drain_no_disconnect:'',bundle_drain_secure:'',bundle_drain_no_leaks:'',
    bundle_bag_below_bladder:'',bundle_bag_not_floor:'',bundle_bag_tubing_unobstructed:'',
    bundle_bag_no_loops:'',bundle_bag_flow_adequate:'',
    bundle_empty_clean:'',bundle_empty_port_clean:'',bundle_empty_container:'',bundle_empty_output_doc:'',
    bundle_io_urine_recorded:'',bundle_io_intake_recorded:'',bundle_io_balance_reviewed:'',
    catheter_removed:false,removal_reason:'',
  })
}
const assessmentSaving = ref(false)

// ── Artificial Airway Assessment form ──
const airwayResponseOptions = [{title:'Yes',value:'yes'},{title:'No',value:'no'},{title:'N/A',value:'na'}]
const airwayDeviceOptions = [
  {title:'Tracheostomy',value:'tracheostomy'},
  {title:'Endotracheal Tube',value:'ett'},
  {title:'Laryngectomy',value:'laryngectomy'},
  {title:'None',value:'none'},
]
const airwayAssessmentTypeOptions = [
  {title:'Initial',value:'initial'},
  {title:'Routine / Shift',value:'routine'},
  {title:'PRN',value:'prn'},
  {title:'Post-Procedure',value:'post_procedure'},
  {title:'Reassessment',value:'reassessment'},
]
const airwayForm = reactive({
  assessment_type: 'routine',
  airway_device: 'tracheostomy',
  mechanically_ventilated: false,
  tube_brand: '', tube_size: '',
  is_cuffed: true, inner_cannula_present: true, subglottic_port_present: false,
  insertion_date: null, device_day: null, location: '',
  // Tracheostomy Assessment — Section 1: General Infection Prevention
  t_hand_hygiene_before: '', t_gloves_worn: '', t_ppe_used: '', t_hand_hygiene_after: '',
  // Section 2: Tube Assessment
  t_tube_position_correct: '', t_tube_patent: '', t_tube_intact: '', t_tube_unobstructed: '',
  t_tube_size_verified: '', t_tube_type_verified: '', t_tube_secured: '', t_tube_no_air_leak: '', t_tube_no_visible_damage: '',
  // Section 3: Stoma Assessment
  t_stoma_skin_clean: '', t_stoma_skin_dry: '', t_stoma_no_redness: '', t_stoma_no_swelling: '',
  t_stoma_no_bleeding: '', t_stoma_no_discharge: '', t_stoma_no_odor: '', t_stoma_no_granulation: '',
  t_stoma_no_pressure_injury: '', t_stoma_no_skin_breakdown: '', t_stoma_pain_absent: '',
  t_stoma_redness_severity: '', t_stoma_photo_url: '', t_stoma_interventions: '',
  // Section 4: Securement
  t_secure_neck_ties_intact: '', t_secure_correct_tightness: '', t_secure_holder_intact: '',
  t_secure_finger_spacing: '', t_secure_no_pressure_injury: '', t_secure_no_excessive_movement: '',
  // Section 5: Inner Cannula (conditional)
  t_inner_clean: '', t_inner_patent: '', t_inner_changed_today: '', t_inner_type: '', t_inner_replacement_required: '',
  // Section 6: Cuff Assessment (conditional)
  t_cuff_inflated: '', t_cuff_pressure_measured: '', t_cuff_pressure_value: null,
  t_cuff_pressure_in_range: '', t_cuff_air_leak_absent: '', t_cuff_pilot_balloon_intact: '',
  // Section 7: Humidification
  t_humid_prescribed: '', t_humid_functioning: '', t_humid_hme_functioning: '',
  t_humid_heated_functioning: '', t_humid_water_chamber_adequate: '', t_humid_tubing_functioning: '',
  // Section 8: Suction Equipment
  t_suction_available: '', t_suction_pressure_checked: '', t_suction_catheter_available: '',
  t_suction_correct_size: '', t_suction_equipment_functional: '',
  // Section 9: Emergency Equipment
  t_emerg_same_size_tube: '', t_emerg_smaller_tube: '', t_emerg_obturator: '',
  t_emerg_bag_valve_mask: '', t_emerg_oxygen: '', t_emerg_call_bell: '',
  // Section 10: Communication
  t_comm_method_assessed: '', t_comm_speaking_valve: '', t_comm_writing_board: '',
  t_comm_communication_chart: '', t_comm_interpreter: '', t_comm_caregiver_support: '',
  // Section 11: Documentation
  t_doc_bundle_complete: '', t_doc_education_completed: '',
  // VAP Prevention — Section 1: Head of Bed
  v_hob_30_45_maintained: '', v_hob_contraindication: '',
  // Section 2: Oral Care
  v_oral_care_completed: '', v_oral_teeth_cleaned: '', v_oral_tongue_cleaned: '',
  v_oral_mucosa_clean: '', v_oral_moisturizer_applied: '', v_oral_chlorhexidine_used: '', v_oral_secretions_removed: '',
  // Section 3: Airway Device
  v_airway_tube_secure: '', v_airway_position_correct: '', v_airway_cuff_pressure_target: '',
  v_airway_no_air_leak: '', v_airway_subglottic_functioning: '',
  // Section 4: Sedation
  v_sedation_daily_review: '', v_sedation_interruption: '', v_sedation_contraindication: '',
  // Section 5: Weaning
  v_weaning_readiness_assessed: '', v_weaning_sbt_considered: '', v_weaning_extubation_readiness: '',
  // Section 6: Suctioning
  v_suction_need_assessed: '', v_suction_secretions_removed: '', v_suction_closed_functioning: '', v_suction_catheter_changed: '',
  // Section 7: Ventilator Circuit
  v_circuit_intact: '', v_circuit_no_disconnections: '', v_circuit_condensation_managed: '', v_circuit_changed_per_policy: '',
  // Section 8: Aspiration Prevention
  v_asp_head_elevated: '', v_asp_feeding_paused: '', v_asp_tube_position_verified: '', v_asp_regurgitation_absent: '',
  // Section 9: Documentation
  v_doc_bundle_complete: '',
  // Removal
  device_removed: false, removal_reason: '',
})
const AIRWAY_TRACH_FIELDS = [
  't_hand_hygiene_before','t_gloves_worn','t_ppe_used','t_hand_hygiene_after',
  't_tube_position_correct','t_tube_patent','t_tube_intact','t_tube_unobstructed',
  't_tube_size_verified','t_tube_type_verified','t_tube_secured','t_tube_no_air_leak','t_tube_no_visible_damage',
  't_stoma_skin_clean','t_stoma_skin_dry','t_stoma_no_redness','t_stoma_no_swelling',
  't_stoma_no_bleeding','t_stoma_no_discharge','t_stoma_no_odor','t_stoma_no_granulation',
  't_stoma_no_pressure_injury','t_stoma_no_skin_breakdown','t_stoma_pain_absent',
  't_secure_neck_ties_intact','t_secure_correct_tightness','t_secure_holder_intact',
  't_secure_finger_spacing','t_secure_no_pressure_injury','t_secure_no_excessive_movement',
  't_inner_clean','t_inner_patent','t_inner_changed_today','t_inner_replacement_required',
  't_cuff_inflated','t_cuff_pressure_measured','t_cuff_pressure_in_range','t_cuff_air_leak_absent','t_cuff_pilot_balloon_intact',
  't_humid_prescribed','t_humid_functioning','t_humid_hme_functioning','t_humid_heated_functioning','t_humid_water_chamber_adequate','t_humid_tubing_functioning',
  't_suction_available','t_suction_pressure_checked','t_suction_catheter_available','t_suction_correct_size','t_suction_equipment_functional',
  't_emerg_same_size_tube','t_emerg_smaller_tube','t_emerg_obturator','t_emerg_bag_valve_mask','t_emerg_oxygen','t_emerg_call_bell',
  't_comm_method_assessed','t_comm_speaking_valve','t_comm_writing_board','t_comm_communication_chart','t_comm_interpreter','t_comm_caregiver_support',
  't_doc_bundle_complete','t_doc_education_completed',
]
const AIRWAY_VAP_FIELDS = [
  'v_hob_30_45_maintained','v_hob_contraindication',
  'v_oral_care_completed','v_oral_teeth_cleaned','v_oral_tongue_cleaned','v_oral_mucosa_clean','v_oral_moisturizer_applied','v_oral_chlorhexidine_used','v_oral_secretions_removed',
  'v_airway_tube_secure','v_airway_position_correct','v_airway_cuff_pressure_target','v_airway_no_air_leak','v_airway_subglottic_functioning',
  'v_sedation_daily_review','v_sedation_interruption','v_sedation_contraindication',
  'v_weaning_readiness_assessed','v_weaning_sbt_considered','v_weaning_extubation_readiness',
  'v_suction_need_assessed','v_suction_secretions_removed','v_suction_closed_functioning','v_suction_catheter_changed',
  'v_circuit_intact','v_circuit_no_disconnections','v_circuit_condensation_managed','v_circuit_changed_per_policy',
  'v_asp_head_elevated','v_asp_feeding_paused','v_asp_tube_position_verified','v_asp_regurgitation_absent',
  'v_doc_bundle_complete',
]
const AIRWAY_EMERGENCY_FIELDS = ['t_emerg_same_size_tube','t_emerg_smaller_tube','t_emerg_obturator','t_emerg_bag_valve_mask','t_emerg_oxygen','t_emerg_call_bell']
const isAirwayTracheostomy = computed(() => ['tracheostomy','laryngectomy'].includes(airwayForm.airway_device))
const isAirwayVAPActive = computed(() => airwayForm.mechanically_ventilated && ['tracheostomy','ett'].includes(airwayForm.airway_device))
function airwayCompliance(fields) {
  const answered = fields.filter(k => ['yes','no','na'].includes(airwayForm[k]))
  if (!answered.length) return null
  return Math.round(answered.filter(k => airwayForm[k] === 'yes').length / answered.length * 100)
}
const airwayTrachCompliancePct = computed(() => isAirwayTracheostomy.value ? airwayCompliance(AIRWAY_TRACH_FIELDS) : null)
const airwayVapCompliancePct = computed(() => isAirwayVAPActive.value ? airwayCompliance(AIRWAY_VAP_FIELDS) : null)
const airwayOverallCompliancePct = computed(() => {
  const parts = [airwayTrachCompliancePct.value, airwayVapCompliancePct.value].filter(p => p != null)
  return parts.length ? Math.round(parts.reduce((a,b) => a+b, 0) / parts.length) : null
})
const airwayOverallComplianceColor = computed(() => {
  const p = airwayOverallCompliancePct.value
  return p == null ? 'transparent' : p >= 90 ? '#059669' : p >= 70 ? '#d97706' : '#b91c1c'
})
const airwayEmergencyIncomplete = computed(() => AIRWAY_EMERGENCY_FIELDS.some(f => airwayForm[f] === 'no'))
function complianceColor(pct) {
  return pct == null ? 'transparent' : pct >= 90 ? '#059669' : pct >= 70 ? '#d97706' : '#b91c1c'
}
function resetAirwayForm() {
  Object.assign(airwayForm, {
    assessment_type:'routine', airway_device:'tracheostomy', mechanically_ventilated:false,
    tube_brand:'', tube_size:'', is_cuffed:true, inner_cannula_present:true, subglottic_port_present:false,
    insertion_date:null, device_day:null, location:'',
    t_hand_hygiene_before:'',t_gloves_worn:'',t_ppe_used:'',t_hand_hygiene_after:'',
    t_tube_position_correct:'',t_tube_patent:'',t_tube_intact:'',t_tube_unobstructed:'',
    t_tube_size_verified:'',t_tube_type_verified:'',t_tube_secured:'',t_tube_no_air_leak:'',t_tube_no_visible_damage:'',
    t_stoma_skin_clean:'',t_stoma_skin_dry:'',t_stoma_no_redness:'',t_stoma_no_swelling:'',
    t_stoma_no_bleeding:'',t_stoma_no_discharge:'',t_stoma_no_odor:'',t_stoma_no_granulation:'',
    t_stoma_no_pressure_injury:'',t_stoma_no_skin_breakdown:'',t_stoma_pain_absent:'',
    t_stoma_redness_severity:'',t_stoma_photo_url:'',t_stoma_interventions:'',
    t_secure_neck_ties_intact:'',t_secure_correct_tightness:'',t_secure_holder_intact:'',
    t_secure_finger_spacing:'',t_secure_no_pressure_injury:'',t_secure_no_excessive_movement:'',
    t_inner_clean:'',t_inner_patent:'',t_inner_changed_today:'',t_inner_type:'',t_inner_replacement_required:'',
    t_cuff_inflated:'',t_cuff_pressure_measured:'',t_cuff_pressure_value:null,
    t_cuff_pressure_in_range:'',t_cuff_air_leak_absent:'',t_cuff_pilot_balloon_intact:'',
    t_humid_prescribed:'',t_humid_functioning:'',t_humid_hme_functioning:'',
    t_humid_heated_functioning:'',t_humid_water_chamber_adequate:'',t_humid_tubing_functioning:'',
    t_suction_available:'',t_suction_pressure_checked:'',t_suction_catheter_available:'',
    t_suction_correct_size:'',t_suction_equipment_functional:'',
    t_emerg_same_size_tube:'',t_emerg_smaller_tube:'',t_emerg_obturator:'',
    t_emerg_bag_valve_mask:'',t_emerg_oxygen:'',t_emerg_call_bell:'',
    t_comm_method_assessed:'',t_comm_speaking_valve:'',t_comm_writing_board:'',
    t_comm_communication_chart:'',t_comm_interpreter:'',t_comm_caregiver_support:'',
    t_doc_bundle_complete:'',t_doc_education_completed:'',
    v_hob_30_45_maintained:'',v_hob_contraindication:'',
    v_oral_care_completed:'',v_oral_teeth_cleaned:'',v_oral_tongue_cleaned:'',
    v_oral_mucosa_clean:'',v_oral_moisturizer_applied:'',v_oral_chlorhexidine_used:'',v_oral_secretions_removed:'',
    v_airway_tube_secure:'',v_airway_position_correct:'',v_airway_cuff_pressure_target:'',
    v_airway_no_air_leak:'',v_airway_subglottic_functioning:'',
    v_sedation_daily_review:'',v_sedation_interruption:'',v_sedation_contraindication:'',
    v_weaning_readiness_assessed:'',v_weaning_sbt_considered:'',v_weaning_extubation_readiness:'',
    v_suction_need_assessed:'',v_suction_secretions_removed:'',v_suction_closed_functioning:'',v_suction_catheter_changed:'',
    v_circuit_intact:'',v_circuit_no_disconnections:'',v_circuit_condensation_managed:'',v_circuit_changed_per_policy:'',
    v_asp_head_elevated:'',v_asp_feeding_paused:'',v_asp_tube_position_verified:'',v_asp_regurgitation_absent:'',
    v_doc_bundle_complete:'',
    device_removed:false,removal_reason:'',
  })
}

const addSingleTypeDef = computed(() => ASSESSMENT_TYPES.find(t => t.key === addSingleType.value))
const assessmentHistoryTypeDef = computed(() => ASSESSMENT_TYPES.find(t => t.key === assessmentHistoryTypeKey.value) || null)

function openAddSingleCard(typeKey) {
  const def = ASSESSMENT_TYPES.find(t => t.key === typeKey)
  if (!def) return
  addSingleType.value = typeKey
  addSingleStartTime.value = new Date().toISOString().slice(0, 16)
  const exists = assessmentWorklistEntries.value.find(e => e.key === typeKey)
  addSingleFrequency.value = exists?.frequency || def.frequency
  showAddSingleDialog.value = true
}

async function confirmAddSingle() {
  const def = addSingleTypeDef.value
  if (!def) return
  const freq = addSingleCustomFreq.value || addSingleFrequency.value
  const exists = assessmentWorklistEntries.value.find(e => e.key === def.key)
  if (exists) {
    exists.frequency = freq
    exists.frequencyRaw = def.frequency
    exists.startedAt = new Date(addSingleStartTime.value).toISOString()
    exists.nextDue = exists.lastDone ? exists.nextDue : exists.startedAt
    exists.active = true
    notify(`${def.label} schedule updated`, 'success')
  } else {
    const startTs = new Date(addSingleStartTime.value).toISOString()
    // Create a draft AssessmentSession in the backend to persist the worklist entry
    let backendId = null
    try {
      const { data } = await $api.post('/homecare/assessment-sessions/', {
        patient: id, session_type: 'reassessment', status: 'draft',
        assessed_at: startTs, notes: JSON.stringify({ worklist_key: def.key, frequency: freq }),
      })
      backendId = data?.id
    } catch { /* silently fallback */ }
    assessmentWorklistEntries.value.push({
      key: def.key, label: def.label, description: def.description,
      icon: def.icon, color: def.color, bgColor: def.bgColor,
      avatarBg: def.avatarBg, avatarColor: def.avatarColor,
      frequencyRaw: def.frequency, frequency: freq,
      startedAt: startTs, lastDone: null, nextDue: startTs, active: true,
      backendId,
    })
    notify(`${def.label} added to worklist`, 'success')
  }
  persistWorklist()
  showAddSingleDialog.value = false
  addSingleCustomFreq.value = ''
}

function openRecordDialog(typeKey) {
  const def = ASSESSMENT_TYPES.find(t => t.key === typeKey)
  if (!def) return
  recordTypeKey.value = typeKey
  try {
    Object.assign(recordForm, {
      assessed_at: new Date().toISOString().slice(0, 16), notes: '',
      must_height: null, must_weight: null, must_bmi: null, must_bmi_score: null,
      must_weight_loss_pct: null, must_loss_score: null, must_acute_none: false, must_acute_score: null,
      braden_sensory: null, braden_moisture: null, braden_activity: null, braden_mobility: null,
      braden_nutrition: null, braden_friction: null,
      morse_history_falls: false, morse_secondary_dx: false, morse_ambulatory_aid: '', morse_iv_lock: false,
      morse_gait: '', morse_mental_status: '',
      caprini_points: null,
      cam_acute_onset: false, cam_inattention: false, cam_disorganized: false, cam_altered: false,
      skin_reposition: false, skin_surface: false, skin_moisture: false,
      skin_nutrition: false, skin_heels: false, skin_inspect: false,
      gcs_eyes: null, gcs_verbal: null, gcs_motor: null,
      pain_score: null,
      db_glucose: null, db_ketones: null,
      hf_weight: null, hf_fluid_balance: null, hf_spo2: null,
    })
    resetPainForm()
    resetPivcForm()
    resetEnteralForm()
    resetUcForm()
    resetAirwayForm()
  } catch (e) {
    console.error('Form reset error:', e)
  }
  showRecordDialog.value = true
}

function openAssessmentHistory(typeKey) {
  assessmentHistoryTypeKey.value = typeKey
  // Auto-expand the most recent entry
  const entries = assessmentHistoryEntries.value
  expandedHistoryIds.value = entries.length ? new Set([entries[0].id]) : new Set()
  showAssessmentHistoryDialog.value = true
}

function toggleHistoryExpand(entryId) {
  const newSet = new Set(expandedHistoryIds.value)
  if (newSet.has(entryId)) newSet.delete(entryId)
  else newSet.add(entryId)
  expandedHistoryIds.value = newSet
}

function parseAssessmentNoteMeta(value) {
  if (!value) return null
  const text = String(value).trim()
  if (!text) return null
  try {
    const parsed = JSON.parse(text)
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null
  } catch {
    return null
  }
}

function readableAssessmentNote(value) {
  if (!value) return ''
  const meta = parseAssessmentNoteMeta(value)
  if (meta) return typeof meta.note === 'string' ? meta.note.trim() : ''
  const text = String(value).trim()
  if (!text) return ''
  if ((text.startsWith('{') && text.endsWith('}')) || (text.startsWith('[') && text.endsWith(']'))) return ''
  return text
}

function buildAssessmentHistoryMetrics(item, typeKey) {
  const metrics = []
  switch (typeKey) {
    case 'braden': {
      if (item.total != null) metrics.push({ label: 'Total', value: `${item.total} / 23` })
      if (item.risk_level) metrics.push({ label: 'Risk', value: item.risk_level })
      break
    }
    case 'caprini': {
      if (item.points != null) metrics.push({ label: 'Points', value: item.points })
      if (item.risk_level) metrics.push({ label: 'Risk', value: item.risk_level })
      break
    }
    case 'morse': {
      if (item.score != null) metrics.push({ label: 'Score', value: `${item.score} / 125` })
      if (item.risk_level) metrics.push({ label: 'Fall risk', value: item.risk_level })
      break
    }
    case 'must': {
      if (item.total_score != null) metrics.push({ label: 'Score', value: `${item.total_score} / 6` })
      if (item.bmi != null) metrics.push({ label: 'BMI', value: item.bmi })
      if (item.risk_level) metrics.push({ label: 'Risk', value: item.risk_level })
      break
    }
    case 'cam': {
      metrics.push({ label: 'Result', value: item.cam_positive ? 'Positive' : 'Negative' })
      break
    }
    case 'diabetes_bundle': {
      if (item.glucose != null) metrics.push({ label: 'Glucose', value: `${item.glucose} mmol/L` })
      if (item.ketones != null) metrics.push({ label: 'Ketones', value: `${item.ketones} mmol/L` })
      break
    }
    case 'hf_bundle': {
      if (item.weight_kg != null) metrics.push({ label: 'Weight', value: `${item.weight_kg} kg` })
      if (item.fluid_balance_ml != null) metrics.push({ label: 'Fluid balance', value: `${item.fluid_balance_ml} ml` })
      if (item.spo2 != null) metrics.push({ label: 'SpO₂', value: `${item.spo2}%` })
      break
    }
    case 'pivc': {
      if (item.vip_score != null) metrics.push({ label: 'VIP Score', value: `${item.vip_score}/5` })
      if (item.vip_label) metrics.push({ label: 'Stage', value: item.vip_label })
      if (item.catheter_site) metrics.push({ label: 'Site', value: `${item.catheter_site}${item.gauge ? ' · ' + item.gauge : ''}` })
      if (item.pain_score_nrs != null) metrics.push({ label: 'Pain', value: `${item.pain_score_nrs}/10` })
      if (item.bundle_compliance_pct != null) metrics.push({ label: 'Compliance', value: `${item.bundle_compliance_pct}%` })
      if (item.catheter_removed) metrics.push({ label: 'Removed', value: item.removal_reason || 'Yes' })
      break
    }
    case 'enteral_feeding': {
      const devLabel = item.device_type_label || (item.device_type ? item.device_type.toUpperCase() : 'Device')
      if (item.device_type) metrics.push({ label: 'Device', value: devLabel })
      if (item.tube_size) metrics.push({ label: 'Size', value: item.tube_size })
      if (item.bundle_compliance_pct != null) metrics.push({ label: 'Compliance', value: `${item.bundle_compliance_pct}%` })
      if (item.device_removed) metrics.push({ label: 'Removed', value: item.removal_reason || 'Yes' })
      break
    }
    case 'skin_care': {
      const completedItems = Array.isArray(item.completed_items) ? item.completed_items : []
      metrics.push({ label: 'Completed', value: `${item.completed_count ?? completedItems.length} / ${skinCareItems.value.length}` })
      if (completedItems.length) metrics.push({ label: 'Tasks', value: completedItems.join(', ') })
      break
    }
    case 'pain_reassess': {
      // Tool & core score
      const toolLabel = item.tool_type === 'nrs' ? 'NRS' : item.tool_type === 'vas' ? 'VAS' :
        item.tool_type === 'faces' ? 'FACES' : item.tool_type === 'flacc' ? 'FLACC' : item.tool_type === 'painad' ? 'PAINAD' : 'NRS'
      if (item.score != null) metrics.push({ label: 'Score', value: `${item.score}/10 [${toolLabel}]` })
      if (item.score_category) metrics.push({ label: 'Category', value: item.score_category })
      if (item.has_pain === true) metrics.push({ label: 'Pain Present', value: 'Yes' })
      else if (item.has_pain === false) metrics.push({ label: 'Pain Present', value: 'No' })
      // NRS detail
      if (item.worst_pain_24h != null) metrics.push({ label: 'Worst (24h)', value: `${item.worst_pain_24h}/10` })
      if (item.least_pain_24h != null) metrics.push({ label: 'Least (24h)', value: `${item.least_pain_24h}/10` })
      if (item.average_pain != null) metrics.push({ label: 'Average', value: `${item.average_pain}/10` })
      if (item.acceptable_pain_goal != null) metrics.push({ label: 'Goal', value: `${item.acceptable_pain_goal}/10` })
      // VAS
      if (item.vas_mm != null) metrics.push({ label: 'VAS', value: `${item.vas_mm} mm` })
      // FACES
      if (item.faces_choice != null) metrics.push({ label: 'FACES', value: `${item.faces_choice}/10` })
      if (item.faces_description) metrics.push({ label: 'Child desc', value: item.faces_description })
      // FLACC compound
      if (item.flacc_total != null) metrics.push({ label: 'FLACC Total', value: `${item.flacc_total}/10` })
      else if (item.flacc_face != null || item.flacc_legs != null || item.flacc_activity != null || item.flacc_cry != null || item.flacc_consolability != null) {
        const ft = (item.flacc_face||0)+(item.flacc_legs||0)+(item.flacc_activity||0)+(item.flacc_cry||0)+(item.flacc_consolability||0)
        metrics.push({ label: 'FLACC Total', value: `${ft}/10` })
      }
      // PAINAD compound
      if (item.painad_total != null) metrics.push({ label: 'PAINAD Total', value: `${item.painad_total}/10` })
      else if (item.painad_breathing != null || item.painad_negative_vocal != null || item.painad_facial != null || item.painad_body_language != null || item.painad_consolability != null) {
        const pt = (item.painad_breathing||0)+(item.painad_negative_vocal||0)+(item.painad_facial||0)+(item.painad_body_language||0)+(item.painad_consolability||0)
        metrics.push({ label: 'PAINAD Total', value: `${pt}/10` })
      }
      // PQRST
      if (Array.isArray(item.provocation_factors) && item.provocation_factors.length) metrics.push({ label: 'Worse by', value: item.provocation_factors.join(', ') })
      if (Array.isArray(item.palliation_factors) && item.palliation_factors.length) metrics.push({ label: 'Relieved by', value: item.palliation_factors.join(', ') })
      if (Array.isArray(item.quality_descriptors) && item.quality_descriptors.length) metrics.push({ label: 'Quality', value: item.quality_descriptors.join(', ') })
      if (item.quality_other) metrics.push({ label: 'Other quality', value: item.quality_other })
      if (Array.isArray(item.pain_locations) && item.pain_locations.length) metrics.push({ label: 'Location', value: item.pain_locations.join(', ') })
      if (item.has_radiation === true) metrics.push({ label: 'Radiates', value: item.radiation_pathway || 'Yes' })
      if (item.onset_type) metrics.push({ label: 'Onset', value: item.onset_type })
      if (item.pain_pattern) metrics.push({ label: 'Pattern', value: item.pain_pattern })
      if (item.pain_duration) metrics.push({ label: 'Duration', value: item.pain_duration })
      if (item.pain_frequency) metrics.push({ label: 'Frequency', value: item.pain_frequency })
      // Functional impact
      if (item.impact_sleep != null) metrics.push({ label: 'Sleep impact', value: item.impact_sleep ? 'Yes' : 'No' })
      if (item.impact_adl != null) metrics.push({ label: 'ADL impact', value: item.impact_adl ? 'Yes' : 'No' })
      if (item.impact_mood != null) metrics.push({ label: 'Mood impact', value: item.impact_mood ? 'Yes' : 'No' })
      if (item.impact_appetite != null) metrics.push({ label: 'Appetite impact', value: item.impact_appetite ? 'Yes' : 'No' })
      if (item.impact_other) metrics.push({ label: 'Other impact', value: item.impact_other })
      // Treatment
      if (item.pre_treatment_score != null || item.post_treatment_score != null) {
        metrics.push({ label: 'Treatment', value: `${item.pre_treatment_score ?? '?'} → ${item.post_treatment_score ?? '?'}` })
      }
      if (item.treatment_given) metrics.push({ label: 'Intervention', value: item.treatment_given })
      break
    }
    case 'gcs': {
      if (item.total != null) metrics.push({ label: 'Total', value: `${item.total} / 15` })
      if (item.eyes != null) metrics.push({ label: 'Eye', value: item.eyes })
      if (item.verbal != null) metrics.push({ label: 'Verbal', value: item.verbal })
      if (item.motor != null) metrics.push({ label: 'Motor', value: item.motor })
      break
    }
    case 'initial': {
      metrics.push({ label: 'Session', value: 'Initial assessment' })
      break
    }
    case 'artificial_airway': {
      const devLabel = item.airway_device_label || (item.airway_device ? item.airway_device.charAt(0).toUpperCase() + item.airway_device.slice(1) : 'Airway')
      if (item.airway_device) metrics.push({ label: 'Device', value: devLabel })
      if (item.mechanically_ventilated) metrics.push({ label: 'Ventilated', value: 'Yes' })
      if (item.trach_compliance_pct != null) metrics.push({ label: 'Trach', value: `${item.trach_compliance_pct}%` })
      if (item.vap_compliance_pct != null) metrics.push({ label: 'VAP', value: `${item.vap_compliance_pct}%` })
      if (item.overall_compliance_pct != null) metrics.push({ label: 'Overall', value: `${item.overall_compliance_pct}%` })
      if (item.emergency_equipment_incomplete) metrics.push({ label: 'Alert', value: 'Emergency equipment incomplete' })
      if (item.device_removed) metrics.push({ label: 'Removed', value: item.removal_reason || 'Yes' })
      break
    }
  }
  return metrics
}

function buildAssessmentHistoryResult(item, typeKey) {
  switch (typeKey) {
    case 'braden':
      return item.total != null ? `Braden ${item.total}/23${item.risk_level ? ` · ${item.risk_level}` : ''}` : 'Braden assessment completed'
    case 'caprini':
      return item.points != null ? `Caprini ${item.points} point${item.points === 1 ? '' : 's'}` : 'Caprini assessment completed'
    case 'morse':
      return item.score != null ? `Morse ${item.score}/125` : 'Morse fall assessment completed'
    case 'must':
      return item.total_score != null ? `MUST ${item.total_score}/6${item.risk_level ? ` · ${item.risk_level} risk` : ''}` : 'MUST assessment completed'
    case 'cam':
      return item.cam_positive ? 'CAM positive' : 'CAM negative'
    case 'diabetes_bundle': return 'Diabetes bundle completed'
    case 'hf_bundle': return 'Heart failure bundle completed'
    case 'pivc':
      if (item.vip_score != null) return `PIVC VIP ${item.vip_score}/5 — ${item.vip_label || ''}`
      return 'PIVC assessment completed'
    case 'enteral_feeding':
      const devLabelEnt = item.device_type_label || (item.device_type ? item.device_type.toUpperCase() : 'Enteral')
      if (item.bundle_compliance_pct != null) return `Enteral ${devLabelEnt} — ${item.bundle_compliance_pct}% compliance`
      return `Enteral ${devLabelEnt} maintenance`
    case 'skin_care': {
      const completedCount = item.completed_count ?? (Array.isArray(item.completed_items) ? item.completed_items.length : 0)
      return `Skin care bundle ${completedCount}/${skinCareItems.value.length} tasks completed`
    }
    case 'pain_reassess':
      const toolLabelPain = (item.tool_type === 'nrs' || !item.tool_type) ? `${item.score ?? '—'}/10` :
        item.tool_type === 'vas' ? `VAS ${item.score ?? '—'}/10` :
        item.tool_type === 'faces' ? `FACES ${item.score ?? '—'}/10` :
        item.tool_type === 'flacc' ? `FLACC ${item.flacc_total ?? item.score ?? '—'}/10` :
        item.tool_type === 'painad' ? `PAINAD ${item.painad_total ?? item.score ?? '—'}/10` : `${item.score ?? '—'}/10`
      return item.score != null ? `Pain ${toolLabelPain}` : 'Pain assessment completed'
    case 'gcs':
      return item.total != null ? `GCS ${item.total}/15` : 'GCS assessment completed'
    case 'initial': return 'Initial assessment completed'
    case 'artificial_airway': {
      const devLabel = item.airway_device_label || (item.airway_device ? item.airway_device.charAt(0).toUpperCase() + item.airway_device.slice(1) : 'Airway')
      const parts = []
      if (item.trach_compliance_pct != null) parts.push(`Trach ${item.trach_compliance_pct}%`)
      if (item.vap_compliance_pct != null) parts.push(`VAP ${item.vap_compliance_pct}%`)
      return parts.length ? `${devLabel} — ${parts.join(' · ')}` : `${devLabel} assessment completed`
    }
    default: return item.session_type_label || 'Assessment completed'
  }
}

function buildHistoryForType(typeKey) {
  if (!typeKey) return []
  const source = typeKey === 'initial'
    ? assessmentData.value.filter(item => item.session_type === 'initial' && item.status === 'completed')
    : (ASSESSMENT_TYPE_REFS[typeKey]?.value || [])
  return source
    .map(item => ({
      id: item.id,
      timestamp: item.assessed_at || item.created_at,
      staff: item.assessed_by_name || item.caregiver_name || item.created_by_name || '—',
      statusLabel: item.status_label || 'Completed',
      sessionType: item.session_type_label || item.session_type || ASSESSMENT_TYPES.find(t => t.key === typeKey)?.label || 'Assessment',
      overallRisk: item.overall_risk_level_label || item.overall_risk_level || item.risk_level || '',
      resultText: buildAssessmentHistoryResult(item, typeKey),
      metrics: buildAssessmentHistoryMetrics(item, typeKey),
      notes: readableAssessmentNote(item.notes),
      braden: typeKey === 'braden' ? item : null,
      bradenTotal: typeKey === 'braden' ? (item.total ?? null) : null,
      itemScore: item.score ?? item.total ?? item.total_score ?? (item.cam_positive != null ? (item.cam_positive ? 2 : 0) : null),
    }))
    .sort((a, b) => new Date(b.timestamp || 0).getTime() - new Date(a.timestamp || 0).getTime())
}

const assessmentHistoryEntries = computed(() => buildHistoryForType(assessmentHistoryTypeKey.value))
const selectedAssessmentHistory = computed(() => buildHistoryForType(selectedAssessment.value?.key))

function buildAssessmentTypePayload(typeKey, common) {
  switch (typeKey) {
    case 'braden':
      return { ...common,
        sensory: Number(recordForm.braden_sensory) || 0,
        moisture: Number(recordForm.braden_moisture) || 0,
        activity: Number(recordForm.braden_activity) || 0,
        mobility: Number(recordForm.braden_mobility) || 0,
        nutrition: Number(recordForm.braden_nutrition) || 0,
        friction: Number(recordForm.braden_friction) || 0,
      }
    case 'caprini':
      return { ...common, points: Number(recordForm.caprini_points) || 0, factors: {} }
    case 'morse':
      return { ...common,
        history_of_falls: !!recordForm.morse_history_falls,
        secondary_dx: !!recordForm.morse_secondary_dx,
        ambulatory_aid: recordForm.morse_ambulatory_aid || 'none',
        iv_lock: !!recordForm.morse_iv_lock,
        gait: recordForm.morse_gait || 'normal',
        mental_status: recordForm.morse_mental_status || 'oriented',
      }
    case 'must':
      return { ...common,
        height_cm: Number(recordForm.must_height) || null,
        weight_kg: Number(recordForm.must_weight) || null,
        weight_loss_percent: Number(recordForm.must_weight_loss_pct) || null,
        acute_no_nutrition: !!recordForm.must_acute_none,
        loss_score: Number(recordForm.must_loss_score) || 0,
      }
    case 'cam':
      return { ...common,
        acute_onset: !!recordForm.cam_acute_onset,
        inattention: !!recordForm.cam_inattention,
        disorganized_thinking: !!recordForm.cam_disorganized,
        altered_consciousness: !!recordForm.cam_altered,
      }
    case 'pain_reassess':
      const flaccKeys = ['flacc_face','flacc_legs','flacc_activity','flacc_cry','flacc_consolability']
      const painadKeys = ['painad_breathing','painad_negative_vocal','painad_facial','painad_body_language','painad_consolability']
      return { ...common,
        tool_type: painForm.tool_type || 'nrs',
        has_pain: painForm.score != null ? true : null,
        score: Number(painForm.score) || null,
        score_category: painCategoryLabel(painForm.score),
        worst_pain_24h: Number(painForm.worst_pain_24h) || null,
        least_pain_24h: Number(painForm.least_pain_24h) || null,
        average_pain: Number(painForm.average_pain) || null,
        acceptable_pain_goal: Number(painForm.acceptable_pain_goal) || null,
        vas_mm: painForm.tool_type === 'vas' ? (Number(painForm.vas_mm) || null) : null,
        faces_choice: painForm.tool_type === 'faces' ? (Number(painForm.faces_choice) || null) : null,
        faces_description: painForm.tool_type === 'faces' ? (painForm.faces_description || '') : '',
        ...Object.fromEntries(flaccKeys.map(k => [k, painForm.tool_type==='flacc' ? (Number(painForm[k])||null) : null])),
        ...Object.fromEntries(painadKeys.map(k => [k, painForm.tool_type==='painad' ? (Number(painForm[k])||null) : null])),
        provocation_factors: Array.isArray(painForm.provocation_factors) ? painForm.provocation_factors : [],
        palliation_factors: Array.isArray(painForm.palliation_factors) ? painForm.palliation_factors : [],
        quality_descriptors: Array.isArray(painForm.quality_descriptors) ? painForm.quality_descriptors : [],
        quality_other: painForm.quality_other || '',
        pain_locations: Array.isArray(painForm.pain_locations) ? painForm.pain_locations : [],
        has_radiation: painForm.has_radiation ?? null,
        radiation_pathway: painForm.has_radiation ? (painForm.radiation_pathway || '') : '',
        onset_type: painForm.onset_type || '',
        pain_pattern: painForm.pain_pattern || '',
        pain_duration: painForm.pain_duration || '',
        pain_frequency: painForm.pain_frequency || '',
        impact_sleep: painForm.impact_sleep ?? null,
        impact_adl: painForm.impact_adl ?? null,
        impact_mood: painForm.impact_mood ?? null,
        impact_appetite: painForm.impact_appetite ?? null,
        impact_other: painForm.impact_other || '',
        pre_treatment_score: Number(painForm.pre_treatment_score) || null,
        post_treatment_score: Number(painForm.post_treatment_score) || null,
        treatment_given: painForm.treatment_given || '',
      }
    case 'diabetes_bundle':
      return { ...common,
        glucose: Number(recordForm.db_glucose) || null,
        ketones: Number(recordForm.db_ketones) || null,
      }
    case 'hf_bundle':
      return { ...common,
        weight_kg: Number(recordForm.hf_weight) || null,
        fluid_balance_ml: Number(recordForm.hf_fluid_balance) || null,
        spo2: Number(recordForm.hf_spo2) || null,
      }
    case 'pivc': {
      const pivcPayload = { ...common,
        assessment_type: pivcForm.assessment_type || 'routine',
        catheter_id: pivcForm.catheter_id || '',
        catheter_site: pivcForm.catheter_site || '',
        vein: pivcForm.vein || '', gauge: pivcForm.gauge || '',
        insertion_date: pivcForm.insertion_date || null,
        current_infusion: pivcForm.current_infusion || '',
        previous_vip_score: Number(pivcForm.previous_vip_score) || null,
        last_flush: pivcForm.last_flush || null,
        last_dressing_change: pivcForm.last_dressing_change || null,
        pain_level: pivcForm.pain_level || '', pain_score_nrs: Number(pivcForm.pain_score_nrs) || null,
        pain_quality: pivcForm.pain_quality || '', pain_onset: pivcForm.pain_onset || '', pain_duration: pivcForm.pain_duration || '',
        erythema: pivcForm.erythema || '', swelling: pivcForm.swelling || '',
        swelling_circumference_cm: Number(pivcForm.swelling_circumference_cm) || null,
        warmth: pivcForm.warmth || '', induration: pivcForm.induration || '',
        palpable_cord: pivcForm.palpable_cord || '',
        drainage_type: pivcForm.drainage_type || '', drainage_quantity: pivcForm.drainage_quantity || '',
        skin_integrity: pivcForm.skin_integrity || '',
        leakage: pivcForm.leakage || '',
        catheter_patency: pivcForm.catheter_patency || '',
        blood_return: pivcForm.blood_return || '',
        limb_colour: pivcForm.limb_colour || '',
        limb_temperature: pivcForm.limb_temperature || '',
        capillary_refill: pivcForm.capillary_refill || '',
        distal_pulses: pivcForm.distal_pulses || '',
        limb_sensation: pivcForm.limb_sensation || '',
        limb_movement: pivcForm.limb_movement || '',
        catheter_removed: !!pivcForm.catheter_removed,
        removal_reason: pivcForm.catheter_removed ? (pivcForm.removal_reason || '') : '',
      }
      PIVC_BUNDLE_FIELDS.forEach(k => { pivcPayload[k] = pivcForm[k] || '' })
      return pivcPayload
    }
    case 'skin_care':
      return { ...common,
        reposition: !!recordForm.skin_reposition,
        surface: !!recordForm.skin_surface,
        moisture: !!recordForm.skin_moisture,
        nutrition: !!recordForm.skin_nutrition,
        heels: !!recordForm.skin_heels,
        inspect: !!recordForm.skin_inspect,
      }
    case 'gcs':
      return { ...common,
        eyes: Number(recordForm.gcs_eyes) || null,
        verbal: Number(recordForm.gcs_verbal) || null,
        motor: Number(recordForm.gcs_motor) || null,
      }
    case 'enteral_feeding':
      const entKeys2 = Object.keys(enteralForm).filter(k => k.startsWith('bundle_'))
      const entPayload2 = { ...common,
        device_type: enteralForm.device_type || '',
        tube_size: enteralForm.tube_size || '', insertion_site: enteralForm.insertion_site || '',
        external_length_cm: Number(enteralForm.external_length_cm) || null,
        device_removed: !!enteralForm.device_removed,
        removal_reason: enteralForm.device_removed ? (enteralForm.removal_reason || '') : '',
      }
      entKeys2.forEach(k => { entPayload2[k] = enteralForm[k] || '' })
      return entPayload2
    case 'urinary_catheter':
      const ucKeys = Object.keys(ucForm).filter(k => k.startsWith('bundle_'))
      const ucPayload = { ...common,
        assessment_type: ucForm.assessment_type || 'daily',
        catheter_type: ucForm.catheter_type || 'foley',
        catheter_day: Number(ucForm.catheter_day) || null,
        catheter_size_fr: Number(ucForm.catheter_size_fr) || null,
        balloon_volume_ml: Number(ucForm.balloon_volume_ml) || null,
        current_indication: ucForm.current_indication || '',
        catheter_indicated: ucForm.catheter_indicated ?? true,
        catheter_secure: ucForm.catheter_secure ?? null, correct_position: ucForm.correct_position ?? null,
        no_traction: ucForm.no_traction ?? null, no_leakage: ucForm.no_leakage ?? null,
        no_obstruction: ucForm.no_obstruction ?? null, tubing_patent: ucForm.tubing_patent ?? null,
        no_dependent_loops: ucForm.no_dependent_loops ?? null, bag_below_bladder: ucForm.bag_below_bladder ?? null,
        closed_system_maintained: ucForm.closed_system_maintained ?? null,
        urine_colour: ucForm.urine_colour || '', urine_clarity: ucForm.urine_clarity || '',
        urine_odour: ucForm.urine_odour || '', urine_sediment: ucForm.urine_sediment || '',
        urine_blood: ucForm.urine_blood || '', urine_output_ml: Number(ucForm.urine_output_ml) || null,
        patient_fever: ucForm.patient_fever ?? null, patient_chills: ucForm.patient_chills ?? null,
        patient_dysuria: ucForm.patient_dysuria ?? null, patient_abdominal_pain: ucForm.patient_abdominal_pain ?? null,
        patient_flank_pain: ucForm.patient_flank_pain ?? null, patient_confusion: ucForm.patient_confusion ?? null,
        patient_rigors: ucForm.patient_rigors ?? null, patient_malaise: ucForm.patient_malaise ?? null,
        catheter_removed: !!ucForm.catheter_removed,
        removal_reason: ucForm.catheter_removed ? (ucForm.removal_reason || '') : '',
      }
      ucKeys.forEach(k => { ucPayload[k] = ucForm[k] || '' })
      return ucPayload
    case 'artificial_airway': {
      const awKeys = [...AIRWAY_TRACH_FIELDS, ...AIRWAY_VAP_FIELDS]
      const awPayload = { ...common,
        assessment_type: airwayForm.assessment_type || 'routine',
        airway_device: airwayForm.airway_device || 'tracheostomy',
        mechanically_ventilated: !!airwayForm.mechanically_ventilated,
        tube_brand: airwayForm.tube_brand || '',
        tube_size: airwayForm.tube_size || '',
        is_cuffed: !!airwayForm.is_cuffed,
        inner_cannula_present: !!airwayForm.inner_cannula_present,
        subglottic_port_present: !!airwayForm.subglottic_port_present,
        device_day: Number(airwayForm.device_day) || null,
        location: airwayForm.location || '',
        t_stoma_redness_severity: airwayForm.t_stoma_redness_severity || '',
        t_stoma_photo_url: airwayForm.t_stoma_photo_url || '',
        t_stoma_interventions: airwayForm.t_stoma_interventions || '',
        t_cuff_pressure_value: Number(airwayForm.t_cuff_pressure_value) || null,
        t_inner_type: airwayForm.t_inner_type || '',
        device_removed: !!airwayForm.device_removed,
        removal_reason: airwayForm.device_removed ? (airwayForm.removal_reason || '') : '',
      }
      awKeys.forEach(k => { awPayload[k] = airwayForm[k] || '' })
      return awPayload
    }
    default:
      return null
  }
}

async function saveAssessmentEntry() {
  const typeKey = recordTypeKey.value
  assessmentSaving.value = true
  try {
    const assessedAtIso = new Date(recordForm.assessed_at).toISOString()
    // Step 1: create the parent episode (episode-level fields only).
    const episodePayload = {
      patient: id,
      session_type: typeKey === 'initial' ? 'initial' : 'reassessment',
      status: 'completed',
      assessed_at: assessedAtIso,
      notes: JSON.stringify({ component_key: typeKey, note: recordForm.notes || '' }),
    }
    const { data: episode } = await $api.post('/homecare/assessment-sessions/', episodePayload)

    // Step 2: create the type-specific scale record against that episode
    // (skipped for 'initial', which has no dedicated scale endpoint).
    let created = null
    const endpoint = ASSESSMENT_TYPE_ENDPOINTS[typeKey]
    if (endpoint) {
      const common = { episode: episode.id, patient: id, assessed_at: assessedAtIso, notes: recordForm.notes || '' }
      const typePayload = buildAssessmentTypePayload(typeKey, common)
      const res = await $api.post(endpoint, typePayload)
      created = res.data
    }

    showRecordDialog.value = false
    const entry = assessmentWorklistEntries.value.find(e => e.key === typeKey && e.active)
    if (entry) {
      const now = new Date()
      entry.lastDone = now.toISOString()
      const freqMs = entry.frequency === 'once' ? Infinity : parseFrequencyMs(entry.frequency)
      if (freqMs !== Infinity) entry.nextDue = new Date(now.getTime() + freqMs).toISOString()
      if (typeKey === 'initial') entry.active = false
    }
    if (typeKey === 'braden' && created?.total != null && created.total <= 13) {
      ensureBradenInWorklist()
      ensureSkinCareInWorklist()
    }
    if (typeKey === 'skin_care') {
      lastSkinCareTime.value = assessedAtIso
      skinCareItems.value.forEach(item => { item.done = false; item.doneTime = '' })
    }
    notify(`${ASSESSMENT_TYPES.find(t => t.key === typeKey)?.label || 'Assessment'} saved`, 'success')
    persistWorklist()
    await loadAll()
  } catch (e) {
    notify('Save failed: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    assessmentSaving.value = false
  }
}

function ensureSkinCareInWorklist() {
  const skinEntry = assessmentWorklistEntries.value.find(e => e.key === 'skin_care' && e.active)
  if (!skinEntry) {
    const def = ASSESSMENT_TYPES.find(t => t.key === 'skin_care')
    const now = new Date()
    assessmentWorklistEntries.value.push({
      key: 'skin_care', label: def.label, description: def.description,
      icon: def.icon, color: def.color, bgColor: def.bgColor,
      avatarBg: def.avatarBg, avatarColor: def.avatarColor,
      frequencyRaw: 'Every 4 hrs', frequency: 'Every 4 hrs',
      startedAt: now.toISOString(), lastDone: null, nextDue: now.toISOString(), active: true,
    })
    persistWorklist()
    notify('Skin Care Bundle auto-activated — Braden ≤ 13', 'warning')
  }
}

function ensureBradenInWorklist() {
  const bradenEntry = assessmentWorklistEntries.value.find(e => e.key === 'braden' && e.active)
  if (!bradenEntry) {
    const def = ASSESSMENT_TYPES.find(t => t.key === 'braden')
    const now = new Date()
    assessmentWorklistEntries.value.push({
      key: 'braden', label: def.label, description: def.description,
      icon: def.icon, color: def.color, bgColor: def.bgColor,
      avatarBg: def.avatarBg, avatarColor: def.avatarColor,
      frequencyRaw: def.frequency, frequency: def.frequency,
      startedAt: now.toISOString(), lastDone: null, nextDue: now.toISOString(), active: true,
    })
    persistWorklist()
    notify('Braden Scale auto-added to worklist — score ≤ 13', 'warning')
  }
}

// --- Persistence: worklist stored in localStorage + backed by draft AssessmentSessions ---
const WORKLIST_STORAGE_KEY = computed(() => `ah_worklist_${id}`)

function persistWorklist() {
  try {
    const data = assessmentWorklistEntries.value.map(e => ({
      key: e.key, label: e.label, description: e.description,
      icon: e.icon, color: e.color, bgColor: e.bgColor,
      avatarBg: e.avatarBg, avatarColor: e.avatarColor,
      frequencyRaw: e.frequencyRaw, frequency: e.frequency,
      startedAt: e.startedAt, lastDone: e.lastDone, nextDue: e.nextDue,
      active: e.active, backendId: e.backendId,
    }))
    localStorage.setItem(WORKLIST_STORAGE_KEY.value, JSON.stringify(data))
  } catch { /* ignore */ }
}

function loadWorklistFromStorage() {
  try {
    const raw = localStorage.getItem(WORKLIST_STORAGE_KEY.value)
    if (raw) {
      assessmentWorklistEntries.value = JSON.parse(raw)
    }
  } catch {
    assessmentWorklistEntries.value = []
  }
}

async function loadWorklistFromBackend() {
  // Fetch draft sessions that represent worklist entries, then merge with localStorage
  try {
    const { data } = await $api.get('/homecare/assessment-sessions/', {
      params: { patient: id, status: 'draft', page_size: 100 }
    })
    const sessions = data?.results || (Array.isArray(data) ? data : [])
    for (const sess of sessions) {
      let meta = {}
      try { meta = JSON.parse(sess.notes || '{}') } catch { /* ignore */}
      const wkey = meta.worklist_key
      if (!wkey) continue
      const existsLocal = assessmentWorklistEntries.value.find(e => e.key === wkey)
      if (existsLocal) {
        existsLocal.backendId = sess.id
      } else {
        const def = ASSESSMENT_TYPES.find(t => t.key === wkey)
        if (def) {
          assessmentWorklistEntries.value.push({
            key: wkey, label: def.label, description: def.description,
            icon: def.icon, color: def.color, bgColor: def.bgColor,
            avatarBg: def.avatarBg, avatarColor: def.avatarColor,
            frequencyRaw: def.frequency,
            frequency: meta.frequency || def.frequency,
            startedAt: sess.assessed_at || new Date().toISOString(),
            lastDone: null, nextDue: sess.assessed_at || new Date().toISOString(),
            active: true, backendId: sess.id,
          })
        }
      }
    }
    persistWorklist()
  } catch { /* use localStorage only */ }
}

const assessmentWorklist = computed(() => {
  const now = Date.now()
  return assessmentWorklistEntries.value
    .filter(e => e.active)
    .map(e => {
      const nextDue = e.nextDue ? new Date(e.nextDue).getTime() : null
      let status = 'not-started'
      let statusLabel = 'Not started'
      let statusColor = 'grey'
      let statusIcon = 'mdi-circle-outline'
      let progressPct = null
      let progressColor = '#059669'

      if (e.lastDone) {
        const freqMs = e.frequency === 'once' ? Infinity : parseFrequencyMs(e.frequency)
        const elapsed = now - new Date(e.lastDone).getTime()
        if (freqMs === Infinity) {
          status = 'done'; statusLabel = 'Done'; statusColor = 'success'; statusIcon = 'mdi-check-circle'
        } else {
          progressPct = Math.min(Math.round((elapsed / freqMs) * 100), 100)
          if (elapsed >= freqMs) {
            status = 'overdue'; statusLabel = 'Overdue'; statusColor = 'error'; statusIcon = 'mdi-alert-circle'
          } else if (elapsed >= freqMs * 0.7) {
            status = 'due'; statusLabel = 'Due soon'; statusColor = 'warning'; statusIcon = 'mdi-clock-alert'
          } else {
            status = 'pending'; statusLabel = 'On track'; statusColor = 'teal'; statusIcon = 'mdi-timer-sand'
          }
          if (elapsed >= freqMs * 2) progressPct = 100
          progressColor = elapsed >= freqMs ? '#ef4444' : elapsed >= freqMs * 0.7 ? '#f59e0b' : '#059669'
        }
      }

      let scoreLine = null, scoreColor = '', scoreBg = ''
      if (e.key === 'braden' && latestBraden.value) {
        const t = latestBraden.value.total
        scoreLine = `${t} / 23 — ${latestBraden.value.risk_level || bradenRiskLabel(t) || ''}`.trim()
        scoreColor = t <= 9 ? '#b91c1c' : t <= 12 ? '#ef4444' : t <= 18 ? '#d97706' : '#059669'
        scoreBg = t <= 12 ? 'rgba(239,68,68,0.08)' : t <= 18 ? 'rgba(217,119,6,0.08)' : 'rgba(5,150,105,0.08)'
      } else if (e.key === 'morse' && latestMorse.value?.score != null) {
        scoreLine = `${latestMorse.value.score} / 125`
        scoreColor = latestMorse.value.score >= 45 ? '#b91c1c' : latestMorse.value.score >= 25 ? '#d97706' : '#059669'
        scoreBg = latestMorse.value.score >= 45 ? 'rgba(185,28,28,0.08)' : latestMorse.value.score >= 25 ? 'rgba(217,119,6,0.08)' : 'rgba(5,150,105,0.08)'
      }

      return { ...e, status, statusLabel, statusColor, statusIcon, progressPct, progressColor, scoreLine, scoreColor, scoreBg,
        lastDone: e.lastDone ? formatTime(e.lastDone) : null,
        nextDue: (nextDue && status !== 'done') ? formatTime(e.nextDue) : null, viewRoute: null }
    })
})

const STATUS_HEX = { success: '#059669', warning: '#f59e0b', error: '#ef4444', grey: '#94a3b8', teal: '#0d9488' }
function statusHex(color) { return STATUS_HEX[color] || '#94a3b8' }

const selectedAssessment = computed(() => {
  if (!selectedAssessmentKey.value) return assessmentWorklist.value[0] || null
  return assessmentWorklist.value.find(c => c.key === selectedAssessmentKey.value) || assessmentWorklist.value[0] || null
})

function parseFrequencyMs(freq) {
  if (!freq) return Infinity
  const m = freq.toLowerCase()
  if (m.includes('once')) return Infinity
  const num = parseInt(m) || 4
  if (m.includes('hour')) return num * 3600 * 1000
  if (m.includes('day')) return num * 86400 * 1000
  if (m.includes('week')) return num * 604800 * 1000
  return num * 12 * 3600 * 1000
}

// --- Form computed helpers for record dialog ---
const BRADEN_FIELD_DEFS = {
  sensory: { title: 'Sensory Perception', opts: [{ value: 1, title: '1 – Completely limited' }, { value: 2, title: '2 – Very limited' }, { value: 3, title: '3 – Slightly limited' }, { value: 4, title: '4 – No impairment' }] },
  moisture: { title: 'Moisture', opts: [{ value: 1, title: '1 – Constantly moist' }, { value: 2, title: '2 – Very moist' }, { value: 3, title: '3 – Occasionally moist' }, { value: 4, title: '4 – Rarely moist' }] },
  activity: { title: 'Activity', opts: [{ value: 1, title: '1 – Bedfast' }, { value: 2, title: '2 – Chairfast' }, { value: 3, title: '3 – Walks occasionally' }, { value: 4, title: '4 – Walks frequently' }] },
  mobility: { title: 'Mobility', opts: [{ value: 1, title: '1 – Completely immobile' }, { value: 2, title: '2 – Very limited' }, { value: 3, title: '3 – Slightly limited' }, { value: 4, title: '4 – No limitation' }] },
  nutrition: { title: 'Nutrition', opts: [{ value: 1, title: '1 – Very poor' }, { value: 2, title: '2 – Probably inadequate' }, { value: 3, title: '3 – Adequate' }, { value: 4, title: '4 – Excellent' }] },
  friction: { title: 'Friction & Shear', opts: [{ value: 1, title: '1 – Problem' }, { value: 2, title: '2 – Potential problem' }, { value: 3, title: '3 – No apparent problem' }] },
}
const bradenFormTotal = computed(() => {
  return (Number(recordForm.braden_sensory)||0) + (Number(recordForm.braden_moisture)||0) + (Number(recordForm.braden_activity)||0)
    + (Number(recordForm.braden_mobility)||0) + (Number(recordForm.braden_nutrition)||0) + (Number(recordForm.braden_friction)||0)
})
function bradenFieldOptions(field) { return BRADEN_FIELD_DEFS[field]?.opts || [] }

const mustFormBMI = computed(() => recordForm.must_height && recordForm.must_weight ? Number((Number(recordForm.must_weight) / ((Number(recordForm.must_height) / 100) ** 2)).toFixed(1)) : '—')
const mustFormBMIScore = computed(() => { const b = mustFormBMI.value; return b === '—' ? 0 : (b > 20 ? 0 : b > 18.5 ? 1 : 2) })
const mustLossOptions = [{ value: 0, title: '0 – <5% weight loss' }, { value: 1, title: '1 – 5–10% weight loss' }, { value: 2, title: '2 – >10% weight loss' }]
const mustFormTotal = computed(() => mustFormBMIScore.value + (Number(recordForm.must_loss_score)||0) + (recordForm.must_acute_none ? 2 : 0))

const morseAidOptions = [{ value: 'none', title: '0 – None / Bed rest / Wheelchair' }, { value: 'cane_crutch', title: '15 – Cane / Crutches / Walker' }, { value: 'furniture', title: '30 – Furniture' }]
const morseGaitOptions = [{ value: 'normal', title: '0 – Normal / Bed rest / Wheelchair' }, { value: 'weak', title: '10 – Weak' }, { value: 'impaired', title: '20 – Impaired' }]
const morseMentalOptions = [{ value: 'oriented', title: '0 – Oriented' }, { value: 'overestimates', title: '15 – Overestimates / Forgets limits' }]
const morseFormTotal = computed(() => {
  let s = 0; if (recordForm.morse_history_falls) s += 25; if (recordForm.morse_secondary_dx) s += 15
  s += { none: 0, cane_crutch: 15, furniture: 30 }[recordForm.morse_ambulatory_aid] || 0
  if (recordForm.morse_iv_lock) s += 20
  s += { normal: 0, weak: 10, impaired: 20 }[recordForm.morse_gait] || 0
  s += { oriented: 0, overestimates: 15 }[recordForm.morse_mental_status] || 0
  return s
})

const skinCareFormTotal = computed(() => skinCareItems.value.reduce((sum, item) => sum + (recordForm[`skin_${item.key}`] ? 1 : 0), 0))

const gcsEyeOptions = [{ value: 4, title: '4 – Spontaneous' }, { value: 3, title: '3 – To speech' }, { value: 2, title: '2 – To pain' }, { value: 1, title: '1 – None' }]
const gcsVerbalOptions = [{ value: 5, title: '5 – Oriented' }, { value: 4, title: '4 – Confused' }, { value: 3, title: '3 – Inappropriate' }, { value: 2, title: '2 – Incomprehensible' }, { value: 1, title: '1 – None' }]
const gcsMotorOptions = [{ value: 6, title: '6 – Obeys commands' }, { value: 5, title: '5 – Localizes pain' }, { value: 4, title: '4 – Withdraws' }, { value: 3, title: '3 – Flexion' }, { value: 2, title: '2 – Extension' }, { value: 1, title: '1 – None' }]
const gcsFormTotal = computed(() => (Number(recordForm.gcs_eyes)||0) + (Number(recordForm.gcs_verbal)||0) + (Number(recordForm.gcs_motor)||0))

// Braden watcher — auto skin care
watch(latestBraden, (b) => {
  if (b?.total != null && b.total <= 13) {
    ensureBradenInWorklist()
    ensureSkinCareInWorklist()
  }
})

// --- Drains & Lines ---
const activeDevices = ref([])
const showAddDevice = ref(false)
const showAssignEquipment = ref(false)
const assignEquipmentForm = reactive({ device_id: null, hire_period: '', hire_rate: null, deposit: null, assigned_at: new Date().toISOString().slice(0, 10), expected_return_at: '', notes: '' })
const assignEquipmentSaving = ref(false)
const availableEquipmentList = ref([])
const equipmentLoading = ref(false)

// Load drain & line registrations from the drains-lines API
async function loadDevices() {
  try {
    const { data } = await $api.get('/homecare/drains-lines/', {
      params: { patient: id, page_size: 100 }
    })
    const items = data?.results || (Array.isArray(data) ? data : [])
    activeDevices.value = items.map(e => ({
      id: e.id,
      device_id: e.id,
      type: e.line_type || 'other',
      type_label: e.line_type_label || e.name || 'Drain/Line',
      name: e.name || '',
      site: e.site || '',
      insert_date: e.insert_date || '',
      indication: e.indication || '',
      statusColor: e.is_active ? 'info' : 'grey',
      status_label: e.is_active ? 'Active' : 'Removed',
      maxDays: e.max_days || 30,
      daysInSitu: e.days_in_situ || 0,
      dressing_intact: e.dressing_intact !== false,
      site_clean: e.site_clean !== false,
      hire_period: '',
      hire_rate: null,
    }))
  } catch {
    activeDevices.value = []
  }
}

const ASSIGN_HIRE_PERIODS = [
  { label: 'Hourly', value: 'hourly' },
  { label: 'Daily', value: 'daily' },
  { label: 'Weekly', value: 'weekly' },
  { label: 'Monthly', value: 'monthly' },
  { label: 'Per Use', value: 'per_use' },
]

const assignPeriodShort = computed(() => {
  const map = { hourly: 'hr', daily: 'day', weekly: 'wk', monthly: 'mo', per_use: 'use' }
  return map[assignEquipmentForm.hire_period] || 'unit'
})
const assignUnitLabel = computed(() => {
  const map = { hourly: 'hour', daily: 'day', weekly: 'week', monthly: 'month', per_use: 'use' }
  const base = map[assignEquipmentForm.hire_period] || 'unit'
  return assignUnits.value === 1 ? base : base + 's'
})
const assignUnits = computed(() => {
  const start = assignEquipmentForm.assigned_at ? new Date(assignEquipmentForm.assigned_at) : null
  const end = assignEquipmentForm.expected_return_at ? new Date(assignEquipmentForm.expected_return_at) : null
  if (!start || !end || end <= start) return 0
  const secs = (end - start) / 1000
  const per = { daily: 86400, weekly: 604800, monthly: 2592000, per_use: 1, hourly: 3600 }[assignEquipmentForm.hire_period] || 86400
  return Math.max(Math.ceil(secs / per), 1)
})
const assignEstimatedTotal = computed(() => (Number(assignEquipmentForm.hire_rate) || 0) * assignUnits.value)
const newDevice = reactive({ type: '', name: '', site: '', insert_date: '', indication: '' })
const deviceSaving = ref(false)
const DEVICE_TYPES = [
  { value: 'catheter', label: 'Urinary Catheter', icon: 'mdi-water-pipe', maxDays: 14, statusColor: 'info' },
  { value: 'central_line', label: 'Central Line', icon: 'mdi-needle', maxDays: 7, statusColor: 'purple' },
  { value: 'ventilator', label: 'Ventilator', icon: 'mdi-ventilator', maxDays: 14, statusColor: 'error' },
  { value: 'wound_drain', label: 'Wound Drain', icon: 'mdi-bandage', maxDays: 7, statusColor: 'orange' },
  { value: 'iv_peripheral', label: 'IV Peripheral', icon: 'mdi-water', maxDays: 3, statusColor: 'blue' },
  { value: 'picc', label: 'PICC Line', icon: 'mdi-needle', maxDays: 30, statusColor: 'deep-purple' },
]
function deviceIcon(type) { return DEVICE_TYPES.find(d => d.value === type)?.icon || 'mdi-medical-bag' }
function deviceProgressPct(dev) { if (!dev.insert_date) return '100%'; const dt = DEVICE_TYPES.find(d => d.value === dev.type); const days = Math.floor((Date.now() - new Date(dev.insert_date).getTime()) / 86400000); return Math.min((days / (dt?.maxDays || 30)) * 100, 100) + '%' }
function deviceProgressColor(dev) { const pct = parseFloat(deviceProgressPct(dev)); if (pct >= 90) return '#ef4444'; if (pct >= 70) return '#f59e0b'; return '#059669' }
async function addDevice() {
  if (!newDevice.type) return notify('Select drain/line type', 'warning')
  deviceSaving.value = true
  try {
    const dt = DEVICE_TYPES.find(d => d.value === newDevice.type)
    const payload = {
      patient: id,
      line_type: newDevice.type,
      name: newDevice.name || dt?.label || 'Drain/Line',
      site: newDevice.site || '',
      insert_date: newDevice.insert_date ? new Date(newDevice.insert_date).toISOString() : new Date().toISOString(),
      indication: newDevice.indication || '',
    }
    const { data } = await $api.post('/homecare/drains-lines/', payload)
    activeDevices.value.push({
      id: data.id,
      device_id: data.id,
      type: data.line_type || newDevice.type,
      type_label: data.line_type_label || dt?.label || newDevice.type,
      name: data.name || '',
      site: data.site || '',
      insert_date: data.insert_date || new Date().toISOString(),
      indication: data.indication || '',
      statusColor: 'info',
      status_label: 'Active',
      maxDays: data.max_days || dt?.maxDays || 30,
      daysInSitu: data.days_in_situ || 0,
      dressing_intact: true,
      site_clean: true,
    })
    showAddDevice.value = false
    Object.assign(newDevice, { type: '', name: '', site: '', insert_date: '', indication: '' })
    notify('Drain/Line registered and saved', 'success')
  } catch (e) {
    notify('Failed to register drain/line: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    deviceSaving.value = false
  }
}
async function removeDevice(dev) {
  if (!dev.id) { activeDevices.value = activeDevices.value.filter(d => d !== dev); return }
  deviceSaving.value = true
  try {
    await $api.patch(`/homecare/drains-lines/${dev.id}/`, { removed_at: new Date().toISOString() })
    activeDevices.value = activeDevices.value.filter(d => d.id !== dev.id)
    notify('Drain/Line returned / removed', 'success')
  } catch (e) {
    notify('Failed: ' + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    deviceSaving.value = false
  }
}

// --- Assign equipment from inventory ---
async function openAssignEquipment() {
  assignEquipmentForm.device_id = null
  assignEquipmentForm.hire_period = ''
  assignEquipmentForm.hire_rate = null
  assignEquipmentForm.deposit = null
  assignEquipmentForm.assigned_at = new Date().toISOString().slice(0, 10)
  assignEquipmentForm.expected_return_at = ''
  assignEquipmentForm.notes = ''
  assignEquipmentForm.patient = id
  equipmentLoading.value = true
  showAssignEquipment.value = true
  try {
    const { data } = await $api.get('/homecare/devices/', { params: { status: 'available', page_size: 9999 } })
    const items = data?.results || (Array.isArray(data) ? data : [])
    availableEquipmentList.value = items.map(d => ({
      ...d,
      title: `${d.name} (${d.device_type_label || d.device_type || 'Device'}) · ${d.quantity_available ?? 0} available`,
      value: d.id,
      deviceInfo: d, // keep full device info for rate sync
    }))
  } catch {
    availableEquipmentList.value = []
    notify('Failed to load equipment inventory', 'error')
  } finally { equipmentLoading.value = false }
}
function assignSyncRate(period) {
  const selected = availableEquipmentList.value.find(d => d.value === assignEquipmentForm.device_id)
  if (selected?.deviceInfo) {
    assignEquipmentForm.hire_rate = selected.deviceInfo[`${period}_rate`] ?? assignEquipmentForm.hire_rate
  }
  assignComputeReturn()
}
function assignComputeReturn() {
  const start = assignEquipmentForm.assigned_at
  const period = assignEquipmentForm.hire_period
  if (!start || !period || period === 'hourly' || period === 'per_use') return
  const daysMap = { daily: 1, weekly: 7, monthly: 30 }
  const days = daysMap[period] || 1
  const startDate = new Date(start)
  startDate.setDate(startDate.getDate() + days)
  assignEquipmentForm.expected_return_at = startDate.toISOString().slice(0, 10)
}
async function confirmAssignEquipment() {
  if (!assignEquipmentForm.device_id) return notify('Select a device', 'warning')
  assignEquipmentSaving.value = true
  try {
    await $api.post(`/homecare/devices/${assignEquipmentForm.device_id}/assign/`, {
      hire_to_type: 'patient',
      patient: id,
      hire_period: assignEquipmentForm.hire_period || undefined,
      hire_rate: assignEquipmentForm.hire_rate,
      deposit: Number(assignEquipmentForm.deposit) || 0,
      assigned_at: new Date(assignEquipmentForm.assigned_at).toISOString(),
      expected_return_at: assignEquipmentForm.expected_return_at ? new Date(assignEquipmentForm.expected_return_at).toISOString() : undefined,
      notes: assignEquipmentForm.notes,
    })
    showAssignEquipment.value = false
    notify('Equipment assigned successfully!', 'success')
    await refreshBilling()
  } catch (e) { notify('Assignment failed: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { assignEquipmentSaving.value = false }
}

// --- Equipment view/edit ---
function viewEquipmentDetail(e) {
  equipmentViewItem.value = e
  equipmentViewDialog.value = true
}
function openEditEquipment(e) {
  Object.assign(equipmentEditForm, {
    id: e.id,
    device: e.device || '',
    hire_period: e.hire_period || '',
    hire_rate: e.hire_rate ?? null,
    deposit: e.deposit ?? null,
    assigned_at: e.assigned_at || null,
    returned_at: e.returned_at || null,
    notes: e.notes || '',
    active: e.active,
  })
  equipmentEditDialog.value = true
}
async function saveEquipmentEdit() {
  if (!equipmentEditForm.device) return notify('Device name is required', 'warning')
  equipmentEditSaving.value = true
  try {
    await $api.patch(`/homecare/device-assignments/${equipmentEditForm.id}/`, {
      device: equipmentEditForm.device,
      hire_period: equipmentEditForm.hire_period,
      hire_rate: equipmentEditForm.hire_rate,
      deposit: equipmentEditForm.deposit,
      assigned_at: equipmentEditForm.assigned_at || undefined,
      returned_at: equipmentEditForm.returned_at || undefined,
      notes: equipmentEditForm.notes,
    })
    equipmentEditDialog.value = false
    notify('Device assignment updated!', 'success')
    await refreshBilling()
  } catch (e) { notify('Update failed: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { equipmentEditSaving.value = false }
}

const supplyList = computed(() => Array.isArray(summary.value?.supplies) ? summary.value.supplies : [])
const equipmentListRaw = computed(() => Array.isArray(summary.value?.equipment) ? summary.value.equipment : [])
const equipmentListSorted = computed(() => [...equipmentListRaw.value].sort((a, b) => {
  const da = a.assigned_at ? new Date(a.assigned_at).getTime() : 0
  const db = b.assigned_at ? new Date(b.assigned_at).getTime() : 0
  return db - da // most recent first
}))
// Equipment pagination
const equipmentPage = ref(1)
const equipmentPerPage = 10
const equipmentTotalPages = computed(() => Math.max(1, Math.ceil(equipmentListSorted.value.length / equipmentPerPage)))
const equipmentList = computed(() => {
  const start = (equipmentPage.value - 1) * equipmentPerPage
  return equipmentListSorted.value.slice(start, start + equipmentPerPage)
})
// Reset page when list changes
watch(equipmentListSorted, () => { if (equipmentPage.value > equipmentTotalPages.value) equipmentPage.value = equipmentTotalPages.value })
const medicationList = computed(() => Array.isArray(summary.value?.medications) ? summary.value.medications : [])

const billableSupplyCount = computed(() => supplyList.value.filter(s => s.billable).length)
const nonBillableSupplyCount = computed(() => supplyList.value.filter(s => !s.billable).length)
const totalSupplyCost = computed(() => supplyList.value.reduce((sum, s) => sum + Number(s.total_cost || 0), 0))
const supplyAttentionItems = computed(() => supplyList.value.filter(s => ['due_soon', 'expired'].includes(s.usage_status)))

const COMMON_MEDICAL_SUPPLIES = [
  'Adult diaper (large)', 'Adult diaper (medium)', 'Adult diaper (small)',
  'Alcohol swabs', 'Antibiotic ointment', 'Aspiration catheter',
  'Bandage (elastic)', 'Bandage (triangular)',
  'Bed pan', 'Blood glucose strips', 'Blood glucose test strips',
  'BP cuff', 'Cannula (IV) size 18G', 'Cannula (IV) size 20G', 'Cannula (IV) size 22G', 'Cannula (IV) size 24G',
  'Catheter (Foley) size 14Fr', 'Catheter (Foley) size 16Fr', 'Catheter (Foley) size 18Fr',
  'Catheter fixation device', 'Colostomy bag', 'Cotton balls', 'Cotton gauze roll',
  'CPAP mask', 'CPAP nasal pillows', 'Crutches (pair)',
  'Disposable gloves (box)', 'Disposable syringe 2ml', 'Disposable syringe 5ml', 'Disposable syringe 10ml', 'Disposable syringe 20ml',
  'Dressing (adhesive)', 'Dressing (alginate)', 'Dressing (film)', 'Dressing (foam)', 'Dressing (hydrocolloid)', 'Dressing (hydrogel)',
  'Dressing pack (sterile)', 'Drainage bag', 'Enteral feeding bag', 'Enteral feeding pump set',
  'Extension tubing', 'Eye pad',
  'Feeding tube (NG) size 8Fr', 'Feeding tube (NG) size 10Fr', 'Feeding tube (NG) size 12Fr', 'Feeding tube (NG) size 14Fr',
  'Gauze pads (sterile) 10x10cm', 'Gauze pads (sterile) 5x5cm', 'Gauze swabs',
  'Gloves (nitrile) box', 'Gloves (sterile) pair', 'Glucometer',
  'Hand sanitizer (500ml)', 'Hydrogen peroxide 3%', 'Hypodermic needle 21G', 'Hypodermic needle 23G', 'Hypodermic needle 25G',
  'Insulin syringe 1ml', 'IV administration set', 'IV drip set', 'IV fluid 0.9% NaCl 500ml', 'IV fluid 5% Dextrose 500ml', 'IV fluid Ringers Lactate 500ml',
  'IV giving set (vented)', 'Lancets', 'Leukoplast tape',
  'Mask (N95)', 'Mask (surgical)', 'Measuring cup (graduated)',
  'Micropore tape', 'Nasal cannula (adult)', 'Nasal cannula (paediatric)',
  'Nasogastric tube (NG) size 8Fr', 'Nasogastric tube (NG) size 10Fr', 'Nasogastric tube (NG) size 12Fr',
  'Nebulizer kit', 'Nebulizer mask (adult)', 'Nebulizer mask (paediatric)',
  'Needle 21G', 'Needle 23G', 'Needle 25G',
  'Oxygen cannula (adult)', 'Oxygen mask (adult)', 'Oxygen mask (non-rebreather)', 'Oxygen mask (paediatric)',
  'Oxygen tubing', 'PEG tube kit',
  'Plaster (adhesive strip)', 'Plaster (hypoallergenic)',
  'Pulse oximeter', 'Safety box (sharps)', 'Saline (normal) 10ml ampoule',
  'Saline (normal) 500ml', 'Scalp vein set 21G', 'Scalp vein set 23G',
  'Sharps container (1L)', 'Spacer device (inhaler)',
  'Specimen container (sterile)', 'Sphygmomanometer (manual)',
  'SpO2 probe (adult)', 'SpO2 probe (paediatric)', 'Stethoscope',
  'Suction catheter size 10Fr', 'Suction catheter size 12Fr', 'Suction catheter size 14Fr',
  'Surgical gloves (sterile) size 7.0', 'Surgical gloves (sterile) size 7.5', 'Surgical gloves (sterile) size 8.0',
  'Suture set', 'Syringe 2ml', 'Syringe 5ml', 'Syringe 10ml', 'Syringe 20ml', 'Syringe 50ml',
  'Thermometer (digital)', 'Three-way stopcock',
  'Tracheostomy inner cannula', 'Tracheostomy tube (cuffed)', 'Tracheostomy tube (uncuffed)',
  'Transparent dressing', 'Underpad (disposable)', 'Urine bag (leg)', 'Urine bag (overnight)',
  'Urine collection bag (paediatric)', 'Urine dipstick',
  'Vaseline gauze', 'Walker', 'Water for injection 10ml',
  'Wheelchair', 'Wound care kit', 'Zinc oxide cream',
]

const knownSupplyNameOptions = computed(() => Array.from(new Set([
  ...COMMON_MEDICAL_SUPPLIES,
  ...knownSupplyNames.value,
  ...supplyList.value.map(s => s.name).filter(Boolean),
])).sort((a, b) => a.localeCompare(b)))

const activeEquipmentCount = computed(() => equipmentList.value.filter(e => e.active).length)
const returnedEquipmentCount = computed(() => equipmentList.value.filter(e => !e.active).length)
const deviceAttentionList = computed(() => activeDevices.value.filter(dev => parseFloat(deviceProgressPct(dev)) >= 80))
const deviceAttentionCount = computed(() => deviceAttentionList.value.length)

const activeMedicationCount = computed(() => medicationList.value.filter(m => m.is_active).length)
const takenMedicationCount = computed(() => medicationList.value.reduce((sum, m) => sum + Number(m.doses_taken || 0), 0))
const pendingMedicationCount = computed(() => medicationList.value.reduce((sum, m) => sum + Number(m.doses_pending || 0), 0))
const missedMedicationCount = computed(() => medicationList.value.reduce((sum, m) => sum + Number(m.doses_missed || 0), 0))
const medicationAttentionList = computed(() => medicationList.value.filter(m => Number(m.doses_missed || 0) > 0 || Number(m.doses_pending || 0) > 0))

// ── Doses tab ──
const doseItems = ref([])
const doseSearch = ref('')
const doseFilterStatus = ref(null)
const doseFilterDate = ref('today')
const doseCustomFrom = ref('')
const doseCustomTo = ref('')

const doseStatusFilterOptions = [
  { value: null, title: 'All statuses' },
  { value: 'taken', title: 'Taken' },
  { value: 'pending', title: 'Pending' },
  { value: 'missed', title: 'Missed' },
  { value: 'skipped', title: 'Skipped' },
  { value: 'not_given', title: 'Not given' },
  { value: 'overdue', title: 'Overdue' }
]

const doseDateFilterOptions = [
  { value: 'today', title: 'Today' },
  { value: 'yesterday', title: 'Yesterday' },
  { value: 'last7', title: 'Last 7 days' },
  { value: 'last30', title: 'Last 30 days' },
  { value: 'all', title: 'All' },
  { value: 'custom', title: 'Custom range…' }
]

function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
function endOfDay(d) { const x = new Date(d); x.setHours(23, 59, 59, 999); return x }

function doseDateRange() {
  const now = new Date()
  switch (doseFilterDate.value) {
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
    case 'custom': return {
      from: doseCustomFrom.value ? startOfDay(doseCustomFrom.value) : null,
      to: doseCustomTo.value ? endOfDay(doseCustomTo.value) : null
    }
    default: return { from: null, to: null }
  }
}

const dosesFilteredList = computed(() => {
  const q = doseSearch.value.trim().toLowerCase()
  const r = doseDateRange()
  return doseItems.value.filter(d => {
    if (doseFilterStatus.value && d.status !== doseFilterStatus.value) return false
    const ts = new Date(d.scheduled_at).getTime()
    if (r.from && ts < r.from.getTime()) return false
    if (r.to && ts > r.to.getTime()) return false
    if (!q) return true
    return (d.medication_name || '').toLowerCase().includes(q)
  })
})

const dosesFilteredCount = computed(() => dosesFilteredList.value.length)
const dosesFilteredTaken = computed(() => dosesFilteredList.value.filter(d => d.status === 'taken').length)
const dosesFilteredPending = computed(() => dosesFilteredList.value.filter(d => d.status === 'pending').length)
const dosesFilteredMissed = computed(() => dosesFilteredList.value.filter(d => d.status === 'missed').length)
const dosesFilteredSkipped = computed(() => dosesFilteredList.value.filter(d => d.status === 'skipped').length)

function doseColor(status) {
  return ({
    taken:     { hex: '#10b981', vuetify: 'success' },
    pending:   { hex: '#f59e0b', vuetify: 'warning' },
    missed:    { hex: '#ef4444', vuetify: 'error' },
    skipped:   { hex: '#94a3b8', vuetify: 'grey' },
    not_given: { hex: '#dc2626', vuetify: 'error' },
    overdue:   { hex: '#dc2626', vuetify: 'error' }
  })[status] || { hex: '#64748b', vuetify: 'grey' }
}
function doseIcon(status) {
  return ({ taken: 'mdi-clipboard-check', pending: 'mdi-clock', missed: 'mdi-alert',
            skipped: 'mdi-skip-next', not_given: 'mdi-cancel', overdue: 'mdi-alert' })[status] || 'mdi-circle'
}
function doseDisplay(status) {
  return ({ taken: 'Documented', pending: 'Pending', missed: 'Missed',
            skipped: 'Skipped', not_given: 'Not given', overdue: 'Overdue' })[status] || status
}

// ── Dose action dialog ──
const doseActionDialog = ref(false)
const doseActionTarget = ref(null)
const doseActionType = ref('document')
const doseActionStatus = ref('taken')
const doseActionTime = ref('')
const doseActionDose = ref('')
const doseActionReason = ref('')
const doseActionNotes = ref('')
const doseActionPin = ref('')
const doseActionBusy = ref(false)

const doseEditStatusOptions = [
  { value: 'pending',   title: 'Pending' },
  { value: 'taken',     title: 'Documented' },
  { value: 'missed',    title: 'Missed' },
  { value: 'skipped',   title: 'Skipped' },
  { value: 'not_given', title: 'Not given' }
]

const doseActionMeta = computed(() => {
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
  return map[doseActionType.value] || map.document
})

function toLocalInput(d) {
  if (!d) return ''
  const dt = new Date(d)
  return new Date(dt.getTime() - dt.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}

function openDoseAction(dose, type) {
  doseActionTarget.value = dose
  doseActionType.value = type
  doseActionStatus.value = type === 'edit'
    ? (dose.status === 'missed' ? 'taken' : dose.status)
    : 'taken'
  doseActionTime.value = toLocalInput(dose.administered_at || new Date())
  doseActionDose.value = dose.dose || ''
  doseActionReason.value = type === 'edit' ? (dose.reason || '') : ''
  doseActionNotes.value = ''
  doseActionPin.value = ''
  doseActionDialog.value = true
}

async function submitDoseAction() {
  if (!doseActionTarget.value) return
  const pin = doseActionPin.value.trim()
  if (!pin) {
    snack.text = 'Please enter your staff PIN'; snack.color = 'warning'; snack.show = true
    return
  }
  if (auth.user?.pin && pin !== auth.user.pin) {
    snack.text = 'PIN does not match the logged-in user'
    snack.color = 'error'; snack.show = true
    return
  }
  const needsReason = doseActionType.value === 'skip' || doseActionType.value === 'not_given' || doseActionType.value === 'edit'
  if (needsReason && !doseActionReason.value.trim()) {
    snack.text = 'A reason is required'; snack.color = 'warning'; snack.show = true
    return
  }
  doseActionBusy.value = true
  const payload = { pin }
  if (doseActionNotes.value) payload.notes = doseActionNotes.value
  if (doseActionReason.value) payload.reason = doseActionReason.value
  let url = ''
  if (doseActionType.value === 'document') {
    url = `/homecare/doses/${doseActionTarget.value.id}/mark_taken/`
    if (doseActionTime.value) payload.administered_at = new Date(doseActionTime.value).toISOString()
  } else if (doseActionType.value === 'skip') {
    url = `/homecare/doses/${doseActionTarget.value.id}/mark_skipped/`
  } else if (doseActionType.value === 'not_given') {
    url = `/homecare/doses/${doseActionTarget.value.id}/mark_not_given/`
  } else if (doseActionType.value === 'edit') {
    url = `/homecare/doses/${doseActionTarget.value.id}/edit_assessment/`
    payload.status = doseActionStatus.value
    if (doseActionDose.value && doseActionDose.value !== doseActionTarget.value.dose) {
      payload.dose = doseActionDose.value
    }
    if (doseActionStatus.value === 'taken' && doseActionTime.value) {
      payload.administered_at = new Date(doseActionTime.value).toISOString()
    }
  }
  try {
    const { data } = await $api.post(url, payload)
    const idx = doseItems.value.findIndex(x => x.id === data.id)
    if (idx >= 0) doseItems.value.splice(idx, 1, data)
    snack.text = `${doseActionMeta.value.title} – saved`; snack.color = 'success'; snack.show = true
    doseActionDialog.value = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Action failed'
    snack.color = 'error'; snack.show = true
  } finally {
    doseActionBusy.value = false
  }
}

function formatFullDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}

async function loadDoses() {
  try {
    const params = { patient: id, page_size: 500 }
    const { data } = await $api.get('/homecare/doses/', { params })
    doseItems.value = data?.results || (Array.isArray(data) ? data : [])
  } catch {
    doseItems.value = []
  }
}

watch(doseFilterDate, () => { if (doseFilterDate.value !== 'custom') loadDoses() })
watch([doseCustomFrom, doseCustomTo], () => { if (doseFilterDate.value === 'custom') loadDoses() })

function supplyUsageMeta(status) {
  if (status === 'expired') return { label: 'Expired', color: 'error' }
  if (status === 'due_soon') return { label: 'Due Soon', color: 'warning' }
  return { label: 'Good', color: 'success' }
}

// --- Supply CRUD helpers ---
function openAddSupply() {
  Object.assign(addSupplyForm, { name: '', category: 'feeding', billable: true, quantity: 1, unit: 'pieces', max_use_days: null, unit_price: null, supplied_at: new Date().toISOString().slice(0, 10), notes: '' })
  addSupplyDialog.value = true
}
async function saveSupply() {
  if (!addSupplyForm.name) return notify('Supply name is required', 'warning')
  supplySaving.value = true
  try {
    await $api.post('/homecare/medical-supplies/', { ...addSupplyForm, patient: id, is_active: true, currency: 'KES' })
    addSupplyDialog.value = false
    notify('Medical supply added successfully!', 'success')
    await refreshBilling()
  } catch (e) { notify('Failed to add supply: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { supplySaving.value = false }
}
function openSupplyActionDialog(mode, supply) {
  supplyActionMode.value = mode
  supplyActionItem.value = supply
  supplyActionTargetId.value = supply?.id || null
  supplyActionDays.value = mode === 'renew' ? Number(supply?.max_use_days || 7) : 7
  supplyActionDialog.value = true
}
function closeSupplyActionDialog() {
  supplyActionDialog.value = false
  supplyActionItem.value = null
  supplyActionTargetId.value = null
  supplyActionDays.value = 7
}
async function confirmSupplyAction() {
  if (!supplyActionItem.value) return
  if (!supplyActionDays.value || Number(supplyActionDays.value) <= 0) return notify('Enter valid days to add', 'warning')
  supplyActionSaving.value = true
  try {
    const supply = supplyActionItem.value
    if (supplyActionMode.value === 'renew') {
      await $api.patch(`/homecare/medical-supplies/${supply.id}/`, {
        supplied_at: new Date().toISOString().slice(0, 10),
        max_use_days: Number(supplyActionDays.value),
        is_active: true,
      })
      notify(`${supply.name} renewed!`, 'success')
    } else {
      await $api.patch(`/homecare/medical-supplies/${supply.id}/`, {
        max_use_days: Number(supply.max_use_days || 0) + Number(supplyActionDays.value),
      })
      notify(`${supply.name} extended!`, 'success')
    }
    closeSupplyActionDialog()
    await refreshBilling()
  } catch (e) {
    notify(`${supplyActionMode.value === 'renew' ? 'Renew' : 'Extend'} failed: ` + (e?.response?.data?.detail || e.message), 'error')
  } finally {
    supplyActionSaving.value = false
  }
}
function viewSupplyDetail(s) {
  supplyViewItem.value = s
  supplyViewDialog.value = true
}
function openEditSupply(s) {
  Object.assign(supplyEditForm, {
    id: s.id,
    name: s.name || '',
    category: s.category || 'feeding',
    billable: s.billable ?? true,
    quantity: s.quantity || 1,
    unit: s.unit || 'pieces',
    max_use_days: s.max_use_days ?? null,
    unit_price: s.unit_price ?? null,
    supplied_at: s.supplied_at || new Date().toISOString().slice(0, 10),
    notes: s.notes || '',
  })
  supplyEditDialog.value = true
}
async function saveSupplyEdit() {
  if (!supplyEditForm.name) return notify('Supply name is required', 'warning')
  supplyEditSaving.value = true
  try {
    await $api.patch(`/homecare/medical-supplies/${supplyEditForm.id}/`, { ...supplyEditForm })
    supplyEditDialog.value = false
    notify('Medical supply updated!', 'success')
    await refreshBilling()
  } catch (e) { notify('Update failed: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { supplyEditSaving.value = false }
}
async function loadKnownSupplyNames() {
  try {
    const { data } = await $api.get('/homecare/medical-supplies/', { params: { ordering: 'name', page_size: 9999 } })
    const items = data?.results || (Array.isArray(data) ? data : [])
    knownSupplyNames.value = Array.from(new Set(items.map(item => item?.name).filter(Boolean)))
  } catch {
    knownSupplyNames.value = []
  }
}

// --- Assessments ---
const assessmentList = computed(() => assessmentData.value.map(a => ({
  id: a.id, title: a.session_type_label || 'Assessment',
  date: formatDate(a.created_at), by: a.assessed_by_name || '',
  status: a.status === 'completed' ? 'done' : 'scheduled',
  statusColor: a.status === 'completed' ? 'teal' : 'warning',
  statusIcon: a.status === 'completed' ? 'mdi-check-circle' : 'mdi-clock-outline',
  statusLabel: a.status === 'completed' ? 'Done' : a.status_label || 'Scheduled',
  icon: 'mdi-clipboard-check',
  scores: [
    a.braden_total != null ? { label: 'Braden', value: a.braden_total, color: a.braden_total <= 12 ? 'error' : a.braden_total <= 18 ? 'warning' : 'success' } : null,
    { label: 'Morse', value: a.morse_score ?? '—', color: a.morse_score >= 45 ? 'error' : a.morse_score >= 25 ? 'warning' : 'success' },
  ].filter(s => s && s.value != null && s.value !== '—'),
})))

// --- Worklist ---
const worklistItems = computed(() => {
  const items = []
  const pendingAssess = assessmentData.value.find(a => a.status !== 'completed')
  if (pendingAssess) items.push({ id: 'assess', icon: 'mdi-clipboard-alert', title: 'Assessment pending', detail: `${pendingAssess.session_type_label || 'Assessment'} not completed`, color: '#f59e0b', statusColor: 'warning', statusLabel: 'Pending', action: () => navigateTo(`/homecare/assessments/${pendingAssess.id}`), actionLabel: 'Complete' })
  const vp = parseFloat(vitalsProgressPct.value)
  if (vp >= 90) items.push({ id: 'vitals', icon: 'mdi-heart-pulse', title: 'Vitals due', detail: `Next vitals ${vp >= 100 ? 'OVERDUE' : 'due now'}`, color: '#ef4444', statusColor: 'error', statusLabel: 'Urgent', action: openQuickVitals, actionLabel: 'Record' })
  if (bradenLowAlert.value) {
    const bp = parseFloat(bradenProgressPct.value)
    if (bp >= 70) items.push({ id: 'braden', icon: 'mdi-human', title: 'Braden reassessment due', detail: `Braden ${latestBraden.value?.total} — ${bp >= 90 ? 'due now' : 'due soon'}`, color: '#d97706', statusColor: 'warning', statusLabel: 'Due', action: () => tab.value = 'braden', actionLabel: 'View' })
    const sp = parseFloat(skinCareProgressPct.value)
    if (sp >= 90) items.push({ id: 'skincare', icon: 'mdi-bandage', title: 'Skin care bundle due', detail: `q4h bundle — ${sp >= 100 ? 'OVERDUE' : 'due now'}`, color: '#ec4899', statusColor: 'error', statusLabel: 'Urgent', action: () => tab.value = 'braden', actionLabel: 'Do now' })
  }
  activeDevices.value.forEach(d => { const dp = parseFloat(deviceProgressPct(d)); if (dp >= 80) items.push({ id: `dev-${d.id}`, icon: 'mdi-medical-bag', title: `${d.type_label} review due`, detail: `${d.daysInSitu}d in situ — ${dp >= 100 ? 'OVERDUE' : 'due soon'}`, color: '#4f46e5', statusColor: 'warning', statusLabel: 'Review', action: () => tab.value = 'equipment', actionLabel: 'View' }) })
  return items
})

const activeAlerts = computed(() => {
  const alerts = []
  const n = latestNews2.value
  if (n != null && n >= 7) alerts.push({ type: 'error', icon: 'mdi-alert-octagon', title: `NEWS2 = ${n} — Emergency`, detail: 'Emergency assessment · notify medical team · consider ICU transfer' })
  else if (n != null && n >= 5) alerts.push({ type: 'warning', icon: 'mdi-alert', title: `NEWS2 = ${n} — Urgent review`, detail: 'Urgent RN review · hourly monitoring · inform medical team' })
  if (bradenLowAlert.value) alerts.push({ type: 'error', icon: 'mdi-human', title: `Braden ${latestBraden.value?.total} — Severe Risk`, detail: 'Reposition q2h · specialty support surface · nutritional consult · moisture management' })
  const bp = parseFloat(bradenProgressPct.value)
  if (bp >= 100) alerts.push({ type: 'warning', icon: 'mdi-clock-alert', title: 'Braden reassessment overdue', detail: 'Braden should be done every 12 hours.' })
  return alerts
})
const alertsPanelColor = computed(() => activeAlerts.value.some(a => a.type === 'error') ? 'error' : activeAlerts.value.some(a => a.type === 'warning') ? 'warning' : 'info')

const latestVitalsGrid = computed(() => {
  const v = latestVitals.value; if (!v) return []
  return [
    { label: 'NEWS2', value: v.news2 ?? '—', color: riskHex.value, bg: `${riskHex.value}15` },
    { label: 'BP', value: `${v.systolic||'—'}/${v.diastolic||'—'}`, color: '#64748b', bg: 'rgba(100,116,139,0.08)' },
    { label: 'RR', value: `${v.rr||'—'} /min`, color: '#0d9488', bg: 'rgba(13,148,136,0.08)' },
    { label: 'Pulse', value: `${v.pulse||'—'} bpm`, color: '#0ea5e9', bg: 'rgba(14,165,233,0.08)' },
    { label: 'Temp', value: `${v.temperature||'—'}°C`, color: '#f59e0b', bg: 'rgba(245,158,11,0.08)' },
    { label: 'SpO₂', value: `${v.spo2||'—'}%`, color: '#059669', bg: 'rgba(5,150,105,0.08)' },
  ]
})

const quickScores = computed(() => [
  { label: 'NEWS2', value: latestNews2.value ?? '—', unit: '/20', color: riskColor.value, bg: `${riskHex.value}12` },
  { label: 'Braden', value: latestBraden.value?.total ?? '—', unit: '/23', color: bradenColor.value, bg: 'rgba(217,119,6,0.08)' },
  { label: 'Morse', value: latestMorse.value?.score ?? '—', unit: '/125', color: (latestMorse.value?.score||0) >= 45 ? 'error' : (latestMorse.value?.score||0) >= 25 ? 'warning' : 'success', bg: 'rgba(245,158,11,0.08)' },
])

// --- Quick vitals dialog ---
const quickVitalsDialog = ref(false)
const quickVitalsForm = reactive({ rr: null, spo2: null, scale2: false, oxygen: 'Room air', oxygen_delivery: null, consciousness: 'A', systolic: null, diastolic: null, pulse: null, temperature: null, glucose: null, weight: null })
const quickNews2Scores = computed(() => ({ rr: scoreRR(quickVitalsForm.rr), spo2: quickVitalsForm.scale2 ? scoreSpO2Scale2(quickVitalsForm.spo2, quickVitalsForm.oxygen==='Supplemental O₂') : scoreSpO2Scale1(quickVitalsForm.spo2), oxygen: scoreOxygen(quickVitalsForm.oxygen), sbp: scoreSBP(quickVitalsForm.systolic), hr: scoreHR(quickVitalsForm.pulse), temp: scoreTemp(quickVitalsForm.temperature), consciousness: scoreConsciousness(quickVitalsForm.consciousness) }))
const quickNews2Total = computed(() => Object.values(quickNews2Scores.value).reduce((a,b)=>a+b,0))
const quickNews2HasRed = computed(() => Object.values(quickNews2Scores.value).some(s=>s>=3))
const quickNews2Risk = computed(() => { const t=quickNews2Total.value; if(t===0) return {label:'Low',color:'success',hex:'#059669'}; if(t<=4&&!quickNews2HasRed.value) return {label:'Low – Medium',color:'info',hex:'#0284c7'}; if(t<=6||quickNews2HasRed.value) return {label:'Medium',color:'warning',hex:'#d97706'}; return {label:'High',color:'error',hex:'#b91c1c'} })
const quickNews2Breakdown = computed(() => [
  {key:'rr',icon:'mdi-lungs',label:'Respiratory rate',value:quickVitalsForm.rr!=null?`${quickVitalsForm.rr}/min`:'—',score:quickNews2Scores.value.rr},
  {key:'spo2',icon:'mdi-water-percent',label:`SpO₂ (Scale ${quickVitalsForm.scale2?2:1})`,value:quickVitalsForm.spo2!=null?`${quickVitalsForm.spo2}%`:'—',score:quickNews2Scores.value.spo2},
  {key:'oxygen',icon:'mdi-gas-cylinder',label:'Supplemental O₂',value:quickVitalsForm.oxygen,score:quickNews2Scores.value.oxygen},
  {key:'sbp',icon:'mdi-heart-pulse',label:'Systolic BP',value:quickVitalsForm.systolic!=null?`${quickVitalsForm.systolic}mmHg`:'—',score:quickNews2Scores.value.sbp},
  {key:'hr',icon:'mdi-heart',label:'Heart rate',value:quickVitalsForm.pulse!=null?`${quickVitalsForm.pulse}bpm`:'—',score:quickNews2Scores.value.hr},
  {key:'temp',icon:'mdi-thermometer',label:'Temperature',value:quickVitalsForm.temperature!=null?`${quickVitalsForm.temperature}°C`:'—',score:quickNews2Scores.value.temp},
  {key:'consciousness',icon:'mdi-brain',label:'Consciousness',value:quickVitalsForm.consciousness,score:quickNews2Scores.value.consciousness}
])
function openQuickVitals() { quickVitalsDialog.value = true }
async function saveQuickVitals() {
  savingVitals.value = true
  try {
    await $api.post('/homecare/vitals/', { ...quickVitalsForm, patient: id, news2: quickNews2Total.value, recorded_at: new Date().toISOString() })
    quickVitalsDialog.value = false; notify(`Vitals saved. NEWS2 ${quickNews2Total.value} (${quickNews2Risk.value.label})`, 'success')
    await loadVitals()
  } catch(e) { notify('Failed to save vitals: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { savingVitals.value = false }
}

// --- Billing ---
const billingPlanLabel = computed(() => { const cp = summary.value?.care_plan; return cp ? cp.plan_type_label || 'Active' : 'No plan' })
const carePlanData = computed(() => summary.value?.care_plan || null)

function billingPct(part, total) {
  const p = Number(part || 0); const t = Number(total || 1); if (t === 0) return 0
  return Math.round((p / t) * 100)
}

// Billing state
const billingSaving = ref(false)
const billingRefreshing = ref(false)
const billGenDialog = ref(false)
const paymentDialog = ref(false)
const planDialog = ref(false)
const billDetailDialog = ref(false)
const billDetailItem = ref(null)
const expandedBillId = ref(null)
const addSupplyDialog = ref(false)
const supplySaving = ref(false)
const knownSupplyNames = ref([])
const supplyActionDialog = ref(false)
const supplyActionMode = ref('renew')
const supplyActionItem = ref(null)
const supplyActionDays = ref(7)
const supplyActionSaving = ref(false)
const supplyActionTargetId = ref(null)
const supplyEditDialog = ref(false)
const supplyEditSaving = ref(false)
const supplyEditForm = reactive({ id: null, name: '', category: 'feeding', billable: true, quantity: 1, unit: 'pieces', max_use_days: null, unit_price: null, supplied_at: '', notes: '' })
const supplyViewDialog = ref(false)
const supplyViewItem = ref(null)
const equipmentViewDialog = ref(false)
const equipmentViewItem = ref(null)
const equipmentEditDialog = ref(false)
const equipmentEditSaving = ref(false)
const equipmentEditForm = reactive({ id: null, device: '', hire_period: '', hire_rate: null, deposit: null, assigned_at: '', returned_at: '', notes: '' })
const addSupplyForm = reactive({ name: '', category: 'feeding', billable: true, quantity: 1, unit: 'pieces', max_use_days: null, unit_price: null, supplied_at: new Date().toISOString().slice(0, 10), notes: '' })
const billGenForm = reactive({ discount: 0, tax: 0, notes: '' })
const paymentForm = reactive({ amount: null, method: 'cash', reference: '', paid_at: '', notes: '', bill_id: null })
const planForm = reactive({ plan_type: 'daily', rate: null, currency: 'KES', start_date: '', end_date: '', notes: '', auto_bill: true })
// Date filters
const billDateFilter = ref('all')
const billDateFrom = ref('')
const billDateTo = ref('')
// Print
const printArea = ref(null)
const printContent = ref(null)

const PLAN_TYPES = [
  { value: 'hourly', title: 'Hourly' }, { value: 'daily', title: 'Daily' }, { value: 'weekly', title: 'Weekly' },
  { value: 'monthly', title: 'Monthly' }, { value: 'per_visit', title: 'Per Visit' },
  { value: 'day_time', title: 'Day Shift' }, { value: 'night_time', title: 'Night Shift' },
]
const PAYMENT_METHODS = [
  { value: 'cash', label: 'Cash' }, { value: 'mpesa', label: 'M-Pesa' }, { value: 'card', label: 'Card' },
  { value: 'bank', label: 'Bank Transfer' }, { value: 'insurance', label: 'Insurance' }, { value: 'other', label: 'Other' },
]
const SUPPLY_CATEGORIES = [
  { title: 'Feeding / Nutrition', value: 'feeding' },
  { title: 'Catheter / Urinary', value: 'catheter' },
  { title: 'Wound Care / Dressing', value: 'wound' },
  { title: 'IV / Infusion', value: 'iv' },
  { title: 'Respiratory', value: 'respiratory' },
  { title: 'Incontinence', value: 'incontinence' },
  { title: 'Diabetic', value: 'diabetic' },
  { title: 'PPE / Hygiene', value: 'hygiene' },
  { title: 'Other', value: 'other' },
]

const billGenTotal = computed(() => Math.max(Number(summary.value.subtotal || 0) - Number(billGenForm.discount || 0) + Number(billGenForm.tax || 0), 0))

const billSelectOptions = computed(() => {
  const bills = summary.value.bills || []
  return bills.filter(b => b.status !== 'void' && b.status !== 'paid').map(b => ({
    value: b.id, title: `${b.bill_number} · ${money(b.total)} (bal ${money(b.balance)})`,
  }))
})

// Date-filtered bills
const filteredBills = computed(() => {
  const bills = summary.value.bills || []
  const filter = billDateFilter.value
  if (filter === 'all') return bills
  const now = new Date(); now.setHours(23, 59, 59, 999)
  const todayStart = new Date(now); todayStart.setHours(0, 0, 0, 0)
  const yesterdayStart = new Date(todayStart); yesterdayStart.setDate(yesterdayStart.getDate() - 1)
  let from = null
  if (filter === 'today') from = todayStart
  else if (filter === 'yesterday') { from = yesterdayStart; now.setDate(now.getDate() - 1); now.setHours(23, 59, 59, 999) }
  else if (filter === '7d') from = new Date(todayStart.getTime() - 7 * 86400000)
  else if (filter === '30d') from = new Date(todayStart.getTime() - 30 * 86400000)
  else if (filter === 'custom') {
    if (billDateFrom.value) from = new Date(billDateFrom.value)
    if (billDateTo.value) { const to = new Date(billDateTo.value); to.setHours(23, 59, 59, 999); return bills.filter(b => filterBillByDate(b, from, to)) }
  }
  if (from) return bills.filter(b => filterBillByDate(b, from, now))
  return bills
})
function filterBillByDate(b, from, to) {
  if (!b.as_of) return false
  const d = new Date(b.as_of)
  if (from && d < from) return false
  if (to && d > to) return false
  return true
}
function applyCustomDateFilter() { /* reactive already updates */ }

function toggleBillExpand(id) { expandedBillId.value = expandedBillId.value === id ? null : id }
function viewBillDetail(b) { billDetailItem.value = b; billDetailDialog.value = true }

// --- Print helpers ---
function absoluteAssetUrl(url) {
  if (!url) return ''
  if (/^(https?:|data:|blob:)/i.test(url)) return url
  if (typeof window !== 'undefined') return new URL(url, window.location.origin).toString()
  return url
}

const facilityLogoUrl = computed(() => absoluteAssetUrl(companyProfile.value?.logo || defaultLogoUrl))
const facilityName = computed(() => auth.tenantName || companyProfile.value?.legal_name || 'AdhereMed Homecare')
const facilityEmail = computed(() => companyProfile.value?.contact_email || auth.user?.email || '')
const facilityPhone = computed(() => companyProfile.value?.contact_phone || '')
const facilityAddress = computed(() => companyProfile.value?.address || '')
const facilityLocation = computed(() => [companyProfile.value?.city, companyProfile.value?.country].filter(Boolean).join(', '))
const platformLogoUrl = computed(() => absoluteAssetUrl(adhereMedLogoUrl))

function buildPrintBase(title, dateLabel, extra) {
  return {
    providerLogo: facilityLogoUrl.value,
    providerName: facilityName.value,
    providerEmail: facilityEmail.value,
    providerPhone: facilityPhone.value,
    providerAddress: facilityAddress.value,
    providerLocation: facilityLocation.value,
    platformLogo: platformLogoUrl.value,
    platformName: 'AdhereMed',
    platformEmail: 'info@adheremed.co',
    title,
    dateLabel,
    ...extra,
  }
}

// Print functions
function printBill(b) {
  const items = (b.line_items || summary.value.line_items || []).map(li => ({
    label: li.label, qty: li.qty, unit: li.unit || '', rate: li.rate ? money(li.rate) : '—', amount: money(li.amount)
  }))
  printContent.value = buildPrintBase(`Bill ${b.bill_number || ''}`, formatDate(b.as_of), {
    billNumber: b.bill_number,
    status: b.status_label || b.status,
    statusColor: b.status === 'paid' ? '#16a34a' : b.status === 'void' ? '#94a3b8' : '#d97706',
    summary: [
      ...(Number(b.subtotal) > 0 ? [{ label: 'Subtotal', value: money(b.subtotal) }] : []),
      ...(Number(b.discount) > 0 ? [{ label: 'Discount', value: '-' + money(b.discount), color: '#ef4444' }] : []),
      ...(Number(b.tax) > 0 ? [{ label: 'Tax', value: money(b.tax) }] : []),
      { label: 'Total', value: money(b.total), bold: true },
      { label: 'Paid', value: money(b.amount_paid), color: '#16a34a' },
      { label: 'Balance', value: money(b.balance), bold: true, color: Number(b.balance) > 0 ? '#ef4444' : '#16a34a' },
    ],
    lineItems: items,
    notes: b.notes || 'Please review the billed services and contact the homecare team for any clarification on charges.',
    generatedBy: b.generated_by_name || '',
    footer: `Generated ${new Date().toLocaleString()} · ${facilityName.value}`,
  })
  nextTick(() => doPrint())
}
function printCostBreakdown() {
  printContent.value = buildPrintBase('Cost Breakdown Summary', formatDate(new Date().toISOString()), {
    summary: [
      { label: 'Care Plan', value: money(summary.value.care_total) },
      ...(Number(summary.value.equipment_total) > 0 ? [{ label: 'Equipment', value: money(summary.value.equipment_total) }] : []),
      ...(Number(summary.value.supplies_total) > 0 ? [{ label: 'Supplies', value: money(summary.value.supplies_total) }] : []),
      ...(Number(summary.value.medication_total) > 0 ? [{ label: 'Medications', value: money(summary.value.medication_total) }] : []),
      { label: 'Subtotal', value: money(summary.value.subtotal), bold: true },
      { label: 'Paid', value: money(summary.value.total_paid), color: '#16a34a' },
      { label: 'Balance', value: money(summary.value.balance), bold: true, color: Number(summary.value.balance) > 0 ? '#ef4444' : '#16a34a' },
    ],
    notes: 'This summary consolidates current care, equipment, supplies, and medication charges for the patient.',
    footer: `Generated ${new Date().toLocaleString()} · ${facilityName.value}`,
  })
  nextTick(() => doPrint())
}
function printLineItems() {
  const items = (summary.value.line_items || []).map(li => ({
    label: li.label, qty: li.qty, unit: li.unit || '', rate: li.rate ? money(li.rate) : '—', amount: money(li.amount)
  }))
  printContent.value = buildPrintBase('Line Items with Summary', formatDate(new Date().toISOString()), {
    summary: [
      { label: 'Subtotal', value: money(summary.value.subtotal), bold: true },
      { label: 'Paid', value: money(summary.value.total_paid), color: '#16a34a' },
      { label: 'Balance', value: money(summary.value.balance), bold: true, color: Number(summary.value.balance) > 0 ? '#ef4444' : '#16a34a' },
    ],
    lineItems: items,
    notes: 'Detailed line items are shown above, with the overall patient billing position summarized at the bottom.',
    footer: `Generated ${new Date().toLocaleString()} · ${facilityName.value}`,
  })
  nextTick(() => doPrint())
}
async function doPrint() {
  if (!printArea.value || !printContent.value) return
  const styleText = `
    * { box-sizing: border-box; margin: 0; padding: 0; }
    @page { size: A4; margin: 14mm; }
    body { font-family: 'Segoe UI', Arial, sans-serif; color: #1e293b; background: #e2e8f0; padding: 24px; }
    .print-document { max-width: 860px; margin: 0 auto; padding: 32px 36px 28px; background: #ffffff; border-radius: 24px; box-shadow: 0 28px 80px -36px rgba(15, 23, 42, 0.4); }
    .print-top-accent { height: 10px; border-radius: 999px; background: linear-gradient(90deg, #0f766e 0%, #14b8a6 45%, #0ea5e9 100%); margin-bottom: 24px; }
    .print-header { display: flex; justify-content: space-between; align-items: stretch; gap: 18px; margin-bottom: 20px; }
    .print-provider-card, .print-platform-card, .print-meta-card, .print-note-card, .print-summary-card { background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%); border: 1px solid #e2e8f0; border-radius: 20px; }
    .print-provider-card { flex: 1.3; padding: 20px; }
    .print-provider-brand { display: flex; align-items: center; gap: 14px; margin-bottom: 14px; }
    .print-provider-logo { width: 68px; height: 68px; border-radius: 18px; object-fit: cover; border: 1px solid #dbeafe; background: #ffffff; }
    .print-eyebrow { font-size: 10px; letter-spacing: 1.6px; text-transform: uppercase; color: #0f766e; font-weight: 700; margin-bottom: 4px; }
    .print-provider-name { font-size: 24px; font-weight: 800; color: #0f172a; line-height: 1.15; }
    .print-provider-sub { font-size: 12px; color: #64748b; margin-top: 4px; }
    .print-provider-details { display: grid; gap: 6px; font-size: 12px; color: #334155; }
    .print-platform-card { width: 250px; padding: 20px; display: flex; flex-direction: column; justify-content: space-between; align-items: flex-end; text-align: right; background: linear-gradient(180deg, #f8fffe 0%, #effcfb 100%); }
    .print-platform-row { display: flex; align-items: center; gap: 12px; }
    .print-platform-logo { width: 54px; height: 54px; object-fit: contain; }
    .print-platform-copy { text-align: right; }
    .print-platform-name { font-size: 22px; font-weight: 800; color: #0f766e; line-height: 1.1; }
    .print-platform-email { font-size: 12px; color: #475569; margin-top: 4px; }
    .print-doc-chip { margin-top: 18px; padding: 10px 14px; border-radius: 999px; background: #0f172a; color: #ffffff; font-size: 11px; font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase; }
    .print-meta-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin-bottom: 22px; }
    .print-meta-card { padding: 18px 20px; }
    .print-card-title { font-size: 11px; letter-spacing: 1.4px; text-transform: uppercase; color: #64748b; font-weight: 700; margin-bottom: 12px; }
    .print-detail-grid { display: grid; gap: 10px; }
    .print-detail-item { display: grid; gap: 2px; }
    .print-detail-label { font-size: 11px; color: #64748b; font-weight: 600; }
    .print-detail-value { font-size: 13px; color: #0f172a; font-weight: 600; line-height: 1.4; }
    .print-section { margin-bottom: 12px; }
    .print-section-spaced { margin-top: 10px; }
    .print-section-head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin-bottom: 10px; }
    .print-section-title { font-size: 13px; font-weight: 800; color: #0f172a; text-transform: uppercase; letter-spacing: 1px; }
    .print-section-caption { font-size: 11px; color: #64748b; }
    .print-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 12px; overflow: hidden; border: 1px solid #e2e8f0; border-radius: 18px; }
    .print-table thead th { background: linear-gradient(180deg, #f8fafc 0%, #eef2f7 100%); padding: 11px 12px; text-align: left; font-weight: 700; color: #475569; border-bottom: 1px solid #dbe2ea; font-size: 11px; text-transform: uppercase; letter-spacing: 0.8px; }
    .print-table tbody td { padding: 10px 12px; border-bottom: 1px solid #eef2f7; }
    .print-table tbody tr:nth-child(even) { background: #fbfdff; }
    .print-table tbody tr:last-child td { border-bottom: none; }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .print-bottom-row { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr); gap: 18px; align-items: start; margin-top: 22px; }
    .print-note-card, .print-summary-card { padding: 18px 20px; min-height: 100%; }
    .print-note-copy { font-size: 12px; color: #475569; line-height: 1.7; }
    .print-summary-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .print-summary-table td { padding: 8px 0; border-bottom: 1px solid #e2e8f0; }
    .print-summary-label { font-weight: 600; color: #475569; text-align: left; padding-right: 16px; }
    .print-summary-value { font-weight: 700; text-align: right; }
    .print-summary-total td { font-size: 14px; padding: 12px 0; border-top: 2px solid #0f766e; border-bottom: 2px solid #0f766e; }
    .print-summary-total .print-summary-label { font-weight: 800; color: #0f172a; }
    .print-footer { text-align: center; margin-top: 26px; padding-top: 14px; border-top: 1px solid #e2e8f0; font-size: 10px; color: #94a3b8; }
    .print-footer-powered { font-size: 10px; color: #64748b; margin-top: 6px; letter-spacing: 0.4px; }
    @media (max-width: 780px) {
      body { padding: 0; background: #ffffff; }
      .print-document { padding: 18px; border-radius: 0; box-shadow: none; }
      .print-header, .print-meta-grid, .print-bottom-row { grid-template-columns: 1fr; display: grid; }
      .print-platform-card { width: 100%; align-items: flex-start; text-align: left; }
      .print-platform-copy { text-align: left; }
    }
    @media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
  `

  const source = printArea.value.querySelector('.print-document')
  if (!source) return

  const mount = document.createElement('div')
  mount.style.position = 'fixed'
  mount.style.left = '-20000px'
  mount.style.top = '0'
  mount.style.width = '860px'
  mount.style.zIndex = '-1'
  mount.style.background = '#e2e8f0'
  mount.style.padding = '24px'

  const styleEl = document.createElement('style')
  styleEl.textContent = styleText
  const clone = source.cloneNode(true)
  mount.appendChild(styleEl)
  mount.appendChild(clone)
  document.body.appendChild(mount)

  try {
    const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
      import('html2canvas'),
      import('jspdf'),
    ])

    if (document.fonts?.ready) await document.fonts.ready
    const images = Array.from(mount.querySelectorAll('img'))
    await Promise.all(images.map((img) => {
      if (img.complete) return Promise.resolve()
      return new Promise((resolve) => {
        img.addEventListener('load', resolve, { once: true })
        img.addEventListener('error', resolve, { once: true })
      })
    }))

    const canvas = await html2canvas(clone, {
      scale: 2,
      useCORS: true,
      backgroundColor: '#e2e8f0',
      windowWidth: clone.scrollWidth,
    })

    const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    const margin = 8
    const contentWidth = pageWidth - margin * 2
    const contentHeight = (canvas.height * contentWidth) / canvas.width
    const pageContentHeight = pageHeight - margin * 2
    const imageData = canvas.toDataURL('image/png')

    let heightLeft = contentHeight
    let position = margin
    pdf.addImage(imageData, 'PNG', margin, position, contentWidth, contentHeight, undefined, 'FAST')
    heightLeft -= pageContentHeight

    while (heightLeft > 0) {
      position -= pageContentHeight
      pdf.addPage()
      pdf.addImage(imageData, 'PNG', margin, position, contentWidth, contentHeight, undefined, 'FAST')
      heightLeft -= pageContentHeight
    }

    const fileName = (printContent.value.title || 'document').replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'document'
    pdf.save(`${fileName}.pdf`)
  } finally {
    document.body.removeChild(mount)
  }
}

// Bill generation
function openGenerateBill() { billGenForm.discount = 0; billGenForm.tax = 0; billGenForm.notes = ''; billGenDialog.value = true }
async function generateBill() {
  billingSaving.value = true
  try {
    await $api.post(`/homecare/patients/${id}/generate-bill/`, {
      discount: billGenForm.discount, tax: billGenForm.tax, notes: billGenForm.notes,
    })
    billGenDialog.value = false; notify('Bill generated successfully!', 'success'); await refreshBilling()
  } catch(e) { notify('Failed to generate bill: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { billingSaving.value = false }
}

// Payment recording
function openRecordPayment(bill) {
  paymentForm.amount = null; paymentForm.method = 'cash'; paymentForm.reference = ''; paymentForm.notes = ''
  paymentForm.paid_at = new Date().toISOString().slice(0, 16); paymentForm.bill_id = bill?.id || null
  paymentDialog.value = true
}
async function savePayment() {
  if (!paymentForm.amount || paymentForm.amount <= 0) return notify('Enter a valid amount', 'warning')
  billingSaving.value = true
  try {
    await $api.post('/homecare/patient-payments/', {
      patient: id, amount: paymentForm.amount, method: paymentForm.method,
      reference: paymentForm.reference, paid_at: paymentForm.paid_at || new Date().toISOString(),
      notes: paymentForm.notes, bill: paymentForm.bill_id || undefined,
    })
    paymentDialog.value = false; notify('Payment recorded!', 'success'); await refreshBilling()
  } catch(e) { notify('Failed to save payment: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { billingSaving.value = false }
}

// Payment plan
function openPlanDialog() {
  const p = carePlanData.value
  planForm.plan_type = p?.plan_type || 'daily'
  planForm.rate = p?.rate != null ? Number(p.rate) : null
  planForm.currency = p?.currency || 'KES'
  planForm.start_date = p?.start_date || new Date().toISOString().slice(0, 10)
  planForm.end_date = p?.end_date || ''
  planForm.notes = ''; planForm.auto_bill = p?.auto_bill !== undefined ? !!p.auto_bill : true
  planDialog.value = true
}
async function savePlan() {
  if (!planForm.rate && planForm.rate !== 0) return notify('Enter a rate', 'warning')
  billingSaving.value = true
  try {
    await $api.post('/homecare/care-plans/', {
      patient: id, plan_type: planForm.plan_type, rate: planForm.rate,
      currency: planForm.currency || 'KES', start_date: planForm.start_date,
      end_date: planForm.end_date || null, is_active: true, notes: planForm.notes,
      auto_bill: planForm.auto_bill,
    })
    planDialog.value = false; notify('Payment plan saved!', 'success'); await refreshBilling()
  } catch(e) { notify('Failed to save plan: ' + (e?.response?.data?.detail || e.message), 'error') }
  finally { billingSaving.value = false }
}

// Refresh
async function refreshBilling() {
  billingRefreshing.value = true
  try {
    const { data } = await $api.get(`/homecare/patients/${id}/care-summary/`)
    careSummaryData.value = data
    await loadKnownSupplyNames()
  }
  catch(e) { notify('Failed to refresh billing data', 'error') }
  finally { billingRefreshing.value = false }
}

// --- Helpers ---
function initials(n) { if(!n) return '?'; return n.split(' ').map(w=>w[0]||'').join('').toUpperCase().slice(0,2) }
function money(v, c) { const cur=c||'KES'; return (cur==='KES'?'KSh ':cur+' ')+Number(v||0).toLocaleString(undefined,{minimumFractionDigits:0,maximumFractionDigits:2}) }
function formatDate(v) { if(!v) return '—'; return new Date(v).toLocaleDateString(undefined,{day:'2-digit',month:'short',year:'numeric'}) }
function formatDateTime(v) { if(!v) return '—'; return new Date(v).toLocaleString(undefined,{day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'}) }
function formatShortDateTime(v) { if(!v) return '—'; return new Date(v).toLocaleString(undefined,{month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'}) }
function formatTime(v) { if(!v) return '—'; return new Date(v).toLocaleTimeString(undefined,{hour:'2-digit',minute:'2-digit'}) }
function news2Color(n) { if(n>=7) return 'error'; if(n>=5) return 'warning'; if(n>0) return 'info'; return 'success' }
function bradenRiskLabel(t) { if(t==null) return ''; if(t<=9) return 'Severe Risk'; if(t<=12) return 'High Risk'; if(t<=14) return 'Moderate Risk'; if(t<=18) return 'Mild Risk'; return 'No Risk' }
function notify(text, color='success') { snack.text=text; snack.color=color; snack.show=true }

// --- Patient Documents ---
const patientDocs = ref([])
const docLoading = ref(false)
const docSaving = ref(false)
const docSearch = ref('')
const docFilterAccess = ref(null)
const docSelectedCategory = ref([''])
const docUploadDialog = ref(false)
const docEditDialog = ref(false)
const docEditItem = ref(null)
const docDetailDialog = ref(false)
const docDetailItem = ref(null)
const docViewerDialog = ref(false)
const docViewerItem = ref(null)
const docViewerZoom = ref(1)
const docViewerRotation = ref(0)
const docViewerPanX = ref(0)
const docViewerPanY = ref(0)
const docIsDragging = ref(false)
const docDragStartX = ref(0)
const docDragStartY = ref(0)
const docDragStartPanX = ref(0)
const docDragStartPanY = ref(0)
const docImgNaturalW = ref(0)
const docImgNaturalH = ref(0)
const docViewerCanvas = ref(null)
const docPdfBlobUrl = ref(null)
const docPdfLoading = ref(false)
const docDeleteDialog = ref(false)
const docDeleteTarget = ref(null)

const docUploadForm = reactive({ name: '', category: 'other', access_level: 'care_team', expiry_date: '', file: null, description: '' })
const docEditForm = reactive({ name: '', category: 'other', access_level: 'care_team', expiry_date: '', file: null, description: '' })

const docCategories = [
  { value: 'insurance_card', label: 'Insurance Cards', icon: 'mdi-card-account-details', color: 'teal' },
  { value: 'id_document', label: 'ID Documents', icon: 'mdi-card-account-details-outline', color: 'amber' },
  { value: 'lab_report', label: 'Lab Reports', icon: 'mdi-test-tube', color: 'blue' },
  { value: 'imaging', label: 'Imaging / Radiology', icon: 'mdi-x-ray-box', color: 'purple' },
  { value: 'clinical_note', label: 'Clinical Notes', icon: 'mdi-note-text', color: 'indigo' },
  { value: 'prescription', label: 'Prescriptions', icon: 'mdi-prescription', color: 'pink' },
  { value: 'consent', label: 'Consents', icon: 'mdi-handshake', color: 'green' },
  { value: 'care_plan', label: 'Care Plans', icon: 'mdi-clipboard-text', color: 'cyan' },
  { value: 'other', label: 'Other', icon: 'mdi-file', color: 'grey' },
]
const docAccessLevels = [
  { value: 'care_team', label: 'Care Team' },
  { value: 'doctor_only', label: 'Doctor Only' },
  { value: 'nurse_only', label: 'Nurse Only' },
  { value: 'restricted', label: 'Restricted' },
]
const docHeaders = [
  { title: 'Document', key: 'name' },
  { title: 'Category', key: 'category' },
  { title: 'Access', key: 'access_level' },
  { title: 'Expires', key: 'expiry_date' },
  { title: 'Uploaded', key: 'uploaded_at' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const filteredPatientDocs = computed(() => {
  const q = docSearch.value.toLowerCase()
  const cat = docSelectedCategory.value?.[0]
  return patientDocs.value.filter(i => {
    if (cat && cat !== '' && i.category !== cat) return false
    if (docFilterAccess.value && i.access_level !== docFilterAccess.value) return false
    if (q && !`${i.name} ${i.description || ''}`.toLowerCase().includes(q)) return false
    return true
  })
})
const docRestrictedCount = computed(() => patientDocs.value.filter(i => i.access_level === 'restricted' || i.access_level === 'doctor_only').length)
const docExpiringCount = computed(() => patientDocs.value.filter(i => i.expiry_date && docDaysUntil(i.expiry_date) <= 30 && docDaysUntil(i.expiry_date) >= 0).length)
const docStorageUsed = computed(() => Math.round(patientDocs.value.reduce((s, i) => s + (i.file_size || 0), 0) / 1024 / 1024))

function docCountByCategory(cat) { return patientDocs.value.filter(i => i.category === cat).length }
function docDaysUntil(d) { return Math.round((new Date(d) - Date.now()) / 86400000) }
function docFormatSize(bytes) {
  if (!bytes) return '—'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / 1048576).toFixed(1) + ' MB'
}
function docCatLabel(c) { return docCategories.find(cat => cat.value === c)?.label || c || '—' }
function docCatColor(c) { return docCategories.find(cat => cat.value === c)?.color || 'teal' }
function docCatIcon(c) { return docCategories.find(cat => cat.value === c)?.icon || 'mdi-file' }
function docAccessLabel(a) { return docAccessLevels.find(l => l.value === a)?.label || a }
function docAccessColor(a) { return { care_team: 'success', doctor_only: 'warning', nurse_only: 'info', restricted: 'error' }[a] || 'grey' }
function docExpiryClass(d) {
  const days = docDaysUntil(d)
  if (days < 0) return 'text-red font-weight-bold'
  if (days <= 30) return 'text-orange font-weight-medium'
  return ''
}

async function loadPatientDocs() {
  docLoading.value = true
  try {
    const { data } = await $api.get('/homecare/patient-documents/', { params: { patient: id, page_size: 500 } })
    patientDocs.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    console.warn('load patient docs failed', e)
    patientDocs.value = []
  } finally { docLoading.value = false }
}

function openDocUploadDialog() {
  Object.assign(docUploadForm, { name: '', category: 'other', access_level: 'care_team', expiry_date: '', file: null, description: '' })
  docUploadDialog.value = true
}
function openDocEditDialog(item) {
  docEditItem.value = item
  Object.assign(docEditForm, {
    name: item.name || '', category: item.category || 'other',
    access_level: item.access_level || 'care_team',
    expiry_date: item.expiry_date || '', file: null,
    description: item.description || '',
  })
  docDetailDialog.value = false
  docEditDialog.value = true
}
async function saveDocEdit() {
  if (!docEditForm.name) { notify('Name required.', 'error'); return }
  docSaving.value = true
  try {
    const formData = new FormData()
    formData.append('name', docEditForm.name)
    formData.append('category', docEditForm.category)
    formData.append('access_level', docEditForm.access_level)
    if (docEditForm.expiry_date) formData.append('expiry_date', docEditForm.expiry_date)
    if (docEditForm.description) formData.append('description', docEditForm.description)
    if (docEditForm.file) formData.append('file', docEditForm.file)
    await $api.patch(`/homecare/patient-documents/${docEditItem.value.id}/`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    notify('Document updated.')
    docEditDialog.value = false
    loadPatientDocs()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update.', 'error')
  } finally { docSaving.value = false }
}
async function uploadPatientDoc() {
  if (!docUploadForm.name || !docUploadForm.file) { notify('Name and file required.', 'error'); return }
  docSaving.value = true
  try {
    const formData = new FormData()
    formData.append('name', docUploadForm.name)
    formData.append('category', docUploadForm.category)
    formData.append('access_level', docUploadForm.access_level)
    formData.append('patient', id)
    if (docUploadForm.expiry_date) formData.append('expiry_date', docUploadForm.expiry_date)
    if (docUploadForm.description) formData.append('description', docUploadForm.description)
    formData.append('file', docUploadForm.file)
    await $api.post('/homecare/patient-documents/', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    notify('Document uploaded.')
    docUploadDialog.value = false
    loadPatientDocs()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to upload.', 'error')
  } finally { docSaving.value = false }
}

function viewDocDetail(item) { docDetailItem.value = item; docDetailDialog.value = true }

const docImageStyle = computed(() => ({
  transform: `translate(${docViewerPanX.value}px, ${docViewerPanY.value}px) scale(${docViewerZoom.value}) rotate(${docViewerRotation.value}deg)`,
  transition: docIsDragging.value ? 'none' : 'transform 0.2s ease',
}))

function docResetView() {
  docViewerZoom.value = 1
  docViewerRotation.value = 0
  docViewerPanX.value = 0
  docViewerPanY.value = 0
}
function openDocViewer(item) {
  docViewerItem.value = item
  docDetailDialog.value = false
  docResetView()
  docPdfBlobUrl.value = null
  docPdfLoading.value = false
  docViewerDialog.value = true
  nextTick(() => { window.addEventListener('keydown', onDocKeydown) })
  const ptype = docPreviewType(item)
  if (ptype === 'pdf') loadDocPdfBlob(item)
}
function closeDocViewer() {
  docViewerDialog.value = false
  window.removeEventListener('keydown', onDocKeydown)
  if (docPdfBlobUrl.value) { URL.revokeObjectURL(docPdfBlobUrl.value); docPdfBlobUrl.value = null }
}
function docPreviewType(item) {
  if (!item?.file_url) return null
  const ext = (item.file_type || item.file_url.split('.').pop() || '').toLowerCase()
  const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']
  const pdfExts = ['pdf']
  const officeExts = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp']
  if (imageExts.includes(ext)) return 'image'
  if (pdfExts.includes(ext)) return 'pdf'
  if (officeExts.includes(ext)) return 'office'
  return null
}
async function loadDocPdfBlob(item) {
  if (!item?.file_url) return
  docPdfLoading.value = true
  try {
    const res = await fetch(item.file_url)
    const blob = await res.blob()
    docPdfBlobUrl.value = URL.createObjectURL(blob)
  } catch (e) {
    console.warn('Failed to load PDF blob', e)
  } finally { docPdfLoading.value = false }
}
function docOfficeViewerUrl(item) {
  if (!item?.file_url) return ''
  return `https://docs.google.com/gview?url=${encodeURIComponent(item.file_url)}&embedded=true`
}
function onDocImageLoad(e) {
  docImgNaturalW.value = e.target.naturalWidth
  docImgNaturalH.value = e.target.naturalHeight
  docFitToScreen()
}
function docZoomIn() { docViewerZoom.value = Math.min(docViewerZoom.value + 0.2, 5) }
function docZoomOut() { docViewerZoom.value = Math.max(docViewerZoom.value - 0.2, 0.2) }
function docRotateLeft() { docViewerRotation.value = (docViewerRotation.value - 90 + 360) % 360 }
function docRotateRight() { docViewerRotation.value = (docViewerRotation.value + 90) % 360 }
function docFitToScreen() {
  if (!docViewerCanvas.value || !docImgNaturalW.value) { docViewerZoom.value = 1; return }
  const cw = docViewerCanvas.value.clientWidth
  const ch = docViewerCanvas.value.clientHeight
  const scaleW = cw / docImgNaturalW.value
  const scaleH = ch / docImgNaturalH.value
  docViewerZoom.value = Math.min(scaleW, scaleH) * 0.9
  docViewerPanX.value = 0
  docViewerPanY.value = 0
}
function docActualSize() {
  docViewerZoom.value = 1
  docViewerPanX.value = 0
  docViewerPanY.value = 0
}
function onDocWheel(e) {
  if (e.deltaY < 0) docZoomIn()
  else docZoomOut()
}
function onDocDoubleClick() {
  if (docViewerZoom.value > 1.5) docFitToScreen()
  else { docViewerZoom.value = 2.5 }
}
function onDocDragStart(e) {
  if (docPreviewType(docViewerItem.value) !== 'image') return
  docIsDragging.value = true
  docDragStartX.value = e.clientX
  docDragStartY.value = e.clientY
  docDragStartPanX.value = docViewerPanX.value
  docDragStartPanY.value = docViewerPanY.value
}
function onDocDragMove(e) {
  if (!docIsDragging.value) return
  docViewerPanX.value = docDragStartPanX.value + (e.clientX - docDragStartX.value)
  docViewerPanY.value = docDragStartPanY.value + (e.clientY - docDragStartY.value)
}
function onDocDragEnd() { docIsDragging.value = false }
function onDocKeydown(e) {
  if (!docViewerDialog.value) return
  switch (e.key) {
    case '+': case '=': docZoomIn(); break
    case '-': case '_': docZoomOut(); break
    case '0': docFitToScreen(); break
    case '1': docActualSize(); break
    case 'r': case 'R': docRotateRight(); break
    case 'l': case 'L': docRotateLeft(); break
    case 'Escape': closeDocViewer(); break
    case 'ArrowLeft': docViewerPanX.value += 30; break
    case 'ArrowRight': docViewerPanX.value -= 30; break
    case 'ArrowUp': docViewerPanY.value += 30; break
    case 'ArrowDown': docViewerPanY.value -= 30; break
  }
}
onBeforeUnmount(() => { window.removeEventListener('keydown', onDocKeydown) })
function downloadPatientDoc(item) {
  if (item?.file_url) window.open(item.file_url, '_blank')
  else notify('File not available.', 'info')
}
function confirmDeleteDoc(item) { docDeleteTarget.value = item; docDeleteDialog.value = true }
async function doDeleteDoc() {
  docSaving.value = true
  try {
    await $api.delete(`/homecare/patient-documents/${docDeleteTarget.value.id}/`)
    notify('Document deleted.')
    docDeleteDialog.value = false
    loadPatientDocs()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  } finally { docSaving.value = false }
}

// --- Data loading ---
async function loadCompanyProfile() {
  try {
    const { data } = await $api.get('/homecare/company-profile/current/')
    companyProfile.value = data || null
  } catch(e) {
    try {
      const { data } = await $api.get('/homecare/company-profile/')
      companyProfile.value = Array.isArray(data) ? (data[0] || null) : data
    } catch {
      companyProfile.value = null
    }
  }
}
async function loadAll() {
  pageLoading.value = true
  try {
    const unwrap = (res) => res.data?.results || (Array.isArray(res.data) ? res.data : [])
    const [
      patientRes, vitalsRes, assessmentsRes, notesRes,
      bradenRes, capriniRes, morseRes, mustRes, camRes,
      painRes, skinRes, gcsRes, diabetesRes, hfRes, pivcRes, enteralRes, ucRes, airwayRes,
    ] = await Promise.all([
      $api.get(`/homecare/patients/${id}/care-summary/`),
      $api.get('/homecare/vitals/', { params: { patient: id } }),
      $api.get('/homecare/assessment-sessions/', { params: { patient: id, ordering: '-created_at' } }),
      $api.get('/homecare/notes/', { params: { patient: id, page_size: 200 } }),
      $api.get('/homecare/braden-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/caprini-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/morse-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/must-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/cam-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/pain-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/skin-care-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/gcs-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/diabetes-bundle-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/hf-bundle-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/pivc-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/enteral-feeding-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/urinary-catheter-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
      $api.get('/homecare/artificial-airway-assessments/', { params: { patient: id, ordering: '-assessed_at' } }),
    ])
    careSummaryData.value = patientRes.data
    loadDevices()  // populate drains & lines from device-assignments API
    // Vitals API returns plain array
    vitalsData.value = Array.isArray(vitalsRes.data) ? vitalsRes.data : (vitalsRes.data?.results || [])
    // Assessments API returns DRF-paginated { results, count }
    assessmentData.value = assessmentsRes.data?.results || (Array.isArray(assessmentsRes.data) ? assessmentsRes.data : [])
    bradenAssessments.value = unwrap(bradenRes)
    capriniAssessments.value = unwrap(capriniRes)
    morseAssessments.value = unwrap(morseRes)
    mustAssessments.value = unwrap(mustRes)
    camAssessments.value = unwrap(camRes)
    painAssessments.value = unwrap(painRes)
    skinCareAssessments.value = unwrap(skinRes)
    gcsAssessments.value = unwrap(gcsRes)
    diabetesBundleAssessments.value = unwrap(diabetesRes)
    hfBundleAssessments.value = unwrap(hfRes)
    pivcAssessments.value = unwrap(pivcRes)
    enteralFeedingAssessments.value = unwrap(enteralRes)
    urinaryCatheterAssessments.value = unwrap(ucRes)
    artificialAirwayAssessments.value = unwrap(airwayRes)
    if (skinCareAssessments.value.length) lastSkinCareTime.value = skinCareAssessments.value[0].assessed_at
    // Notes API
    patientNotes.value = notesRes.data?.results || (Array.isArray(notesRes.data) ? notesRes.data : [])
  } catch(e) {
    console.error('Failed to load patient data:', e)
    notify('Could not load patient data. Check console for details.', 'error')
  } finally {
    pageLoading.value = false
  }
}

onMounted(async () => {
  loadCompanyProfile()
  loadWorklistFromStorage() // load from localStorage first (instant)
  await loadAll()
  await loadKnownSupplyNames()
  await loadWorklistFromBackend() // merge with backend draft sessions
  loadPatientDocs() // load patient documents
  loadTreatmentPlans() // load treatment plans and medication schedules
  loadDoses() // load dose administration records
})
</script>

<style scoped>
.command-centre { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.cc-hero { position: relative; border-radius: 0 0 24px 24px; overflow: hidden; padding: 24px 24px 40px; box-shadow: 0 20px 60px -16px rgba(0,0,0,0.15); }
.cc-hero-inner { position: relative; z-index: 2; }
.cc-hero-glow { position: absolute; right: -80px; top: -100px; width: 340px; height: 340px; border-radius: 50%; background: radial-gradient(circle, rgba(255,255,255,0.1), transparent 65%); pointer-events: none; }
.cc-hero-pattern { position: absolute; inset: 0; background-image: radial-gradient(rgba(255,255,255,0.06) 1px, transparent 1px); background-size: 24px 24px; pointer-events: none; }
.cc-kpi-row { position: relative; z-index: 3; }
.cc-kpi-card { background: white; border: 1px solid rgba(15,23,42,0.05); transition: transform 0.2s; }
.cc-kpi-card:hover { transform: translateY(-2px); }
.cc-main { background: white; border: 1px solid rgba(15,23,42,0.06); position: relative; }
.cc-tabs :deep(.v-tab) { text-transform: none; letter-spacing: 0; }
.cc-worklist-item { background: rgba(255,255,255,0.7); transition: background .2s; }
.cc-worklist-item:hover { background: rgba(255,255,255,0.95); }
.cc-gauge { position: relative; width: 120px; height: 120px; flex-shrink: 0; }
.cc-gauge-svg { width: 100%; height: 100%; }
.cc-gauge-arc { transition: stroke-dasharray 0.5s ease, stroke 0.5s ease; }
.cc-gauge-value { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.cc-countdown-track { height: 8px; background: rgba(148,163,184,0.15); border-radius: 4px; overflow: hidden; }
.cc-countdown-track-lg { height: 14px; border-radius: 7px; }
.cc-countdown-track-sm { height: 4px; border-radius: 2px; }
.cc-countdown-fill { height: 100%; border-radius: inherit; transition: width 30s linear; }
.cc-news2-row { display: flex; align-items: center; padding: 4px 0; border-bottom: 1px solid rgba(148,163,184,0.12); }
.cc-news2-row:last-child { border-bottom: none; }
.cc-skin-item { background: rgba(255,255,255,0.5); transition: background .2s; }
.cc-skin-item.done { background: rgba(5,150,105,0.08); }
.cc-assessment-card { transition: border-color .2s; }
.cc-clinical-card { transition: border-color .2s; }
.cc-device-card { transition: border-color .2s; }
.cc-fluid-in { background: rgba(14,165,233,0.03); }
.cc-fluid-out { background: rgba(249,115,22,0.03); }
.cc-table :deep(table) { font-size: 13px; }
.news2-panel { border: 1px solid rgba(13,148,136,0.2); border-radius: 16px; padding: 16px; position: sticky; top: 8px; }
.news2-total { font-size: 46px; font-weight: 800; line-height: 1; margin: 2px 0 8px; }
.news2-row { display: flex; align-items: center; padding: 5px 0; border-bottom: 1px solid rgba(148,163,184,0.15); }
.news2-row:last-child { border-bottom: none; }
.border-teal { border-color: rgba(13,148,136,0.4) !important; }
.border-warning { border-color: rgba(245,158,11,0.4) !important; }
.border-purple { border-color: rgba(124,58,237,0.4) !important; }
.cc-bill-row { background: rgba(8,145,178,0.04); transition: background .15s; }
.cc-bill-row:hover { background: rgba(8,145,178,0.08); }
.cc-payment-row { background: rgba(22,163,74,0.04); transition: background .15s; }
.cc-payment-row:hover { background: rgba(22,163,74,0.08); }
.cc-bill-table :deep(table) { font-size: 13px; }

/* ═══════ Assessment Master-Detail Layout ═══════ */
.hc-assess-layout {
  display: flex; gap: 16px; height: calc(100vh - 280px); min-height: 500px;
}
.hc-assess-list {
  width: 340px; flex-shrink: 0; display: flex; flex-direction: column;
  background: white; border: 1px solid rgba(15,23,42,0.06); border-radius: 16px; overflow: hidden;
}
.hc-assess-list-scroll {
  flex: 1; overflow-y: auto; padding: 8px;
}
.hc-assess-list-scroll::-webkit-scrollbar { width: 5px; }
.hc-assess-list-scroll::-webkit-scrollbar-track { background: transparent; }
.hc-assess-list-scroll::-webkit-scrollbar-thumb { background: rgba(148,163,184,0.3); border-radius: 3px; }

.hc-assess-item {
  position: relative; display: flex; align-items: center; gap: 12px; padding: 10px 12px 10px 16px;
  margin-bottom: 6px; border-radius: 12px; cursor: pointer; transition: all .18s ease;
  border: 1px solid transparent; background: transparent;
}
.hc-assess-item:hover { background: rgba(15,23,42,0.03); }
.hc-assess-item--active {
  background: rgba(13,148,136,0.06); border-color: rgba(13,148,136,0.2);
  box-shadow: 0 1px 4px rgba(13,148,136,0.08);
}
.hc-assess-item-accent {
  position: absolute; left: 0; top: 8px; bottom: 8px; width: 3px; border-radius: 2px; opacity: .7;
}
.hc-assess-item--active .hc-assess-item-accent { opacity: 1; width: 4px; }

.hc-assess-legend {
  padding: 10px 16px; border-top: 1px solid rgba(15,23,42,0.06);
  background: rgba(248,250,252,0.6);
}

.hc-assess-detail {
  flex: 1; overflow-y: auto; min-width: 0;
  background: white; border: 1px solid rgba(15,23,42,0.06); border-radius: 16px;
}
.hc-assess-detail::-webkit-scrollbar { width: 5px; }
.hc-assess-detail::-webkit-scrollbar-track { background: transparent; }
.hc-assess-detail::-webkit-scrollbar-thumb { background: rgba(148,163,184,0.3); border-radius: 3px; }

.hc-assess-detail-empty { min-height: 400px; }

.hc-detail-header {
  padding: 20px; border-radius: 16px 16px 0 0;
  border-bottom: 1px solid rgba(15,23,42,0.05);
}

.hc-detail-tile {
  padding: 12px; border-radius: 12px; background: rgba(248,250,252,0.8);
  border: 1px solid rgba(15,23,42,0.05); text-align: center; min-height: 80px;
  display: flex; flex-direction: column; justify-content: center;
}

.hc-history-entry {
  padding: 12px; border-radius: 10px; border: 1px solid rgba(15,23,42,0.06);
  background: rgba(248,250,252,0.5); transition: border-color .15s;
}
.hc-history-entry:hover { border-color: rgba(13,148,136,0.15); }
.hc-history-entry--latest {
  border-color: rgba(13,148,136,0.2); background: rgba(13,148,136,0.03);
}

/* ── Dose Cards (in patient-care) ── */
.cc-dose-card {
  position: relative; border-radius: 16px; overflow: hidden;
  background: #fff; border: 1px solid rgba(15,23,42,0.06);
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.cc-dose-card:hover { border-color: rgba(13,148,136,0.18); box-shadow: 0 4px 16px -4px rgba(0,0,0,0.06); }
.cc-dose-card-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.cc-dose-card-avatar {
  flex-shrink: 0; border: 2px solid transparent;
}
.cc-dose-card-avatar--taken    { background: rgba(16,185,129,0.10) !important; border-color: rgba(16,185,129,0.25) !important; }
.cc-dose-card-avatar--taken .v-icon { color: #10b981 !important; }
.cc-dose-card-avatar--pending  { background: rgba(245,158,11,0.10) !important; border-color: rgba(245,158,11,0.25) !important; }
.cc-dose-card-avatar--pending .v-icon { color: #f59e0b !important; }
.cc-dose-card-avatar--missed   { background: rgba(239,68,68,0.10) !important; border-color: rgba(239,68,68,0.25) !important; }
.cc-dose-card-avatar--missed .v-icon { color: #ef4444 !important; }
.cc-dose-card-avatar--skipped  { background: rgba(148,163,184,0.10) !important; border-color: rgba(148,163,184,0.25) !important; }
.cc-dose-card-avatar--skipped .v-icon { color: #94a3b8 !important; }
.cc-dose-card-avatar--overdue  { background: rgba(239,68,68,0.10) !important; border-color: rgba(239,68,68,0.25) !important; }
.cc-dose-card-avatar--overdue .v-icon { color: #ef4444 !important; }
.cc-dose-card-avatar--not_given { background: rgba(220,38,38,0.10) !important; border-color: rgba(220,38,38,0.25) !important; }
.cc-dose-card-avatar--not_given .v-icon { color: #dc2626 !important; }
.cc-dose-card-title { color: #1e293b; }
.cc-dose-card-status { color: white !important; }
.cc-dose-card-status--taken    { background: #10b981 !important; }
.cc-dose-card-status--pending  { background: #f59e0b !important; }
.cc-dose-card-status--missed   { background: #ef4444 !important; }
.cc-dose-card-status--skipped  { background: #94a3b8 !important; }
.cc-dose-card-status--overdue  { background: #ef4444 !important; }
.cc-dose-card-status--not_given { background: #dc2626 !important; }
.cc-dose-card-auto { background: rgba(245,158,11,0.12) !important; color: #d97706 !important; }
.cc-dose-card-dose { color: #64748b !important; }
.cc-dose-card-meta { color: #64748b; font-size: 12px; }
.cc-dose-card-meta-item { display: inline-flex; align-items: center; gap: 3px; }
.cc-dose-card-meta-item--taken { color: #10b981; }
.cc-dose-card-reason { color: #94a3b8; font-size: 12px; display: flex; align-items: center; gap: 4px; }

/* ── Dose Action Dialog ── */
.cc-dose-action-hero { border-radius: 16px 16px 0 0; }
.cc-dose-action-hero-icon {
  width: 56px; height: 56px; border-radius: 14px;
  background: rgba(255,255,255,0.18); display: flex; align-items: center; justify-content: center;
}
.cc-dose-action-info { background: rgba(13,148,136,0.06); border: 1px solid rgba(13,148,136,0.12); }
</style>
