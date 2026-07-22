<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- ═══════ HERO ═══════ -->
    <div class="hc-hero pa-6 pa-md-7 mb-5">
      <div class="hc-hero-inner">
        <div class="d-flex align-center flex-wrap ga-4">
          <div class="flex-grow-1">
            <div class="d-flex align-center mb-1">
              <v-avatar size="48" class="hc-hero-icon mr-3">
                <v-icon icon="mdi-clipboard-list-outline" size="26" />
              </v-avatar>
              <div>
                <div class="text-overline font-weight-bold text-teal-darken-2">CLINICAL ASSESSMENT</div>
                <h1 class="text-h4 text-md-h3 font-weight-bold ma-0">{{ session.patient_name || 'Patient Assessment' }}</h1>
              </div>
            </div>
            <p class="text-body-1 text-medium-emphasis mb-3 mt-1">
              {{ session.session_type_label }} · {{ formatFull(session.assessed_at) }} · by <strong>{{ session.assessed_by_name || '—' }}</strong>
            </p>
            <v-chip-group column class="mt-1">
              <v-chip size="small" color="teal" variant="tonal">{{ session.session_type_label }}</v-chip>
              <v-chip size="small" :color="riskColor" variant="flat" class="text-white font-weight-bold">
                {{ session.overall_risk_label || session.overall_risk_level || 'Risk N/A' }}
              </v-chip>
              <v-chip v-if="alerts.length" size="small" color="error" variant="tonal" class="font-weight-bold">
                <v-icon start icon="mdi-bell-alert" size="14" /> {{ alerts.length }} alert{{ alerts.length !== 1 ? 's' : '' }}
              </v-chip>
            </v-chip-group>
          </div>
          <div class="d-flex ga-2">
            <v-btn variant="tonal" rounded="pill" color="teal" class="text-none"
                   prepend-icon="mdi-arrow-left" to="/homecare/assessments">
              Back
            </v-btn>
          </div>
        </div>
      </div>
    </div>

    <v-row dense>
      <!-- ─── Initial Survey + Vitals ─── -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-4">
            <div class="hc-panel-icon" style="background:linear-gradient(135deg,#0d9488,#0f766e);">
              <v-icon icon="mdi-account-check" size="18" />
            </div>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Initial Survey</h3>
              <div class="text-caption text-medium-emphasis">Arrival + vital signs + primary survey</div>
            </div>
          </div>
          <v-divider class="mb-3" />
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-if="ini.temperature != null">
              <v-list-item-title class="text-caption font-weight-medium">Temperature</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.temperature }} °C</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="ini.systolic_bp != null">
              <v-list-item-title class="text-caption font-weight-medium">Blood Pressure</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.systolic_bp }}/{{ ini.diastolic_bp }} mmHg</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="ini.heart_rate != null">
              <v-list-item-title class="text-caption font-weight-medium">Heart Rate</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.heart_rate }} bpm</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="ini.respiratory_rate != null">
              <v-list-item-title class="text-caption font-weight-medium">Respiratory Rate</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.respiratory_rate }} /min</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="ini.spo2 != null">
              <v-list-item-title class="text-caption font-weight-medium">SpO₂</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.spo2 }}%</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Consciousness</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.consciousness || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Pain Score</v-list-item-title>
              <v-list-item-subtitle class="text-body-2 font-weight-bold" :class="painClass(ini.pain_score)">
                {{ ini.pain_score != null ? ini.pain_score + '/10' : '—' }}
                <v-chip v-if="ini.pain_score != null" size="x-small" :color="painChipColor(ini.pain_score)" variant="tonal" class="ml-1">
                  {{ painCategory(ini.pain_score) }}
                </v-chip>
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Skin Integrity</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.skin_integrity || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Skin Moisture</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ ini.skin_moisture || '—' }}</v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <v-expand-transition>
            <div v-if="showMoreInit">
              <v-divider class="mb-3" />
              <v-list density="compact" class="bg-transparent pa-0">
                <v-list-item>
                  <v-list-item-title class="text-caption font-weight-medium">Chief concern</v-list-item-title>
                  <v-list-item-subtitle class="text-body-2">{{ ini.chief_concern || '—' }}</v-list-item-subtitle>
                </v-list-item>
                <v-list-item>
                  <v-list-item-title class="text-caption font-weight-medium">General appearance</v-list-item-title>
                  <v-list-item-subtitle class="text-body-2">{{ ini.general_appearance || '—' }}</v-list-item-subtitle>
                </v-list-item>
                <v-list-item>
                  <v-list-item-title class="text-caption font-weight-medium">Recent falls</v-list-item-title>
                  <v-list-item-subtitle class="text-body-2">{{ ini.recent_falls != null ? ini.recent_falls : '—' }}</v-list-item-subtitle>
                </v-list-item>
                <v-list-item>
                  <v-list-item-title class="text-caption font-weight-medium">Devices</v-list-item-title>
                  <v-list-item-subtitle class="text-body-2">
                    <v-chip v-if="ini.has_catheter" size="x-small" color="info" variant="tonal" class="mr-1">Catheter</v-chip>
                    <v-chip v-if="ini.has_central_line" size="x-small" color="warning" variant="tonal" class="mr-1">Central line</v-chip>
                    <v-chip v-if="ini.has_ventilator" size="x-small" color="error" variant="tonal" class="mr-1">Ventilator</v-chip>
                    <v-chip v-if="ini.has_wound" size="x-small" color="purple" variant="tonal">Wound</v-chip>
                    <span v-if="!ini.has_catheter && !ini.has_central_line && !ini.has_ventilator && !ini.has_wound" class="text-medium-emphasis">None</span>
                  </v-list-item-subtitle>
                </v-list-item>
                <v-list-item v-if="ini.allergies">
                  <v-list-item-title class="text-caption font-weight-medium">Allergies</v-list-item-title>
                  <v-list-item-subtitle class="text-body-2">{{ ini.allergies }}</v-list-item-subtitle>
                </v-list-item>
              </v-list>
            </div>
          </v-expand-transition>
          <v-btn variant="text" size="small" class="text-none mt-2" @click="showMoreInit = !showMoreInit">
            {{ showMoreInit ? 'Show less' : 'Show more' }}
          </v-btn>
        </v-card>
      </v-col>

      <!-- ─── Head-to-Toe ─── -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-4">
            <div class="hc-panel-icon" style="background:linear-gradient(135deg,#0284c7,#0369a1);">
              <v-icon icon="mdi-human-male-board" size="18" />
            </div>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Head-to-Toe</h3>
              <div class="text-caption text-medium-emphasis">Systematic body systems survey</div>
            </div>
          </div>
          <v-divider class="mb-3" />
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Orientation</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">
                Time: <strong>{{ fmtBool(h2t.oriented_time) }}</strong> ·
                Place: <strong>{{ fmtBool(h2t.oriented_place) }}</strong> ·
                Person: <strong>{{ fmtBool(h2t.oriented_person) }}</strong>
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Mobility</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.mobility_level || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Heart Rhythm</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.heart_rhythm || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Peripheral pulses</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.peripheral_pulses || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Breath Sounds</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.breath_sounds || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Respiratory Effort</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.resp_effort || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="h2t.on_oxygen">
              <v-list-item-title class="text-caption font-weight-medium">Oxygen</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.oxygen_flow_lpm }} LPM via {{ h2t.oxygen_mode || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Abdomen</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.abdomen_shape || '—' }} · Bowel: {{ h2t.bowel_sounds || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption font-weight-medium">Continence</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">Urinary: {{ h2t.urinary_continence }} · Bowel: {{ h2t.bowel_continence }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="h2t.any_wounds">
              <v-list-item-title class="text-caption font-weight-medium">Wounds</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ h2t.wound_descriptions?.length || 0 }} wound(s) noted</v-list-item-subtitle>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>

      <!-- ─── Risk Scores Summary ─── -->
      <v-col cols="12" lg="4">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-4">
            <div class="hc-panel-icon" style="background:linear-gradient(135deg,#7c3aed,#6d28d9);">
              <v-icon icon="mdi-shield-check" size="18" />
            </div>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Risk Scores</h3>
              <div class="text-caption text-medium-emphasis">Validated scales at a glance</div>
            </div>
          </div>
          <v-divider class="mb-3" />
          <div v-for="rs in riskCards" :key="rs.code" class="d-flex align-center ga-3 pa-3 rounded-lg mb-2 hc-risk-row">
            <v-avatar size="40" :color="rs.bg" variant="tonal">
              <v-icon :icon="rs.icon" :color="rs.color" size="20" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="d-flex align-center">
                <span class="text-body-2 font-weight-medium">{{ rs.label }}</span>
                <v-spacer />
                <span class="text-h6 font-weight-bold" :style="{ color: rs.color }">{{ rs.score }}</span>
                <span class="text-caption text-medium-emphasis ml-1">{{ rs.unit }}</span>
              </div>
              <v-chip size="x-small" :color="rs.color" variant="tonal" class="font-weight-bold mt-1">
                <v-icon start :icon="rs.alertIcon" size="12" />{{ rs.riskLabel }}
              </v-chip>
            </div>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex align-center pa-3 rounded-lg" :style="{ background: bgByRisk, borderRadius: '12px' }">
            <v-avatar size="44" :color="riskColor" variant="flat">
              <v-icon icon="mdi-shield-check" color="white" size="22" />
            </v-avatar>
            <div class="ml-3 text-white">
              <div class="text-caption font-weight-bold text-uppercase" style="opacity:.85">Overall Risk Level</div>
              <div class="text-h5 font-weight-bold">{{ session.overall_risk_label || session.overall_risk_level || 'Unknown' }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════ ALERTS ── if any ═══════ -->
    <v-row v-if="alerts.length" dense class="mt-2">
      <v-col cols="12">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-3">
            <v-avatar size="36" color="error" variant="tonal">
              <v-icon icon="mdi-bell-alert" color="error" size="18" />
            </v-avatar>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Clinical Alerts ({{ alerts.length }})</h3>
              <div class="text-caption text-medium-emphasis">Threshold-triggered notifications requiring action</div>
            </div>
          </div>
          <v-alert
            v-for="(a, i) in alerts" :key="i"
            :type="a.severity === 'critical' ? 'error' : a.severity === 'high' ? 'warning' : 'info'"
            variant="tonal" rounded="lg" density="compact" class="mb-2"
            :icon="a.severity === 'critical' ? 'mdi-alert-octagon' : a.severity === 'high' ? 'mdi-alert' : 'mdi-information'"
          >
            <div class="d-flex flex-column ga-1">
              <div class="d-flex align-center ga-2">
                <span class="font-weight-bold text-body-2">{{ a.title }}</span>
                <v-chip size="x-small" color="grey" variant="tonal" class="text-caption">{{ a.code }}</v-chip>
              </div>
              <div class="text-caption">{{ a.detail }}</div>
              <div v-if="a.recommendation" class="text-caption font-weight-medium" style="opacity:.85">🅁 {{ a.recommendation }}</div>
            </div>
          </v-alert>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════ DETAILED SCALES – accordion ═══════ -->
    <v-row dense class="mt-2">
      <v-col cols="12">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-4">
            <div class="hc-panel-icon" style="background:linear-gradient(135deg,#10b981,#059669);">
              <v-icon icon="mdi-chart-box-outline" size="18" />
            </div>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Detailed Scale Breakdowns</h3>
              <div class="text-caption text-medium-emphasis">Individual component scores per validated tool</div>
            </div>
          </div>
          <v-expansion-panels variant="accordion" class="hc-expand">
            <!-- Braden -->
            <v-expansion-panel v-if="session.braden" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-human" color="teal" />
                    Braden Scale — Pressure Ulcer Risk
                    <v-chip size="x-small" :color="bradenColor" variant="flat" class="ml-2 text-white font-weight-bold">
                      {{ session.braden.total }} · {{ session.braden.risk_level }}
                    </v-chip>
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead><tr><th>Subscale</th><th>Score</th></tr></thead>
                  <tbody>
                    <tr v-for="s in BRADEN_SUBSCALES" :key="s.key">
                      <td class="text-body-2">{{ s.label }}</td>
                      <td><span class="font-weight-bold">{{ session.braden[s.key] ?? '—' }}</span></td>
                    </tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Caprini -->
            <v-expansion-panel v-if="session.vte_caprini" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-blood-bag" color="purple" />
                    Caprini Score — VTE Risk
                    <v-chip size="x-small" :color="capriniColor" variant="flat" class="ml-2 text-white font-weight-bold">
                      {{ session.vte_caprini.points }} · {{ session.vte_caprini.risk_level }}
                    </v-chip>
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead><tr><th>Factor</th><th>Points</th><th>Present</th></tr></thead>
                  <tbody>
                    <tr v-for="f in CAPRINI_FACTORS" :key="f.key">
                      <td class="text-body-2">{{ f.label }}</td>
                      <td>{{ f.points }}</td>
                      <td>
                        <v-icon v-if="session.vte_caprini.factors?.[f.key]" color="success" size="16">mdi-check</v-icon>
                        <span v-else class="text-medium-emphasis">—</span>
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Morse -->
            <v-expansion-panel v-if="session.falls" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-fall" color="warning" />
                    Morse Fall Scale
                    <v-chip size="x-small" :color="morseColor" variant="flat" class="ml-2 text-white font-weight-bold">
                      {{ session.falls.score }} · {{ session.falls.risk_level }}
                    </v-chip>
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead><tr><th>Item</th><th>Score</th></tr></thead>
                  <tbody>
                    <tr><td>History of falls</td><td class="font-weight-bold">{{ session.falls.history_of_falls ? 15 : 0 }}</td></tr>
                    <tr><td>Secondary diagnosis</td><td class="font-weight-bold">{{ session.falls.secondary_dx ? 15 : 0 }}</td></tr>
                    <tr><td>Ambulatory aid</td><td class="font-weight-bold">{{ session.falls.ambulatory_aid }}</td></tr>
                    <tr><td>IV / heparin lock</td><td class="font-weight-bold">{{ session.falls.iv_lock ? 15 : 0 }}</td></tr>
                    <tr><td>Gait</td><td class="font-weight-bold">{{ session.falls.gait }}</td></tr>
                    <tr><td>Mental status</td><td class="font-weight-bold">{{ session.falls.mental_status }}</td></tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- MUST -->
            <v-expansion-panel v-if="session.must" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-food-apple" color="error" />
                    MUST — Malnutrition Risk
                    <v-chip size="x-small" :color="mustColor" variant="flat" class="ml-2 text-white font-weight-bold">
                      {{ session.must.total_score }} · {{ session.must.risk_level }}
                    </v-chip>
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead><tr><th>Component</th><th>Value</th><th>Score</th></tr></thead>
                  <tbody>
                    <tr><td>BMI</td><td>{{ session.must.bmi ?? '—' }}</td><td class="font-weight-bold">{{ session.must.bmi_score ?? '—' }}</td></tr>
                    <tr><td>Weight loss</td><td>{{ session.must.weight_loss_percent ?? '—' }}%</td><td class="font-weight-bold">{{ session.must.loss_score ?? '—' }}</td></tr>
                    <tr><td>Acute illness / no intake >5d</td><td>{{ fmtBool(session.must.acute_no_nutrition) }}</td><td class="font-weight-bold">{{ session.must.acute_score ?? '—' }}</td></tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- CAM -->
            <v-expansion-panel v-if="session.cam" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-brain" color="purple" />
                    CAM — Delirium Screen
                    <v-chip size="x-small" :color="session.cam.cam_positive ? 'error' : 'success'" variant="flat" class="ml-2 text-white font-weight-bold">
                      {{ session.cam.cam_positive ? 'POSITIVE' : 'Negative' }}
                    </v-chip>
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead><tr><th>Criterion</th><th>Present</th></tr></thead>
                  <tbody>
                    <tr><td>Acute onset / fluctuating</td><td><v-icon :color="session.cam.acute_onset ? 'error' : 'grey'">{{ session.cam.acute_onset ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></td></tr>
                    <tr><td>Inattention</td><td><v-icon :color="session.cam.inattention ? 'error' : 'grey'">{{ session.cam.inattention ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></td></tr>
                    <tr><td>Disorganised thinking</td><td><v-icon :color="session.cam.disorganized_thinking ? 'error' : 'grey'">{{ session.cam.disorganized_thinking ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></td></tr>
                    <tr><td>Altered consciousness</td><td><v-icon :color="session.cam.altered_consciousness ? 'error' : 'grey'">{{ session.cam.altered_consciousness ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></td></tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Catheter bundle -->
            <v-expansion-panel v-if="session.catheter_bundle?.present" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-water-pipe" color="info" />
                    Catheter Bundle (CAUTI Prevention)
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item><v-list-item-title class="text-caption">Type</v-list-item-title><v-list-item-subtitle>{{ session.catheter_bundle.type }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Insertion date</v-list-item-title><v-list-item-subtitle>{{ session.catheter_bundle.insert_date }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Indication</v-list-item-title><v-list-item-subtitle>{{ session.catheter_bundle.indication || '—' }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Closed system maintained</v-list-item-title><v-list-item-subtitle><v-icon :color="session.catheter_bundle.closed_system_maintained ? 'success' : 'error'">{{ session.catheter_bundle.closed_system_maintained ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Bag below bladder</v-list-item-title><v-list-item-subtitle><v-icon :color="session.catheter_bundle.bag_below_bladder ? 'success' : 'error'">{{ session.catheter_bundle.bag_below_bladder ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Needs review</v-list-item-title><v-list-item-subtitle><v-chip size="x-small" :color="session.catheter_bundle.needs_review ? 'error' : 'success'">{{ session.catheter_bundle.needs_review ? 'Yes — prompt removal' : 'Still indicated' }}</v-chip></v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Central Line bundle -->
            <v-expansion-panel v-if="session.central_line_bundle?.present" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-needle" color="purple" />
                    Central Line Bundle (CLABSI Prevention)
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item><v-list-item-title class="text-caption">Type</v-list-item-title><v-list-item-subtitle>{{ session.central_line_bundle.type }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Insertion site</v-list-item-title><v-list-item-subtitle>{{ session.central_line_bundle.insert_site || '—' }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Maximal barrier used</v-list-item-title><v-list-item-subtitle><v-icon :color="session.central_line_bundle.maximal_barrier ? 'success' : 'error'">{{ session.central_line_bundle.maximal_barrier ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Hub scrub protocol</v-list-item-title><v-list-item-subtitle><v-icon :color="session.central_line_bundle.hub_scrub ? 'success' : 'error'">{{ session.central_line_bundle.hub_scrub ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Needs removal</v-list-item-title><v-list-item-subtitle><v-chip size="x-small" :color="session.central_line_bundle.needs_removal ? 'error' : 'success'">{{ session.central_line_bundle.needs_removal ? 'Yes — prompt removal' : 'Still indicated' }}</v-chip></v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Ventilator bundle -->
            <v-expansion-panel v-if="session.ventilator_bundle?.present" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-ventilator" color="error" />
                    Ventilator Bundle (VAP Prevention)
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item><v-list-item-title class="text-caption">Head of bed elevated ≥30°</v-list-item-title><v-list-item-subtitle><v-icon :color="session.ventilator_bundle.head_of_bed_elevated ? 'success' : 'error'">{{ session.ventilator_bundle.head_of_bed_elevated ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Daily spontaneous breathing trial</v-list-item-title><v-list-item-subtitle><v-icon :color="session.ventilator_bundle.daily_sbt ? 'success' : 'error'">{{ session.ventilator_bundle.daily_sbt ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Sedation vacation</v-list-item-title><v-list-item-subtitle><v-icon :color="session.ventilator_bundle.sedation_vacation ? 'success' : 'error'">{{ session.ventilator_bundle.sedation_vacation ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Oral care performed</v-list-item-title><v-list-item-subtitle><v-icon :color="session.ventilator_bundle.oral_care ? 'success' : 'error'">{{ session.ventilator_bundle.oral_care ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item v-if="session.ventilator_bundle.vent_settings"><v-list-item-title class="text-caption">Settings</v-list-item-title><v-list-item-subtitle>{{ session.ventilator_bundle.vent_settings }}</v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Wound Bundle -->
            <v-expansion-panel v-if="session.wound_bundle?.present" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-bandage" color="orange" />
                    Wound / Pressure Injury Bundle — NPIAP
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item><v-list-item-title class="text-caption">Turn schedule</v-list-item-title><v-list-item-subtitle>Every {{ session.wound_bundle.turn_schedule_hours }} h</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Special mattress</v-list-item-title><v-list-item-subtitle><v-icon :color="session.wound_bundle.special_mattress ? 'success' : 'grey'">{{ session.wound_bundle.special_mattress ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Barrier cream applied</v-list-item-title><v-list-item-subtitle><v-icon :color="session.wound_bundle.barrier_cream ? 'success' : 'grey'">{{ session.wound_bundle.barrier_cream ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item v-if="(session.wound_bundle.wound_details || []).length"><v-list-item-title class="text-caption">Wound details</v-list-item-title><v-list-item-subtitle>
                    <div v-for="(w, wi) in session.wound_bundle.wound_details" :key="wi" class="text-caption">• {{ w.location }} — {{ w.type }} ({{ w.size }})</div>
                  </v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Diabetes Bundle -->
            <v-expansion-panel v-if="session.disease_bundles?.diabetes?.foot_ulcer != null || session.disease_bundles?.diabetes?.latest_bg != null" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-water" color="blue" />
                    Diabetes Bundle
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item><v-list-item-title class="text-caption">Foot ulcer</v-list-item-title><v-list-item-subtitle><v-icon :color="session.disease_bundles.diabetes.foot_ulcer ? 'error' : 'success'">{{ session.disease_bundles.diabetes.foot_ulcer ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon></v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Neuropathy</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.diabetes.neuropathy) }}</v-list-item-subtitle></v-list-item>
                  <v-list-item v-if="session.disease_bundles.diabetes.latest_bg != null"><v-list-item-title class="text-caption">Blood glucose</v-list-item-title><v-list-item-subtitle>{{ session.disease_bundles.diabetes.latest_bg }} mg/dL</v-list-item-subtitle></v-list-item>
                  <v-list-item v-if="session.disease_bundles.diabetes.latest_bg_mmol != null"><v-list-item-title class="text-caption">Blood glucose (mmol/L)</v-list-item-title><v-list-item-subtitle>{{ session.disease_bundles.diabetes.latest_bg_mmol }} mmol/L</v-list-item-subtitle></v-list-item>
                  <v-list-item v-if="session.disease_bundles.diabetes.last_foot_check"><v-list-item-title class="text-caption">Last foot inspection</v-list-item-title><v-list-item-subtitle>{{ session.disease_bundles.diabetes.last_foot_check }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Insulin pump</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.diabetes.insulin_pump) }}</v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Heart Failure Bundle -->
            <v-expansion-panel v-if="session.disease_bundles?.heart_failure?.daily_weight != null || session.disease_bundles?.heart_failure?.edema" rounded="xl">
              <v-expansion-panel-title class="text-subtitle-2 font-weight-bold">
                <template #default>
                  <div class="d-flex align-center ga-2">
                    <v-icon icon="mdi-heart" color="red" />
                    Heart Failure Bundle
                  </div>
                </template>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-list density="compact" class="bg-transparent pa-0">
                  <v-list-item v-if="session.disease_bundles.heart_failure.daily_weight != null"><v-list-item-title class="text-caption">Daily weight</v-list-item-title><v-list-item-subtitle>{{ session.disease_bundles.heart_failure.daily_weight }} kg</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Edema</v-list-item-title><v-list-item-subtitle>{{ session.disease_bundles.heart_failure.edema || 'None' }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">SOB at rest</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.heart_failure.sob_at_rest) }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">SOB on exertion</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.heart_failure.sob_on_exertion) }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Orthopnea</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.heart_failure.orthopnea) }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">JVD</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.heart_failure.jvd) }}</v-list-item-subtitle></v-list-item>
                  <v-list-item><v-list-item-title class="text-caption">Lung crackles</v-list-item-title><v-list-item-subtitle>{{ fmtBool(session.disease_bundles.heart_failure.lung_crackles) }}</v-list-item-subtitle></v-list-item>
                </v-list>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════ NOTES ═══════ -->
    <v-row v-if="session.notes" dense class="mt-2">
      <v-col cols="12">
        <v-card class="hc-panel pa-5" rounded="xl" elevation="0">
          <div class="d-flex align-center ga-3 mb-3">
            <div class="hc-panel-icon" style="background:linear-gradient(135deg,#64748b,#475569);">
              <v-icon icon="mdi-note-text" size="18" />
            </div>
            <div>
              <h3 class="text-subtitle-1 font-weight-bold ma-0">Notes</h3>
            </div>
          </div>
          <p class="text-body-2">{{ session.notes }}</p>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="4000">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import {
  BRADEN_SUBSCALES, CAPRINI_FACTORS, RISK_META,
  bradenRiskLabel, capriniRiskLabel, morseRiskLabel, mustRiskLabel, painCategory,
  generateAlerts,
} from '~/composables/useAssessmentScoring'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()

const session = ref({})
const loading = ref(true)
const snack = reactive({ show: false, color: 'success', text: '' })
const showMoreInit = ref(false)

// Derive sub-objects
const ini = computed(() => session.value.initial_survey || {})
const h2t = computed(() => session.value.head_to_toe || {})

const alerts = computed(() => {
  const s = session.value
  return generateAlerts({
    braden_total: s.braden_total, caprini_points: s.caprini_points,
    morse_score: s.morse_score, must_score: s.must_score,
    cam_positive: s.cam_positive, pain_score: s.pain_score,
    braden: s.braden, vte_caprini: s.vte_caprini, falls: s.falls, must: s.must,
    catheter_bundle: s.catheter_bundle || {},
    central_line_bundle: s.central_line_bundle || {},
  })
})

const riskColor = computed(() => RISK_META[session.value.overall_risk_level || '']?.color || 'grey')
const bgByRisk = computed(() => RISK_META[session.value.overall_risk_level || '']?.hex || '#64748b')

const bradenColor = computed(() => {
  const t = session.value.braden_total
  if (t == null) return 'grey'
  if (t <= 12) return 'error'
  if (t <= 18) return 'warning'
  return 'success'
})
const capriniColor = computed(() => {
  const p = session.value.caprini_points
  if (p == null) return 'grey'
  if (p >= 5) return 'error'
  if (p >= 3) return 'warning'
  return 'success'
})
const morseColor = computed(() => {
  const s = session.value.morse_score
  if (s == null) return 'grey'
  if (s >= 45) return 'error'
  if (s >= 25) return 'warning'
  return 'success'
})
const mustColor = computed(() => {
  const t = session.value.must_score
  if (t == null) return 'grey'
  if (t >= 2) return 'error'
  if (t === 1) return 'warning'
  return 'success'
})

function painClass(s) {
  if (s == null) return ''
  if (s >= 7) return 'text-error'
  if (s >= 4) return 'text-warning'
  return 'text-success'
}
function painChipColor(s) {
  if (s == null) return 'grey'
  if (s >= 7) return 'error'
  if (s >= 4) return 'warning'
  return 'success'
}

const riskCards = computed(() => [
  { code: 'BRADEN', label: 'Braden (pressure)', icon: 'mdi-human', score: session.value.braden_total, unit: '/23', riskLabel: session.value.braden?.risk_level || '', bg: 'rgba(13,148,136,0.08)', color: '#0d9488', alertIcon: '' },
  { code: 'CAPRINI', label: 'Caprini (VTE)', icon: 'mdi-blood-bag', score: session.value.caprini_points, unit: 'pts', riskLabel: session.value.vte_caprini?.risk_level || '', bg: 'rgba(124,58,237,0.08)', color: '#7c3aed', alertIcon: '' },
  { code: 'MORSE', label: 'Morse (falls)', icon: 'mdi-fall', score: session.value.morse_score, unit: '/125', riskLabel: session.value.falls?.risk_level || '', bg: 'rgba(245,158,11,0.08)', color: '#d97706', alertIcon: '' },
  { code: 'MUST', label: 'MUST (nutrition)', icon: 'mdi-food-apple', score: session.value.must_score, unit: '/6', riskLabel: session.value.must?.risk_level || '', bg: 'rgba(239,68,68,0.08)', color: '#ef4444', alertIcon: '' },
  { code: 'CAM', label: 'CAM (delirium)', icon: 'mdi-brain', score: session.value.cam_positive ? 'Pos' : 'Neg', unit: '', riskLabel: session.value.cam_positive ? 'Delirium' : 'Normal', bg: 'rgba(168,85,247,0.08)', color: '#a855f7', alertIcon: '' },
  { code: 'PAIN', label: 'Pain (NRS)', icon: 'mdi-alert', score: session.value.pain_score ?? '—', unit: '/10', riskLabel: session.value.pain_score != null ? painCategory(session.value.pain_score) : '', bg: 'rgba(239,68,68,0.08)', color: '#ef4444', alertIcon: '' },
])

function fmtBool(v) { return v ? 'Yes' : 'No' }
function formatFull(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString([], { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get(`/homecare/assessment-sessions/${route.params.id}/`)
    session.value = data
  } catch {
    snack.text = 'Could not load assessment'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-hero {
  position: relative; border-radius: 24px; overflow: hidden;
  background: white; border: 1px solid rgba(15,23,42,0.06);
  box-shadow: 0 1px 3px rgba(15,23,42,0.04);
}
.hc-hero-inner { position: relative; z-index: 2; }
.hc-hero-icon {
  background: rgba(13,148,136,0.12) !important;
  border: 1px solid rgba(13,148,136,0.22);
}
.hc-hero-icon .v-icon { color: #0d9488 !important; }
.hc-panel {
  background: white; border: 1px solid rgba(15,23,42,0.06);
  height: 100%;
}
.hc-panel-icon {
  width: 36px; height: 36px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  color: white; flex-shrink: 0;
}
.hc-risk-row {
  background: rgba(15,23,42,0.02);
  transition: background 0.15s ease;
}
.hc-risk-row:hover { background: rgba(13,148,136,0.04); }
.hc-expand :deep(.v-expansion-panel) { margin-bottom: 4px; }
:global(.v-theme--dark .hc-hero) { background: #1e293b; border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .hc-panel) { background: rgb(30,41,59); border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .hc-risk-row) { background: rgba(255,255,255,0.02); }
:global(.v-theme--dark .hc-risk-row:hover) { background: rgba(13,148,136,0.10); }
</style>
