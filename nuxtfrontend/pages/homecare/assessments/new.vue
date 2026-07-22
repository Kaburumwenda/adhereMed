<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- ═══ PREMIUM HERO ═══ -->
    <div class="hc-new-hero pa-6 pa-md-7 mb-5">
      <div class="hc-new-hero-content">
        <div class="d-flex align-center flex-wrap ga-4">
          <div class="flex-grow-1">
            <v-btn variant="text" class="text-none mb-2 px-2" color="rgba(255,255,255,0.8)" prepend-icon="mdi-arrow-left" to="/homecare/assessments">
              Back to assessments
            </v-btn>
            <h1 class="text-h4 text-md-h3 font-weight-bold text-white ma-0">New Assessment</h1>
            <p class="text-body-1 mt-1" style="color:rgba(255,255,255,0.8)">
              Comprehensive nursing assessment per WHO/CDC guidelines — structured survey, validated risk scales, evidence-based bundles
            </p>
          </div>
          <div class="d-flex ga-3 align-center">
            <v-chip variant="flat" class="text-white font-weight-bold" :color="stepColor" size="small">
              Step {{ step }} / {{ maxStep }}
            </v-chip>
            <span class="text-caption text-white" style="opacity:.7">{{ stepLabel }}</span>
          </div>
        </div>
      </div>
      <div class="hc-new-hero-glow" />
      <div class="hc-new-hero-pattern" />
    </div>

    <!-- ═══ STEPPER PROGRESS ═══ -->
    <v-card rounded="xl" elevation="0" class="hc-new-progress pa-4 mb-4">
      <div class="d-flex ga-2 flex-wrap">
        <v-chip
          v-for="(s, i) in steps" :key="s.key"
          :color="i < step ? 'teal' : i === step - 1 ? 'teal' : 'grey'"
          :variant="i <= step - 1 ? 'flat' : 'tonal'"
          size="small" class="text-none font-weight-medium"
          @click="step = i + 1"
        >
          <v-icon start :icon="s.icon" size="14" />
          {{ s.label }}
        </v-chip>
      </div>
    </v-card>

    <!-- ═══ FORM BODY ═══ -->
    <v-card rounded="xl" elevation="0" class="hc-new-panel pa-5 pa-md-6">
      <v-fade-transition mode="out-in">
        <!-- ════ STEP 1: Patient + Arrival + Vitals ════ -->
        <div v-if="step === 1" key="s1">
          <SectionHead title="Patient & Arrival" subtitle="Identify patient and record arrival details" icon="mdi-account-check" color="#0d9488" />
          <v-row dense>
            <v-col cols="12" md="6">
              <v-autocomplete v-model="form.patient" :items="patientOptions" label="Patient"
                              item-title="label" item-value="id" variant="outlined" rounded="lg"
                              density="comfortable" prepend-inner-icon="mdi-account"
                              hide-details class="mb-3 hc-field" required />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.arrival.arrival_mode" :items="ARRIVAL_MODES" label="Mode of arrival"
                        variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.session_type" :items="sessionTypes" label="Session type"
                        variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" />
            </v-col>
          </v-row>

          <SectionHead title="Vital Signs" subtitle="Core measurements with NEWS2 clinical pathway" icon="mdi-heart-pulse" color="#0284c7" class="mt-4" />
          <v-row>
            <v-col cols="12" md="7">
              <v-row dense>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.respiratory_rate" type="number" label="Respiratory rate (/min)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                :hint="`Score: ${news2Computed.rr}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.spo2" type="number" label="SpO₂ (%)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                :hint="`Score: ${news2Computed.spo2}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="12">
                  <v-switch v-model="ini.scale2" color="teal" hide-details density="compact"
                            label="SpO₂ Scale 2 (hypercapnic / COPD target 88–92%)" class="mb-3" />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="ini.oxygen" :items="['Room air', 'Supplemental O₂']" label="Oxygen"
                            variant="outlined" rounded="lg" density="comfortable" hide-details
                            :hint="`Score: ${news2Computed.oxygen}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col v-if="ini.oxygen === 'Supplemental O₂'" cols="6">
                  <v-select v-model="ini.oxygen_delivery" :items="OXYGEN_DELIVERY_MODES"
                            label="Mode of delivery" variant="outlined" rounded="lg" density="comfortable"
                            hide-details hint="Route the supplemental oxygen is given" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="ini.consciousness"
                            :items="['Alert', 'Verbal', 'Pain', 'Unresponsive']"
                            label="ACVPU consciousness" variant="outlined" rounded="lg" density="comfortable" hide-details
                            :hint="`Score: ${news2Computed.consciousness}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-select v-model="useGcs" :items="[{title:'ACVPU (default)',value:false},{title:'GCS (Glasgow Coma Scale)',value:true}]"
                            item-title="title" item-value="value" label="Consciousness scale"
                            variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
                </v-col>
                <!-- GCS sub-fields -->
                <template v-if="useGcs">
                  <v-col cols="4">
                    <v-select v-model="ini.gcs_eye" :items="GCS_EYE" item-title="label" item-value="value"
                              label="GCS — Eye" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
                  </v-col>
                  <v-col cols="4">
                    <v-select v-model="ini.gcs_verbal" :items="GCS_VERBAL" item-title="label" item-value="value"
                              label="GCS — Verbal" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
                  </v-col>
                  <v-col cols="4">
                    <v-select v-model="ini.gcs_motor" :items="GCS_MOTOR" item-title="label" item-value="value"
                              label="GCS — Motor" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
                  </v-col>
                  <v-col cols="12" v-if="gcsPreview.total != null">
                    <v-chip color="purple" variant="tonal" class="font-weight-bold">
                      GCS {{ gcsPreview.total }}/15 — {{ gcsPreview.category }}
                    </v-chip>
                  </v-col>
                </template>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.systolic_bp" type="number" label="Systolic BP (mmHg)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                :hint="`Score: ${news2Computed.sbp}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.diastolic_bp" type="number" label="Diastolic BP (mmHg)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                hint="Recorded (not scored)" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.heart_rate" type="number" label="Heart rate (bpm)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                :hint="`Score: ${news2Computed.hr}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.temperature" type="number" label="Temperature (°C)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                :hint="`Score: ${news2Computed.temp}`" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.glucose" type="number" label="Glucose (mmol/L)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                hint="Optional" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.weight" type="number" label="Weight (kg)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details
                                hint="Optional" persistent-hint class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="ini.pain_score" type="number" min="0" max="10" label="Pain (0–10)"
                                variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model="ini.last_pain_meds" type="datetime-local" label="Last analgesia given"
                                variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
                </v-col>
              </v-row>
            </v-col>

            <!-- NEWS2 Premium Panel -->
            <v-col cols="12" md="5">
              <div class="news2-panel" :style="{ background: `linear-gradient(135deg, ${news2Computed.risk.hex}22, ${news2Computed.risk.hex}0d)`, borderColor: `${news2Computed.risk.hex}55` }">
                <div class="d-flex align-center justify-space-between mb-2">
                  <div class="text-caption text-uppercase font-weight-bold" :style="{ color: news2Computed.risk.hex }">Aggregate NEWS2</div>
                  <v-chip v-if="news2Computed.willEscalate" size="x-small" color="error" variant="tonal" class="font-weight-bold">
                    <v-icon start icon="mdi-alert-octagram" size="12" />Escalate
                  </v-chip>
                </div>
                <div class="news2-total" :style="{ color: news2Computed.risk.hex }">{{ news2Computed.total }}</div>
                <v-chip :color="news2Computed.risk.color" variant="flat" class="font-weight-bold mb-2">{{ news2Computed.risk.label }} risk</v-chip>

                <!-- Clinical pathway -->
                <v-alert :type="news2Computed.total >= 5 ? 'warning' : 'success'" variant="tonal" density="compact"
                         icon="mdi-hospital-box" class="text-caption mb-3">
                  <div class="text-caption font-weight-medium">{{ news2Computed.clinicalPathway }}</div>
                </v-alert>

                <v-divider class="mb-2" />
                <div class="text-caption font-weight-bold mb-2">Breakdown</div>
                <div v-for="b in news2Computed.breakdown" :key="b.key" class="news2-row">
                  <v-icon size="16" class="me-2" :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'grey')">{{ b.icon }}</v-icon>
                  <span class="text-caption flex-grow-1">{{ b.label }}</span>
                  <span class="text-caption text-medium-emphasis me-2">{{ b.value }}</span>
                  <v-chip size="x-small" variant="tonal"
                          :color="b.score >= 3 ? 'error' : (b.score > 0 ? 'warning' : 'success')">{{ b.score }}</v-chip>
                </div>
              </div>
            </v-col>
          </v-row>

          <SectionHead title="Primary Survey" subtitle="Initial checks and safety questions per WHO/CDC" icon="mdi-shield-check" color="#7c3aed" class="mt-4" />
          <v-row dense>
            <v-col cols="12"><v-textarea v-model="ini.chief_concern" label="Chief concern / reason for visit" variant="outlined" rounded="lg" density="comfortable" hide-details rows="2" class="mb-3 hc-field" /></v-col>
            <v-col cols="12"><v-textarea v-model="ini.general_appearance" label="General appearance" variant="outlined" rounded="lg" density="comfortable" hide-details rows="1" class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3">
              <v-select v-model="ini.skin_integrity" :items="SKIN_INTEGRITY" label="Skin integrity" variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="ini.skin_moisture" :items="SKIN_MOISTURE" label="Skin moisture" variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" />
            </v-col>
            <v-col cols="6" md="2"><v-text-field v-model="ini.recent_falls" type="number" min="0" label="Falls (12 mo)" variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="4" class="d-flex align-center ga-2 flex-wrap mb-3">
              <v-checkbox v-model="ini.has_catheter" label="Catheter" density="compact" hide-details />
              <v-checkbox v-model="ini.has_central_line" label="Central line" density="compact" hide-details />
              <v-checkbox v-model="ini.has_ventilator" label="Ventilator" density="compact" hide-details />
              <v-checkbox v-model="ini.has_wound" label="Wound" density="compact" hide-details />
            </v-col>
            <v-col cols="6"><v-text-field v-model="ini.allergies" label="Allergies" variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6"><v-text-field v-model="ini.current_meds" label="Current medications" variant="outlined" rounded="lg" density="comfortable" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>
        </div>

        <!-- ════ STEP 2: Head-to-Toe ════ -->
        <div v-if="step === 2" key="s2">
          <SectionHead title="Neuro & General" subtitle="Neurological status, orientation, mobility" icon="mdi-brain" color="#7c3aed" />
          <v-row dense>
            <v-col cols="4"><v-checkbox v-model="h2t.oriented_time" label="Oriented to time" density="compact" hide-details /></v-col>
            <v-col cols="4"><v-checkbox v-model="h2t.oriented_place" label="Oriented to place" density="compact" hide-details /></v-col>
            <v-col cols="4"><v-checkbox v-model="h2t.oriented_person" label="Oriented to person" density="compact" hide-details /></v-col>
            <v-col cols="4"><v-checkbox v-model="h2t.pupil_reactive" label="Pupils reactive" density="compact" hide-details /></v-col>
            <v-col cols="4"><v-select v-model="h2t.mobility_level" :items="MOBILITY_LEVEL" label="Mobility" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="4"><v-text-field v-model="h2t.speech" label="Speech issues" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Eyes / ENT / Oral" subtitle="Vision, hearing, oral health" icon="mdi-eye" color="#0284c7" class="mt-3" />
          <v-row dense>
            <v-col cols="12" md="4"><v-text-field v-model="h2t.vision_problems" label="Vision" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="h2t.hearing_problems" label="Hearing" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="h2t.oral_status" label="Oral health" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Cardiovascular" subtitle="Heart rhythm, peripheral perfusion" icon="mdi-heart" color="#dc2626" class="mt-3" />
          <v-row dense>
            <v-col cols="6" md="4"><v-select v-model="h2t.heart_rhythm" :items="HEART_RHYTHM" label="Heart rhythm" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="4"><v-select v-model="h2t.peripheral_pulses" :items="PERIPHERAL_PULSES" label="Peripheral pulses" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Respiratory" subtitle="Breath sounds, effort, oxygen therapy" icon="mdi-lungs" color="#0d9488" class="mt-3" />
          <v-row dense>
            <v-col cols="6" md="4"><v-select v-model="h2t.breath_sounds" :items="BREATH_SOUNDS" label="Breath sounds" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="h2t.resp_effort" :items="RESP_EFFORT" label="Resp. effort" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="2" class="d-flex align-center">
              <v-checkbox v-model="h2t.on_oxygen" label="On oxygen" density="compact" hide-details />
            </v-col>
            <v-col v-if="h2t.on_oxygen" cols="6" md="3"><v-text-field v-model="h2t.oxygen_flow_lpm" type="number" label="O₂ flow (LPM)" variant="outlined" rounded="lg" density="compact" hide-details hint="Validate ≤ 15 LPM" persistent-hint class="mb-3 hc-field" /></v-col>
            <v-col v-if="h2t.on_oxygen" cols="6" md="4"><v-select v-model="h2t.oxygen_mode" :items="OXYGEN_MODE" label="O₂ mode" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Abdomen / GI" subtitle="Abdominal assessment, bowel function" icon="mdi-food" color="#d97706" class="mt-3" />
          <v-row dense>
            <v-col cols="6" md="4"><v-select v-model="h2t.abdomen_shape" :items="ABDOMEN_SHAPE" label="Abdomen shape" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="4"><v-select v-model="h2t.bowel_sounds" :items="BOWEL_SOUNDS" label="Bowel sounds" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Musculoskeletal" subtitle="Joint status, functional assessment" icon="mdi-account-tie" color="#a855f7" class="mt-3" />
          <v-row dense>
            <v-col cols="12"><v-text-field v-model="h2t.joint_deformities" label="Joint / musculoskeletal issues" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>

          <SectionHead title="Continence & Nutrition" subtitle="Bladder, bowel control, feeding ability" icon="mdi-human" color="#0d9488" class="mt-3" />
          <v-row dense>
            <v-col cols="6" md="3"><v-select v-model="h2t.urinary_continence" :items="CONTINENCE" label="Urinary continence" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="h2t.bowel_continence" :items="CONTINENCE" label="Bowel continence" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="h2t.nutrition_assist" :items="NUTRITION_ASSIST" label="Nutrition assist" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="2" class="d-flex align-center">
              <v-checkbox v-model="h2t.dysphagia" label="Dysphagia" density="compact" hide-details />
            </v-col>
          </v-row>

          <SectionHead title="Skin / Wounds" subtitle="Full skin check — pressure points, wounds" icon="mdi-bandage" color="#ef4444" class="mt-3" />
          <v-row dense>
            <v-col cols="12" md="6" class="d-flex align-center ga-2">
              <v-checkbox v-model="h2t.any_wounds" label="Has wounds / pressure injuries" density="compact" hide-details />
            </v-col>
            <v-col v-if="h2t.any_wounds" cols="12">
              <v-textarea v-model="h2t.wound_descriptions_raw" label="Wound descriptions (location, size, type — one per line)" variant="outlined" rounded="lg" density="compact" hide-details rows="2" class="mb-3 hc-field" />
            </v-col>
          </v-row>
        </div>

        <!-- ════ STEP 3: Risk Scales ════ -->
        <div v-if="step === 3" key="s3">
          <SectionHead title="Braden Scale" subtitle="Pressure ulcer risk (NPIAP)" icon="mdi-human" color="#0d9488" />
          <v-row dense>
            <v-col v-for="s in BRADEN_SUBSCALES" :key="s.key" cols="12" md="4">
              <v-select v-model="form.braden[s.key]" :items="BRADEN_OPTIONS[s.key]" item-title="label" item-value="value"
                        :label="s.label" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" />
            </v-col>
          </v-row>
          <v-alert v-if="bradenPreview.total != null" :type="bradenPreview.total <= 12 ? 'error' : bradenPreview.total <= 18 ? 'warning' : 'success'" variant="tonal" rounded="lg" density="compact" class="mb-3">
            <div class="d-flex align-center ga-2">
              <strong>Braden total: {{ bradenPreview.total }}/23</strong> — {{ bradenPreview.risk_level }}
              <v-spacer />
              <span class="text-caption">{{ bradenPreview.total <= 18 ? '🛡️ NPIAP: Implement pressure-relief measures' : '✅ No action required' }}</span>
            </div>
          </v-alert>

          <SectionHead title="Caprini Score" subtitle="VTE risk assessment (StatPearls)" icon="mdi-blood-bag" color="#7c3aed" class="mt-4" />
          <v-row dense>
            <v-col cols="12" md="3"><v-text-field v-model="form.vte_caprini.age" type="number" label="Age" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="12" md="9">
              <div class="d-flex flex-wrap ga-2 mb-3">
                <v-chip v-for="f in CAPRINI_FACTORS" :key="f.key"
                  :color="form.vte_caprini.factors[f.key] ? 'purple-darken-2' : undefined"
                  :variant="form.vte_caprini.factors[f.key] ? 'flat' : 'tonal'"
                  size="small" class="text-none" @click="toggleCaprini(f.key)">
                  <v-icon v-if="form.vte_caprini.factors[f.key]" start icon="mdi-check" size="12" />
                  {{ f.label }} ({{ f.points }}pt)
                </v-chip>
              </div>
            </v-col>
          </v-row>
          <v-alert v-if="capriniPreview.points > 0" :type="capriniPreview.points >= 5 ? 'error' : capriniPreview.points >= 3 ? 'warning' : 'success'" variant="tonal" rounded="lg" density="compact" class="mb-3">
            <strong>Caprini: {{ capriniPreview.points }} pts</strong> — {{ capriniPreview.risk_level }}
            <span v-if="capriniPreview.points >= 3" class="ml-2 text-caption">⚕️ Consider prophylaxis</span>
          </v-alert>

          <SectionHead title="Morse Fall Scale" subtitle="Falls risk (CDC/STEADI)" icon="mdi-fall" color="#d97706" class="mt-4" />
          <v-row dense>
            <v-col cols="6" md="2" class="d-flex align-center"><v-checkbox v-model="form.falls.history_of_falls" label="Fall history" density="compact" hide-details /></v-col>
            <v-col cols="6" md="2" class="d-flex align-center"><v-checkbox v-model="form.falls.secondary_dx" label="Secondary diagnosis" density="compact" hide-details /></v-col>
            <v-col cols="6" md="2" class="d-flex align-center"><v-checkbox v-model="form.falls.iv_lock" label="IV / heparin lock" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3"><v-select v-model="form.falls.ambulatory_aid" :items="MORSE_AMBULATORY_AID" item-title="label" item-value="value" label="Ambulatory aid" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="form.falls.gait" :items="MORSE_GAIT" item-title="label" item-value="value" label="Gait" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="form.falls.mental_status" :items="MORSE_MENTAL" item-title="label" item-value="value" label="Mental status" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>
          <v-alert v-if="morsePreview.score > 0" :type="morsePreview.score >= 45 ? 'error' : morsePreview.score >= 25 ? 'warning' : 'success'" variant="tonal" rounded="lg" density="compact" class="mb-3">
            <strong>Morse: {{ morsePreview.score }}/125</strong> — {{ morsePreview.risk_level }}
          </v-alert>

          <SectionHead title="MUST" subtitle="Malnutrition risk (BAPEN)" icon="mdi-food-apple" color="#ef4444" class="mt-4" />
          <v-row dense>
            <v-col cols="6" md="3"><v-text-field v-model="form.must.height_cm" type="number" label="Height (cm)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="form.must.weight_kg" type="number" label="Weight (kg)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="form.must.weight_loss_percent" type="number" label="Weight loss %" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.must.acute_no_nutrition" label="Acute illness / no intake >5d" density="compact" hide-details /></v-col>
          </v-row>
          <v-alert v-if="mustPreview.total_score != null" :type="mustPreview.total_score >= 2 ? 'error' : mustPreview.total_score === 1 ? 'warning' : 'success'" variant="tonal" rounded="lg" density="compact" class="mb-3">
            <strong>MUST: {{ mustPreview.total_score }}/6</strong> — {{ mustPreview.risk_level }}
            <span v-if="mustPreview.bmi != null" class="ml-2 text-caption">BMI: {{ mustPreview.bmi }}</span>
          </v-alert>

          <SectionHead title="CAM — Delirium Screen" subtitle="Confusion Assessment Method" icon="mdi-brain" color="#a855f7" class="mt-4" />
          <v-row dense>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.cam.acute_onset" label="Acute onset" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.cam.fluctuating" label="Fluctuating course" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.cam.inattention" label="Inattention" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.cam.disorganized_thinking" label="Disorganised thinking" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="form.cam.altered_consciousness" label="Altered consciousness" density="compact" hide-details /></v-col>
          </v-row>
          <v-alert v-if="camPreview.cam_positive" type="error" variant="tonal" rounded="lg" density="compact" icon="mdi-alert-octagon" class="mb-3">
            <strong>CAM Positive</strong> — Delirium detected. Physician review required.
          </v-alert>
        </div>

        <!-- ════ STEP 4: Device & Care Bundles ════ -->
        <div v-if="step === 4" key="s4">
          <SectionHead title="Device & Care Bundles" subtitle="Evidence-based bundles per CDC/IHI/NPIAP guidelines" icon="mdi-medical-bag" color="#0d9488" />

          <v-expansion-panels v-model="bundlePanels" multiple class="hc-expand">
            <!-- Catheter -->
            <v-expansion-panel v-if="ini.has_catheter" value="catheter" rounded="xl">
              <v-expansion-panel-title class="font-weight-bold">
                <v-icon icon="mdi-water-pipe" class="mr-2" color="info" />
                Catheter Bundle (CAUTI Prevention) — CDC
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-row dense>
                  <v-col cols="4"><v-select v-model="catheter.type" :items="CATHETER_TYPE" label="Type" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="4"><v-text-field v-model="catheter.insert_date" type="date" label="Insertion date" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="4"><v-text-field v-model="catheter.next_review_date" type="date" label="Next review" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="12"><v-textarea v-model="catheter.indication" label="Indication (required — CDC: restrict use)" variant="outlined" rounded="lg" density="compact" hide-details rows="1" class="mb-3 hc-field" /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="catheter.closed_system_maintained" label="Closed system maintained" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="catheter.bag_below_bladder" label="Bag below bladder" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="catheter.needs_review" label="May no longer be needed" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="catheter.daily_care_performed" label="Daily care performed" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="catheter.bag_emptied" label="Bag emptied this shift" density="compact" hide-details /></v-col>
                  <v-col cols="4"><v-text-field v-model="catheter.last_bag_change" type="date" label="Last bag change" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                </v-row>
                <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mt-2">
                  <div class="text-caption"><strong>CDC CAUTI Prevention:</strong> Closed drainage mandatory, bag below bladder, remove when no longer indicated. No routine change unless clinically indicated. Daily review recommended.</div>
                </v-alert>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Central line -->
            <v-expansion-panel v-if="ini.has_central_line" value="cl" rounded="xl">
              <v-expansion-panel-title class="font-weight-bold">
                <v-icon icon="mdi-needle" class="mr-2" color="purple" />
                Central Line Bundle (CLABSI Prevention) — CDC
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-row dense>
                  <v-col cols="4"><v-select v-model="cl.type" :items="LINE_TYPE" label="Type" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="4"><v-text-field v-model="cl.insert_date" type="date" label="Insertion date" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="4"><v-text-field v-model="cl.insert_site" label="Insertion site" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="cl.maximal_barrier" label="Maximal barrier used" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="cl.hub_scrub" label="Hub scrub protocol" density="compact" hide-details /></v-col>
                  <v-col cols="4" class="d-flex align-center"><v-checkbox v-model="cl.needs_removal" label="May no longer be needed" density="compact" hide-details /></v-col>
                  <v-col cols="6"><v-text-field v-model="cl.last_accessed_by" label="Last accessed by" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="6"><v-text-field v-model="cl.last_access_date" type="datetime-local" label="Last access date" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                </v-row>
                <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mt-2">
                  <div class="text-caption"><strong>CDC CLABSI Prevention:</strong> Hand hygiene, maximal barriers, chlorhexidine skin prep, avoid femoral site, remove promptly. Change dressings q7d or sooner if soiled. Scrub hub with antiseptic on each access.</div>
                </v-alert>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Ventilator -->
            <v-expansion-panel v-if="ini.has_ventilator" value="vent" rounded="xl">
              <v-expansion-panel-title class="font-weight-bold">
                <v-icon icon="mdi-ventilator" class="mr-2" color="error" />
                Ventilator Bundle (VAP Prevention) — IHI
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-row dense>
                  <v-col cols="6" class="d-flex align-center"><v-checkbox v-model="vent.head_of_bed_elevated" label="Head of bed ≥30°" density="compact" hide-details /></v-col>
                  <v-col cols="6" class="d-flex align-center"><v-checkbox v-model="vent.daily_sbt" label="Daily SBT" density="compact" hide-details /></v-col>
                  <v-col cols="6" class="d-flex align-center"><v-checkbox v-model="vent.sedation_vacation" label="Sedation vacation" density="compact" hide-details /></v-col>
                  <v-col cols="6" class="d-flex align-center"><v-checkbox v-model="vent.oral_care" label="Oral care performed" density="compact" hide-details /></v-col>
                  <v-col cols="12"><v-text-field v-model="vent.vent_settings" label="Ventilator settings" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                </v-row>
                <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mt-2">
                  <div class="text-caption"><strong>IHI VAP Bundle:</strong> Elevate HOB, daily sedation interruption, oral care with chlorhexidine, DVT prophylaxis, peptic ulcer prophylaxis.</div>
                </v-alert>
              </v-expansion-panel-text>
            </v-expansion-panel>

            <!-- Wound -->
            <v-expansion-panel v-if="ini.has_wound || h2t.any_wounds" value="wound" rounded="xl">
              <v-expansion-panel-title class="font-weight-bold">
                <v-icon icon="mdi-bandage" class="mr-2" color="orange" />
                Wound / Pressure Injury Bundle — NPIAP
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-row dense>
                  <v-col cols="6" md="3"><v-text-field v-model="wound.turn_schedule_hours" type="number" label="Turn schedule (hours)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
                  <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="wound.special_mattress" label="Special mattress" density="compact" hide-details /></v-col>
                  <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="wound.barrier_cream" label="Barrier cream" density="compact" hide-details /></v-col>
                  <v-col cols="12"><v-textarea v-model="wound.wound_details_raw" label="Wound details (location, stage, size)" variant="outlined" rounded="lg" density="compact" hide-details rows="2" class="mb-3 hc-field" /></v-col>
                </v-row>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
        </div>

        <!-- ════ STEP 5: Disease-Specific Bundles ════ -->
        <div v-if="step === 5" key="s5">
          <SectionHead title="Diabetes Bundle" subtitle="Foot checks, glucose monitoring" icon="mdi-water" color="#0284c7" />
          <v-row dense>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.diabetes.foot_ulcer" label="Foot ulcer detected" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.diabetes.neuropathy" label="Neuropathy" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.diabetes.insulin_pump" label="Insulin pump" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="db.diabetes.latest_bg" type="number" label="Latest blood glucose (mg/dL)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model.number="db.diabetes.latest_bg_mmol" type="number" step="0.1" label="Latest BG (mmol/L)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-text-field v-model="db.diabetes.last_foot_check" type="date" label="Last foot inspection date" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
          </v-row>
          <v-alert v-if="db.diabetes.foot_ulcer" type="warning" variant="tonal" rounded="lg" density="compact" icon="mdi-foot-print" class="mb-3">
            <strong>Foot ulcer present</strong> — Initiate wound care, offload pressure, optimise blood glucose, refer to podiatry.
          </v-alert>
          <v-alert v-if="db.diabetes.latest_bg != null && db.diabetes.latest_bg > 180" type="info" variant="tonal" rounded="lg" density="compact" class="mb-3">
            <span class="text-caption">Elevated blood glucose ({{ db.diabetes.latest_bg }} mg/dL). Consider insulin adjustment per physician order.</span>
          </v-alert>

          <SectionHead title="Heart Failure Bundle" subtitle="Volume status assessment, daily monitoring" icon="mdi-heart" color="#dc2626" class="mt-4" />
          <v-row dense>
            <v-col cols="6" md="3"><v-text-field v-model.number="db.heart_failure.daily_weight" type="number" step="0.1" label="Daily weight (kg)" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3"><v-select v-model="db.heart_failure.edema" :items="EDEMA_LEVELS" label="Edema level" variant="outlined" rounded="lg" density="compact" hide-details class="mb-3 hc-field" /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.heart_failure.sob_at_rest" label="SOB at rest" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.heart_failure.sob_on_exertion" label="SOB on exertion" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.heart_failure.orthopnea" label="Orthopnea" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.heart_failure.jvd" label="JVD" density="compact" hide-details /></v-col>
            <v-col cols="6" md="3" class="d-flex align-center"><v-checkbox v-model="db.heart_failure.lung_crackles" label="Lung crackles" density="compact" hide-details /></v-col>
          </v-row>
          <v-alert v-if="db.heart_failure.sob_at_rest || db.heart_failure.orthopnea" type="warning" variant="tonal" rounded="lg" density="compact" icon="mdi-alert" class="mb-3">
            <strong>Heart failure decompensation signs</strong> — Assess volume status, check daily weight trend, notify physician re: diuretic adjustment.
          </v-alert>

          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis text-center">
            Disease-specific bundles follow WHO and international society guidelines for condition-specific monitoring.
          </div>
        </div>

        <!-- ════ STEP 6: Review & Submit ════ -->
        <div v-if="step === 6" key="s6">
          <SectionHead title="Review & Submit" subtitle="Verify all data before signing" icon="mdi-file-check" color="#10b981" />

          <v-row dense>
            <v-col cols="12" md="6">
              <v-card variant="tonal" rounded="xl" class="pa-4 mb-3">
                <div class="text-overline font-weight-bold text-teal mb-2">Patient</div>
                <div class="text-body-2 font-weight-medium">{{ patientName || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ sessionTypeLabel }} · {{ form.arrival.arrival_mode }}</div>
              </v-card>
            </v-col>
            <v-col cols="12" md="6">
              <v-card variant="tonal" rounded="xl" class="pa-4 mb-3" :style="{ background: riskBg }">
                <div class="text-overline font-weight-bold mb-1" style="opacity:.85">Computed Risk Level</div>
                <div class="d-flex align-center ga-2">
                  <v-icon :icon="riskIcon" :color="riskTextColor" size="28" />
                  <span class="text-h5 font-weight-bold" :class="'text-'+riskTextColor">{{ overallRiskLabel }}</span>
                </div>
              </v-card>
            </v-col>
          </v-row>

          <v-card variant="tonal" rounded="xl" class="pa-4 mb-3">
            <div class="text-overline font-weight-bold text-purple mb-2">All Scores</div>
            <v-row dense>
              <v-col v-for="s in summaryScores" :key="s.label" cols="6" md="3">
                <div class="d-flex align-center ga-2 pa-2 rounded-lg mb-1" :style="{ background: s.bg }">
                  <span class="text-caption font-weight-medium">{{ s.label }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-bold" :class="'text-'+s.color">{{ s.value }}</span>
                  <span class="text-caption text-medium-emphasis">{{ s.unit }}</span>
                </div>
              </v-col>
            </v-row>
          </v-card>

          <!-- Alerts preview -->
          <v-card v-if="alertsPreview.length" variant="tonal" rounded="xl" class="pa-4 mb-3">
            <div class="d-flex align-center ga-2 mb-2">
              <v-icon icon="mdi-bell-alert" color="error" size="20" />
              <span class="text-overline font-weight-bold">Triggers & Alerts ({{ alertsPreview.length }})</span>
            </div>
            <v-alert v-for="(a, i) in alertsPreview" :key="i" :type="a.severity === 'critical' ? 'error' : a.severity === 'high' ? 'warning' : 'info'" variant="tonal" rounded="lg" density="compact" class="mb-1">
              <div class="text-caption"><strong>{{ a.title }}</strong> — {{ a.detail }}</div>
            </v-alert>
          </v-card>

          <v-divider class="mb-4" />
          <div class="d-flex align-center ga-2 mb-4">
            <v-icon icon="mdi-key" size="18" color="teal" />
            <span class="text-caption font-weight-medium">Staff verification required to sign this assessment</span>
          </div>
          <v-text-field v-model="signPin" label="Your staff PIN" type="password" inputmode="numeric" maxlength="12"
                        density="comfortable" variant="outlined" rounded="lg" prepend-inner-icon="mdi-key"
                        @keyup.enter="submit" hide-details class="mb-3 hc-field" style="max-width:300px" />

          <v-textarea v-model="form.notes" label="Additional clinical notes (optional)" variant="outlined" rounded="lg" density="compact" hide-details rows="2" class="mb-3 hc-field" />
        </div>
      </v-fade-transition>

      <!-- ═══ NAVIGATION ═══ -->
      <v-divider class="my-4" />
      <div class="d-flex align-center ga-3 flex-wrap">
        <v-btn v-if="step > 1" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-chevron-left"
               @click="step--">Previous</v-btn>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ stepLabel }}</span>
        <v-btn v-if="step < maxStep" variant="flat" color="teal" rounded="lg" class="text-none text-white font-weight-bold"
               append-icon="mdi-chevron-right" @click="step++">Next</v-btn>
        <v-btn v-else variant="flat" color="success" rounded="lg" class="text-none font-weight-bold"
               prepend-icon="mdi-content-save" :loading="saving" @click="submit">
          {{ saving ? 'Saving…' : 'Save Assessment' }}
        </v-btn>
      </div>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="4000" rounded="xl">
      <v-icon :icon="snack.icon" class="mr-2" />{{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import {
  ARRIVAL_MODES, AVPU, SKIN_INTEGRITY, SKIN_MOISTURE, MOBILITY_LEVEL,
  HEART_RHYTHM, PERIPHERAL_PULSES, BREATH_SOUNDS, RESP_EFFORT, OXYGEN_MODE,
  ABDOMEN_SHAPE, BOWEL_SOUNDS, CONTINENCE, NUTRITION_ASSIST,
  CATHETER_TYPE, LINE_TYPE, RISK_META,
  BRADEN_SUBSCALES, BRADEN_OPTIONS, CAPRINI_FACTORS,
  MORSE_AMBULATORY_AID, MORSE_GAIT, MORSE_MENTAL,
  GCS_EYE, GCS_VERBAL, GCS_MOTOR,
  EDEMA_LEVELS,
  calcBraden, calcCaprini, calcMorse, calcMust, calcCam, calcPain, calcNews2, calcGcs,
  aggregateRisk, generateAlerts, emptyForm, OXYGEN_DELIVERY_MODES,
} from '~/composables/useAssessmentScoring'

const { $api } = useNuxtApp()
const router = useRouter()
const auth = useAuthStore()

const step = ref(1)
const maxStep = 6
const saving = ref(false)
const signPin = ref('')
const snack = reactive({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })
const patients = ref([])
const bundlePanels = ref(['catheter', 'cl', 'vent', 'wound'])
const useGcs = ref(false)

const steps = [
  { key: 'arrival', label: 'Patient & Vitals', icon: 'mdi-account-check' },
  { key: 'headtotoe', label: 'Head-to-Toe', icon: 'mdi-human-male-board' },
  { key: 'scales', label: 'Risk Scales', icon: 'mdi-shield-check' },
  { key: 'bundles', label: 'Bundles', icon: 'mdi-medical-bag' },
  { key: 'disease', label: 'Disease Bundles', icon: 'mdi-water' },
  { key: 'review', label: 'Review & Save', icon: 'mdi-file-check' },
]

const sessionTypes = [
  { value: 'initial', title: 'Initial Assessment' },
  { value: 'head_to_toe', title: 'Head-to-Toe Baseline' },
  { value: 'reassessment', title: 'Reassessment' },
  { value: 'admission', title: 'Admission' },
  { value: 'discharge', title: 'Discharge' },
]

const stepLabel = computed(() => steps[step.value - 1]?.label || '')
const stepColor = computed(() => {
  const m = { 1: 'teal', 2: 'blue', 3: 'purple', 4: 'teal', 5: 'error', 6: 'success' }
  return m[step.value] || 'teal'
})

const form = ref(emptyForm())
const ini = computed(() => form.value.initial_survey)
const h2t = computed(() => form.value.head_to_toe)
const catheter = computed(() => form.value.catheter_bundle)
const cl = computed(() => form.value.central_line_bundle)
const vent = computed(() => form.value.ventilator_bundle)
const wound = computed(() => form.value.wound_bundle)
const db = computed(() => form.value.disease_bundles)

// Parse wound descriptions from text
watch(() => h2t.value.wound_descriptions_raw, (v) => {
  if (v) {
    h2t.value.wound_descriptions = v.split('\n').filter(Boolean).map(line => ({
      location: line, type: '', size: '',
    }))
  } else { h2t.value.wound_descriptions = [] }
})

// Patient options
const patientOptions = computed(() =>
  patients.value.map(p => ({
    id: p.id,
    label: (p.user?.full_name || p.user?.email) + (p.medical_record_number ? ` · ${p.medical_record_number}` : ''),
  }))
)
const patientName = computed(() => {
  const p = patients.value.find(p => p.id === form.value.patient)
  return p?.user?.full_name || p?.user?.email || '—'
})
const sessionTypeLabel = computed(() => {
  const st = sessionTypes.find(s => s.value === form.value.session_type)
  return st?.title || '—'
})

// Live computed scores
const bradenPreview = computed(() => calcBraden(form.value.braden))
const capriniPreview = computed(() => calcCaprini(form.value.vte_caprini))
const morsePreview = computed(() => calcMorse(form.value.falls))
const mustPreview = computed(() => calcMust(form.value.must))
const camPreview = computed(() => calcCam(form.value.cam))
const news2Computed = computed(() => calcNews2(ini.value))
const gcsPreview = computed(() => calcGcs(ini.value))

const overallRiskLevel = computed(() => aggregateRisk(
  bradenPreview.value.total, capriniPreview.value.points, morsePreview.value.score,
  mustPreview.value.total_score, camPreview.value.cam_positive, ini.value.pain_score,
))
const riskBg = computed(() => RISK_META[overallRiskLevel.value]?.hex ? `${RISK_META[overallRiskLevel.value].hex}18` : 'rgba(100,116,139,0.08)')
const riskTextColor = computed(() => RISK_META[overallRiskLevel.value]?.color || 'grey')
const riskIcon = computed(() => {
  const m = { low: 'mdi-shield-check', medium: 'mdi-shield', high: 'mdi-shield-alert', critical: 'mdi-alert-octagon' }
  return m[overallRiskLevel.value] || 'mdi-shield'
})

const summaryScores = computed(() => [
  { label: 'NEWS2', value: news2Computed.value.total ?? '—', unit: '/20', color: news2Computed.value.total >= 7 ? 'error' : news2Computed.value.total >= 5 ? 'warning' : news2Computed.value.total > 0 ? 'info' : 'success', bg: 'rgba(2,132,199,0.06)' },
  { label: 'Braden', value: bradenPreview.value.total ?? '—', unit: '/23', color: bradenPreview.value.total != null && bradenPreview.value.total <= 12 ? 'error' : bradenPreview.value.total <= 18 ? 'warning' : 'success', bg: 'rgba(13,148,136,0.06)' },
  { label: 'Caprini', value: capriniPreview.value.points ?? '—', unit: 'pts', color: capriniPreview.value.points >= 5 ? 'error' : capriniPreview.value.points >= 3 ? 'warning' : 'success', bg: 'rgba(124,58,237,0.06)' },
  { label: 'Morse', value: morsePreview.value.score ?? '—', unit: '/125', color: morsePreview.value.score >= 45 ? 'error' : morsePreview.value.score >= 25 ? 'warning' : 'success', bg: 'rgba(245,158,11,0.06)' },
  { label: 'MUST', value: mustPreview.value.total_score ?? '—', unit: '/6', color: mustPreview.value.total_score >= 2 ? 'error' : mustPreview.value.total_score === 1 ? 'warning' : 'success', bg: 'rgba(239,68,68,0.06)' },
  { label: 'CAM', value: camPreview.value.cam_positive ? 'Pos' : 'Neg', unit: '', color: camPreview.value.cam_positive ? 'error' : 'success', bg: 'rgba(168,85,247,0.06)' },
  { label: 'Pain', value: ini.value.pain_score ?? '—', unit: '/10', color: ini.value.pain_score >= 7 ? 'error' : ini.value.pain_score >= 4 ? 'warning' : 'success', bg: 'rgba(239,68,68,0.06)' },
  { label: 'GCS', value: gcsPreview.value.total ?? '—', unit: '/15', color: gcsPreview.value.total != null && gcsPreview.value.total <= 8 ? 'error' : gcsPreview.value.total <= 12 ? 'warning' : 'success', bg: 'rgba(124,58,237,0.06)' },
])

const alertsPreview = computed(() => {
  const b = bradenPreview.value; const c = capriniPreview.value; const m = morsePreview.value
  const mu = mustPreview.value; const cam = camPreview.value; const ps = ini.value.pain_score
  return generateAlerts({
    braden_total: b.total, caprini_points: c.points, morse_score: m.score,
    must_score: mu.total_score, cam_positive: cam.cam_positive, pain_score: ps,
    braden: b, vte_caprini: c, falls: m, must: mu,
    catheter_bundle: { present: ini.value.has_catheter, needs_review: catheter.value.needs_review },
    central_line_bundle: { present: ini.value.has_central_line, needs_removal: cl.value.needs_removal },
    disease_bundles: db.value,
  })
})

function toggleCaprini(key) {
  const f = form.value.vte_caprini.factors
  f[key] = !f[key]
}

async function submit() {
  if (!form.value.patient) { snack.text = 'Please select a patient'; snack.color = 'warning'; snack.icon = 'mdi-alert'; snack.show = true; return }
  const pin = signPin.value.trim()
  if (!pin) { snack.text = 'Please enter your staff PIN to sign'; snack.color = 'warning'; snack.icon = 'mdi-alert'; snack.show = true; return }
  if (auth.user?.pin && pin !== auth.user.pin) { snack.text = 'PIN does not match'; snack.color = 'error'; snack.icon = 'mdi-alert-circle'; snack.show = true; return }
  saving.value = true
  const payload = {
    patient: form.value.patient,
    session_type: form.value.session_type,
    arrival: { arrival_timestamp: new Date().toISOString(), arrival_mode: form.value.arrival.arrival_mode },
    initial_survey: ini.value,
    head_to_toe: h2t.value,
    braden: bradenPreview.value,
    vte_caprini: capriniPreview.value,
    falls: morsePreview.value,
    must: mustPreview.value,
    cam: camPreview.value,
    pain: calcPain({ score: ini.value.pain_score }),
    news2: { total: news2Computed.value.total, risk: news2Computed.value.risk.label, scores: news2Computed.value },
    disease_bundles: db.value,
    catheter_bundle: ini.value.has_catheter ? catheter.value : { present: false },
    ventilator_bundle: ini.value.has_ventilator ? vent.value : { present: false },
    central_line_bundle: ini.value.has_central_line ? cl.value : { present: false },
    wound_bundle: (ini.value.has_wound || h2t.value.any_wounds) ? wound.value : { present: false },
    notes: form.value.notes || '',
    pin,
  }
  try {
    const { data } = await $api.post('/homecare/assessment-sessions/', payload)
    snack.text = 'Assessment saved successfully'; snack.color = 'success'; snack.icon = 'mdi-check-circle'; snack.show = true
    setTimeout(() => router.push(`/homecare/assessments/${data.id}`), 1000)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to save assessment'; snack.color = 'error'; snack.icon = 'mdi-alert-circle'; snack.show = true
  } finally { saving.value = false }
}

onMounted(async () => {
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 500 } })
    patients.value = data?.results || data || []
  } catch { /* ignore */ }
})
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-new-hero {
  position: relative; border-radius: 24px; overflow: hidden;
  background: linear-gradient(135deg, #0c3d3a 0%, #0d9488 50%, #0ea5a4 80%);
  box-shadow: 0 20px 60px -16px rgba(13,148,136,0.50), inset 0 0 0 1px rgba(255,255,255,0.08);
}
.hc-new-hero-content { position: relative; z-index: 2; }
.hc-new-hero-glow {
  position: absolute; right: -80px; top: -100px; width: 340px; height: 340px;
  border-radius: 50%; background: radial-gradient(circle, rgba(255,255,255,0.08), transparent 65%);
  pointer-events: none;
}
.hc-new-hero-pattern {
  position: absolute; inset: 0;
  background-image: radial-gradient(rgba(255,255,255,0.06) 1px, transparent 1px);
  background-size: 24px 24px; pointer-events: none;
}
.hc-new-progress { background: white; border: 1px solid rgba(15,23,42,0.06); }
.hc-new-panel { background: white; border: 1px solid rgba(15,23,42,0.06); }
.hc-field :deep(.v-field__outline) { --v-field-border-opacity: 0.20; }
.hc-field:hover :deep(.v-field__outline) { --v-field-border-opacity: 0.40; }
.hc-expand :deep(.v-expansion-panel) { margin-bottom: 4px; }
.news2-panel {
  border: 1px solid rgba(13,148,136,0.2);
  border-radius: 16px;
  padding: 16px;
  position: sticky;
  top: 8px;
}
.news2-total { font-size: 46px; font-weight: 800; line-height: 1; margin: 2px 0 8px; }
.news2-row {
  display: flex; align-items: center;
  padding: 5px 0;
  border-bottom: 1px solid rgba(148,163,184,0.15);
}
.news2-row:last-child { border-bottom: none; }
:global(.v-theme--dark .news2-row) { border-bottom-color: rgba(148,163,184,0.12); }
:global(.v-theme--dark .hc-new-progress),
:global(.v-theme--dark .hc-new-panel) { background: rgb(30,41,59); border-color: rgba(255,255,255,0.08); }
</style>
