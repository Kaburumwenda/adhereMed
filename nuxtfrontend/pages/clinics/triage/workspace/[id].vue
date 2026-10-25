<template>
  <v-container fluid class="pa-4 pa-md-6 tr-page" :style="heroTheme">
    <!-- ══ Critical safety strip ══════════════════════════════════════ -->
    <div v-if="allergyList.length" class="tr-critical">
      <div class="tr-critical-icon">
        <v-icon size="18">mdi-alert-octagon</v-icon>
      </div>
      <div class="tr-critical-text">
        <div class="tr-critical-eyebrow">Allergy alert · verify before any drug administration</div>
        <div class="tr-critical-body">{{ allergyList.join(' · ') }}</div>
      </div>
      <span class="tr-critical-count">{{ allergyList.length }} recorded</span>
    </div>

    <!-- ══ Hero ══════════════════════════════════════════════════════ -->
    <header class="tr-hero">
      <span class="tr-hero-glow"></span>
      <span class="tr-hero-glow-2"></span>

      <div class="tr-hero-top">
        <v-btn icon variant="text" class="tr-back" to="/clinics/triage" aria-label="Back to triage queue">
          <v-icon size="20">mdi-arrow-left</v-icon>
        </v-btn>

        <div class="tr-hero-avatar">{{ initials || '?' }}</div>

        <div class="tr-hero-id">
          <div class="tr-eyebrow">
            <v-icon size="11">mdi-monitor-heart</v-icon>
            Triage · {{ statusLabel }}<span v-if="triageId"> · #{{ triageId }}</span>
          </div>
          <h1 class="tr-patient">{{ patientName || 'Loading patient…' }}</h1>
          <div class="tr-meta">
            <span v-for="m in heroMeta" :key="m">{{ m }}</span>
          </div>
        </div>

        <div class="tr-hero-actions">
          <button type="button" class="tr-glass" :disabled="saving" @click="saveDraft">
            <v-icon size="16">mdi-content-save-outline</v-icon>
            Save draft
          </button>
          <button type="button" class="tr-solid" :disabled="!canComplete || saving" @click="completeTriage">
            <v-icon size="16">mdi-check-circle</v-icon>
            Complete triage
          </button>
        </div>
      </div>

      <div class="tr-hero-foot">
        <div class="tr-chip" :class="'is-' + waitTimeColor">
          <span class="tr-pulse"></span>
          <v-icon size="13">mdi-timer-sand</v-icon>
          {{ waitTimeLabel }}
        </div>
        <div class="tr-chip" :class="'is-' + news2Color">
          <v-icon size="13">mdi-heart-pulse</v-icon>
          NEWS2 {{ news2Score }} · {{ news2Cat.label }}
        </div>
        <div class="tr-chip" :class="'is-' + esiTone">
          <v-icon size="13">mdi-clipboard-pulse</v-icon>
          ESI {{ form.esi_level || '—' }}<span v-if="esiMeta"> · {{ esiMeta.label }}</span>
        </div>
        <div v-if="bmi" class="tr-chip">
          <v-icon size="13">mdi-scale-bathroom</v-icon>
          BMI {{ bmi }}<span v-if="bmiHint"> · {{ bmiHint }}</span>
        </div>
        <div v-if="lastSave" class="tr-chip tr-chip--muted">
          <v-icon size="13">mdi-cloud-check</v-icon>
          Saved {{ lastSave }}
        </div>

        <div class="tr-hero-progress">
          <div class="tr-hero-progress-bar">
            <span :style="{ width: completionPct + '%' }"></span>
          </div>
          <span class="tr-hero-progress-label">{{ completionPct }}% documented</span>
        </div>
      </div>
    </header>

    <!-- ══ Body ══════════════════════════════════════════════════════ -->
    <div class="tr-grid">
      <!-- ─────────── Main column ─────────── -->
      <div class="tr-main">
        <!-- Chief complaint -->
        <section class="tr-card">
          <div class="tr-card-head">
            <div class="tr-card-icon is-primary"><v-icon size="18">mdi-format-text</v-icon></div>
            <div class="tr-card-titles">
              <h2>Chief complaint</h2>
              <p>What brought the patient in, in their own words</p>
            </div>
            <span class="tr-req" :class="{ done: complaintDone }">
              <v-icon size="12">{{ complaintDone ? 'mdi-check' : 'mdi-asterisk' }}</v-icon>
              {{ complaintDone ? 'Captured' : 'Required' }}
            </span>
          </div>

          <div class="tr-card-body">
            <v-textarea
              v-model="form.chief_complaint"
              placeholder="e.g. Sudden chest tightness since this morning, worse on exertion…"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              rows="2"
              auto-grow
              hide-details
            />

            <ReasonChips v-model="form.chief_complaint" class="mt-3" />

            <div class="tr-split">
              <v-select
                v-model="form.arrival_mode"
                :items="arrivalModes"
                item-title="title"
                item-value="value"
                label="Arrival mode"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
                prepend-inner-icon="mdi-ambulance"
              />

              <div class="tr-pain">
                <div class="tr-pain-head">
                  <span class="tr-mini-label">Pain score</span>
                  <span class="tr-pain-value" :style="{ color: painColor(form.pain_scale) }">
                    {{ form.pain_scale }}/10
                    <em>{{ painLabel }}</em>
                  </span>
                </div>
                <div class="tr-pain-scale">
                  <button
                    v-for="n in 11"
                    :key="n"
                    type="button"
                    class="tr-pain-btn"
                    :class="{ on: form.pain_scale === n - 1 }"
                    :style="{ '--pn': painColor(n - 1) }"
                    :title="`${n - 1} — ${painWord(n - 1)}`"
                    @click="form.pain_scale = n - 1"
                  >
                    {{ n - 1 }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Vital signs -->
        <section class="tr-card">
          <div class="tr-card-head">
            <div class="tr-card-icon is-error"><v-icon size="18">mdi-heart-pulse</v-icon></div>
            <div class="tr-card-titles">
              <h2>Vital signs</h2>
              <p>Out-of-range values are flagged automatically</p>
            </div>
            <span class="tr-req" :class="{ done: vitalsDone }">
              <v-icon size="12">{{ vitalsDone ? 'mdi-check' : 'mdi-asterisk' }}</v-icon>
              {{ vitalsDone ? 'Recorded' : 'Required' }}
            </span>
          </div>

          <div class="tr-card-body">
            <div class="tr-vitals">
              <!-- `normal` is the clinical reference band (colours the field);
                   `min`/`max` are the physiological limits that hard-block entry. -->
              <VitalInput v-model="form.vital_signs.temperature" label="Temperature" unit="°C" :normal="[36.1, 38]" :min="30" :max="45" :step="0.1" />
              <VitalInput v-model="form.vital_signs.bp_systolic" label="BP Systolic" unit="mmHg" :normal="[110, 140]" :min="40" :max="300" />
              <VitalInput v-model="form.vital_signs.bp_diastolic" label="BP Diastolic" unit="mmHg" :normal="[70, 90]" :min="20" :max="200" />
              <VitalInput v-model="form.vital_signs.heart_rate" label="Pulse" unit="bpm" :normal="[60, 100]" :min="20" :max="300" />
              <VitalInput v-model="form.vital_signs.respiratory_rate" label="Resp Rate" unit="/min" :normal="[12, 20]" :min="4" :max="80" />
              <VitalInput v-model="form.vital_signs.oxygen_saturation" label="SpO₂" unit="%" :normal="[95, 100]" :min="50" :max="100" />
              <VitalInput v-model="form.vital_signs.blood_sugar" label="Blood Sugar" unit="mmol/L" :normal="[4, 7]" :min="0.5" :max="50" :step="0.1" />
              <VitalInput v-model="form.vital_signs.weight" label="Weight" unit="kg" :normal="[0, 0]" :min="0.5" :max="500" :step="0.1" @update:model-value="updateBMI" />
              <VitalInput v-model="form.vital_signs.height" label="Height" unit="cm" :normal="[0, 0]" :min="20" :max="250" :step="0.1" @update:model-value="updateBMI" />
            </div>

            <div class="tr-vitals-foot">
              <div class="tr-seg-block">
                <span class="tr-mini-label">Consciousness · AVPU</span>
                <div class="tr-seg">
                  <button
                    v-for="a in avpuOptions"
                    :key="a.value"
                    type="button"
                    class="tr-seg-btn"
                    :class="{ on: form.avpu === a.value, danger: a.danger && form.avpu === a.value }"
                    @click="form.avpu = a.value"
                  >
                    {{ a.label }}
                  </button>
                </div>
              </div>

              <div class="tr-news">
                <div class="tr-news-top">
                  <span class="tr-mini-label">NEWS2</span>
                  <span class="tr-news-score" :style="{ color: news2Hex }">{{ news2Score }}</span>
                  <span class="tr-news-cat">{{ news2Cat.label }}</span>
                </div>
                <div class="tr-news-track">
                  <span class="tr-news-zone z1"></span>
                  <span class="tr-news-zone z2"></span>
                  <span class="tr-news-zone z3"></span>
                  <span class="tr-news-dot" :style="{ left: 'calc(' + news2Pct + '% - 6px)', background: news2Hex }"></span>
                </div>
                <div class="tr-news-legend">
                  <span>0–4 low</span><span>5–6 medium</span><span>7+ high</span>
                </div>
              </div>
            </div>

            <div v-if="impossibleVitals.length" class="tr-alert is-error">
              <v-icon size="16">mdi-close-octagon</v-icon>
              <div>
                <strong>Value outside the possible range</strong>
                <span>{{ impossibleVitals.join(' · ') }} — correct before completing triage.</span>
              </div>
            </div>

            <div v-else-if="abnormalVitals.length" class="tr-abn">
              <header class="tr-abn-head">
                <v-icon size="16">mdi-alert</v-icon>
                <div class="tr-abn-headtext">
                  <strong>{{ abnormalVitals.length }} abnormal {{ abnormalVitals.length === 1 ? 'value' : 'values' }} detected</strong>
                  <span v-if="criticalVitalCount">
                    {{ criticalVitalCount }} need{{ criticalVitalCount === 1 ? 's' : '' }} immediate review
                  </span>
                  <span v-else>Flag to the clinician at handoff</span>
                </div>
              </header>

              <ul class="tr-abn-list">
                <li
                  v-for="a in abnormalVitals"
                  :key="a.key"
                  class="tr-abn-item"
                  :class="'is-' + a.severity"
                >
                  <div class="tr-abn-item-top">
                    <span class="tr-abn-arrow">
                      <v-icon size="12">{{ a.arrow }}</v-icon>
                    </span>
                    <span class="tr-abn-label">{{ a.label }}</span>
                    <span class="tr-abn-value">{{ a.value }}</span>
                    <span class="tr-abn-tag">{{ a.finding }}</span>
                  </div>
                  <div class="tr-abn-note">
                    <v-icon size="12">mdi-lightbulb-on-outline</v-icon>
                    <span>{{ a.note }}</span>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </section>

        <!-- ESI -->
        <section class="tr-card">
          <div class="tr-card-head">
            <div class="tr-card-icon is-warning"><v-icon size="18">mdi-clipboard-pulse</v-icon></div>
            <div class="tr-card-titles">
              <h2>ESI acuity assignment</h2>
              <p>System suggestion is based on the current NEWS2 score</p>
            </div>
            <span class="tr-req" :class="{ done: !!form.esi_level }">
              <v-icon size="12">{{ form.esi_level ? 'mdi-check' : 'mdi-asterisk' }}</v-icon>
              {{ form.esi_level ? 'Assigned' : 'Required' }}
            </span>
          </div>

          <div class="tr-card-body">
            <div class="tr-esi-grid">
              <button
                v-for="e in esiLevels"
                :key="e.level"
                type="button"
                class="tr-esi"
                :class="{ on: form.esi_level === e.level, suggested: e.level === suggestedESI }"
                :style="{ '--esi': e.color }"
                @click="pickESI(e.level)"
              >
                <span v-if="e.level === suggestedESI" class="tr-esi-flag">
                  <v-icon size="10">mdi-auto-fix</v-icon>Suggested
                </span>
                <div class="tr-esi-top">
                  <span class="tr-esi-num">{{ e.level }}</span>
                  <v-icon v-if="form.esi_level === e.level" size="15" class="tr-esi-check">mdi-check-circle</v-icon>
                </div>
                <div class="tr-esi-name">{{ e.label }}</div>
                <div class="tr-esi-time">{{ e.target }}</div>
                <div class="tr-esi-desc">{{ e.desc }}</div>
              </button>
            </div>

            <div v-if="isOverriding" class="tr-alert is-warning mt-3">
              <v-icon size="16">mdi-alert-outline</v-icon>
              <div class="tr-override">
                <strong>You are overriding the suggested ESI {{ suggestedESI }}</strong>
                <span>Document a clinical reason before completing triage.</span>
                <template v-if="!overrideConfirmed">
                  <v-text-field
                    v-model="form.esi_override_reason"
                    placeholder="e.g. Patient reassessed after analgesia, now comfortable"
                    variant="outlined"
                    density="compact"
                    rounded="lg"
                    hide-details
                    class="mt-2"
                  />
                  <button
                    type="button"
                    class="tr-mini-cta"
                    :disabled="!form.esi_override_reason.trim()"
                    @click="overrideConfirmed = true"
                  >
                    <v-icon size="13">mdi-check</v-icon>Confirm override
                  </button>
                </template>
                <span v-else class="tr-confirmed">
                  <v-icon size="13">mdi-check-decagram</v-icon>Override confirmed
                  <em v-if="form.esi_override_reason">· {{ form.esi_override_reason }}</em>
                </span>
              </div>
            </div>
          </div>
        </section>

        <!-- Allergies & medication reconciliation -->
        <section class="tr-card">
          <div class="tr-card-head">
            <div class="tr-card-icon is-purple"><v-icon size="18">mdi-pill</v-icon></div>
            <div class="tr-card-titles">
              <h2>Allergies, conditions &amp; medications</h2>
              <p>Reconcile with the patient before the clinician sees them</p>
            </div>
          </div>

          <div class="tr-card-body">
            <div class="tr-subblock">
              <div class="tr-subhead">
                <span class="tr-mini-label">Allergies</span>
                <span class="tr-count">{{ allergyList.length }}</span>
              </div>

              <!-- Catalog-backed multi-select, matching the front-desk register
                   field: pick from the clinic's own allergy catalog, or type a
                   new allergen and press Enter. -->
              <v-combobox
                v-model="allergiesModel"
                :items="allergyOptions"
                :loading="catalogLoading"
                :item-props="clinicalItemProps"
                item-title="title"
                item-value="value"
                :delimiters="null"
                label="Allergies"
                placeholder="Search the catalog, or type a new allergen"
                multiple
                chips
                closable-chips
                small-chips
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-alert-box-outline"
                no-data-text="No match — press Enter to add it"
                :hide-no-data="false"
                :menu-props="{ maxHeight: 360 }"
                hide-details
              >
                <template #append-item>
                  <div class="tr-cb-foot">
                    <v-btn block variant="text" size="small" rounded="lg"
                           class="text-none tr-cb-link" prepend-icon="mdi-cog-outline"
                           to="/clinics/catalog/allergies" @mousedown.stop>
                      Manage allergy catalog
                      <v-icon end size="14">mdi-arrow-top-right</v-icon>
                    </v-btn>
                  </div>
                </template>
              </v-combobox>

              <div class="tr-cb-note">
                <v-icon size="12">mdi-library-shelves</v-icon>
                <span v-if="catalogLoading">Loading the clinic catalog…</span>
                <span v-else>{{ allergyOptions.length }} allergens from the clinic catalog</span>
              </div>

              <label class="tr-confirm" :class="{ on: form.allergies_confirmed }">
                <input v-model="form.allergies_confirmed" type="checkbox" />
                <span class="tr-confirm-box"><v-icon size="13">mdi-check</v-icon></span>
                <span class="tr-confirm-label">
                  Allergies confirmed with the patient
                  <em>Required before triage can be completed</em>
                </span>
              </label>
            </div>

            <div class="tr-subblock tr-subblock--gap">
              <div class="tr-subhead">
                <span class="tr-mini-label">Chronic conditions</span>
                <span class="tr-count">{{ conditionList.length }}</span>
              </div>

              <!-- Same catalog-backed pattern as Allergies: pick from the clinic's
                   condition catalog, or type a new diagnosis and press Enter. -->
              <v-combobox
                v-model="conditionsModel"
                :items="conditionOptions"
                :loading="catalogLoading"
                :item-props="clinicalItemProps"
                item-title="title"
                item-value="value"
                :delimiters="null"
                label="Chronic conditions"
                placeholder="Search the catalog, or type a new condition"
                multiple
                chips
                closable-chips
                small-chips
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-heart-pulse"
                no-data-text="No match — press Enter to add it"
                :hide-no-data="false"
                :menu-props="{ maxHeight: 360 }"
                hide-details
              >
                <template #append-item>
                  <div class="tr-cb-foot">
                    <v-btn block variant="text" size="small" rounded="lg"
                           class="text-none tr-cb-link" prepend-icon="mdi-cog-outline"
                           to="/clinics/catalog/chronic-conditions" @mousedown.stop>
                      Manage condition catalog
                      <v-icon end size="14">mdi-arrow-top-right</v-icon>
                    </v-btn>
                  </div>
                </template>
              </v-combobox>

              <div class="tr-cb-note">
                <v-icon size="12">mdi-library-shelves</v-icon>
                <span v-if="catalogLoading">Loading the clinic catalog…</span>
                <span v-else>{{ conditionOptions.length }} conditions from the clinic catalog</span>
              </div>
            </div>

            <div class="tr-divider"></div>

            <div class="tr-subblock">
              <div class="tr-subhead">
                <span class="tr-mini-label">Medication history</span>
                <span class="tr-count">{{ form.medication_history.length }}</span>
                <button type="button" class="tr-ghostbtn" @click="addMed">
                  <v-icon size="13">mdi-plus</v-icon>Add row
                </button>
              </div>

              <div v-if="form.medication_history.length" class="tr-meds">
                <div v-for="(m, i) in form.medication_history" :key="i" class="tr-med">
                  <v-text-field v-model="m.name" placeholder="Drug name" variant="outlined" density="compact" rounded="lg" hide-details />
                  <v-text-field v-model="m.dose" placeholder="Dose" variant="outlined" density="compact" rounded="lg" hide-details />
                  <v-text-field v-model="m.frequency" placeholder="Frequency" variant="outlined" density="compact" rounded="lg" hide-details />
                  <button type="button" class="tr-del" title="Remove" @click="form.medication_history.splice(i, 1)">
                    <v-icon size="15">mdi-delete-outline</v-icon>
                  </button>
                </div>
              </div>
              <div v-else class="tr-empty">No current medication pulled from prescriptions</div>
            </div>
          </div>
        </section>

        <!-- Screening -->
        <section class="tr-card">
          <button type="button" class="tr-card-head tr-card-head--btn tr-card-head--screening" @click="open.screening = !open.screening">
            <div class="tr-card-icon is-teal"><v-icon size="18">mdi-clipboard-search</v-icon></div>
            <div class="tr-card-titles">
              <h2>Screening</h2>
              <p>{{ screeningComplete ? 'All screening questions answered' : 'Lifestyle, risk factors and mental health' }}</p>
            </div>
            <!-- Collapsed, this badge is the only signal that the section is
                 still outstanding — so it states the requirement explicitly. -->
            <span class="tr-screen-badge" :class="{ done: screeningComplete }">
              <v-icon size="11">{{ screeningComplete ? 'mdi-check' : 'mdi-asterisk' }}</v-icon>
              {{ screeningComplete ? 'Complete' : `Required · ${screeningMissing} left` }}
            </span>
            <span class="tr-screen-count">{{ screeningDone }}/{{ screeningTotal }}</span>
            <v-icon size="18" class="tr-chev">{{ open.screening ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
          </button>

          <div v-if="open.screening" class="tr-card-body">
            <!-- Risk flags raised by the answers so far -->
            <div v-if="screeningFlags.length" class="tr-flags">
              <span v-for="f in screeningFlags" :key="f.label" class="tr-flag" :style="{ '--tone': f.tone }">
                <v-icon size="12">{{ f.icon }}</v-icon>
                {{ f.label }}
              </span>
            </div>

            <div class="tr-field-block">
              <div class="tr-field-head">
                <span class="tr-field-label">Smoking</span>
                <span v-if="smokingMeta" class="tr-field-value" :style="{ color: smokingMeta.tone }">{{ smokingMeta.title }}</span>
              </div>
              <div class="tr-tiles tr-tiles--4">
                <button
                  v-for="o in smokingOptions"
                  :key="o.value"
                  type="button"
                  class="tr-tile"
                  :class="{ on: form.smoking_status === o.value }"
                  :style="{ '--tone': o.tone }"
                  @click="toggleChoice('smoking_status', o.value)"
                >
                  <v-icon size="17" class="tr-tile-icon">{{ o.icon }}</v-icon>
                  <span class="tr-tile-label">{{ o.title }}</span>
                  <span class="tr-tile-desc">{{ o.desc }}</span>
                </button>
              </div>
            </div>

            <div class="tr-field-block">
              <div class="tr-field-head">
                <span class="tr-field-label">Alcohol use</span>
                <span v-if="alcoholMeta" class="tr-field-value" :style="{ color: alcoholMeta.tone }">
                  {{ alcoholMeta.title }}
                </span>
              </div>
              <div class="tr-tiles tr-tiles--4">
                <button
                  v-for="o in alcoholOptions"
                  :key="o.value"
                  type="button"
                  class="tr-tile"
                  :class="{ on: form.alcohol_use === o.value }"
                  :style="{ '--tone': o.tone }"
                  @click="toggleChoice('alcohol_use', o.value)"
                >
                  <v-icon size="17" class="tr-tile-icon">{{ o.icon }}</v-icon>
                  <span class="tr-tile-label">{{ o.title }}</span>
                  <span class="tr-tile-desc">{{ o.desc }}</span>
                </button>
              </div>
            </div>

            <div class="tr-field-block">
              <div class="tr-field-head">
                <span class="tr-field-label">Substance use</span>
              </div>
              <v-select
                v-model="form.substance_use"
                :items="substanceOptions"
                item-title="title"
                item-value="value"
                label="Recreational or injected substances"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                clearable
                hide-details
                prepend-inner-icon="mdi-flask-outline"
              />
            </div>

            <div class="tr-divider"></div>

            <div class="tr-subhead">
              <span class="tr-mini-label">Risk assessment</span>
            </div>

            <div class="tr-field-block">
              <div class="tr-field-head">
                <span class="tr-field-label">Fall risk</span>
                <span v-if="fallMeta" class="tr-field-value" :style="{ color: fallMeta.tone }">
                  {{ fallMeta.title }}
                </span>
              </div>
              <div class="tr-tiles tr-tiles--3">
                <button
                  v-for="o in fallOptions"
                  :key="o.value"
                  type="button"
                  class="tr-tile"
                  :class="{ on: form.fall_risk === o.value }"
                  :style="{ '--tone': o.tone }"
                  @click="toggleChoice('fall_risk', o.value)"
                >
                  <v-icon size="17" class="tr-tile-icon">{{ o.icon }}</v-icon>
                  <span class="tr-tile-label">{{ o.title }}</span>
                  <span class="tr-tile-desc">{{ o.desc }}</span>
                </button>
              </div>
            </div>

            <div v-if="showPregnancy" class="tr-field-block">
              <div class="tr-field-head">
                <span class="tr-field-label">Pregnancy</span>
                <span v-if="pregnancyMeta" class="tr-field-value" :style="{ color: pregnancyMeta.tone }">{{ pregnancyMeta.title }}</span>
              </div>
              <div class="tr-tiles tr-tiles--4">
                <button
                  v-for="o in pregnancyOptions"
                  :key="o.value"
                  type="button"
                  class="tr-tile"
                  :class="{ on: form.pregnancy_status === o.value }"
                  :style="{ '--tone': o.tone }"
                  @click="toggleChoice('pregnancy_status', o.value)"
                >
                  <v-icon size="17" class="tr-tile-icon">{{ o.icon }}</v-icon>
                  <span class="tr-tile-label">{{ o.title }}</span>
                  <span class="tr-tile-desc">{{ o.desc }}</span>
                </button>
              </div>
            </div>

            <div class="tr-divider"></div>

            <!-- PHQ-2: two-item depression screen -->
            <div class="tr-field-head">
              <span class="tr-field-label">Mental health · PHQ-2</span>
              <span class="tr-phq-chip" :class="phq2Tone">{{ phq2Score }} / 6</span>
            </div>
            <p class="tr-phq-intro">Over the last 2 weeks, how often have you been bothered by…</p>

            <div v-for="q in phq2Questions" :key="q.key" class="tr-phq-q">
              <span class="tr-phq-text">{{ q.text }}</span>
              <div class="tr-phq-opts">
                <button
                  v-for="s in phq2Scale"
                  :key="s.value"
                  type="button"
                  class="tr-phq-btn"
                  :class="{ on: phqAnswer(q.key) === s.value }"
                  :title="`${s.value} — ${s.title}`"
                  @click="setPhq(q.key, s.value)"
                >
                  {{ s.value }}
                </button>
              </div>
            </div>

            <div v-if="phq2Complete" class="tr-phq-result" :class="phq2Positive ? 'is-warn' : 'is-ok'">
              <v-icon size="14">{{ phq2Positive ? 'mdi-alert-outline' : 'mdi-check-circle-outline' }}</v-icon>
              <span>{{ phq2Interpretation }}</span>
            </div>
            <div v-else class="tr-phq-result is-idle">
              <v-icon size="14">mdi-information-outline</v-icon>
              <span>Answer both items to score the screen. 0 = not at all, 3 = nearly every day.</span>
            </div>
          </div>
        </section>

        <!-- Nursing assessment -->
        <section class="tr-card">
          <button type="button" class="tr-card-head tr-card-head--btn" @click="open.nursing = !open.nursing">
            <div class="tr-card-icon is-indigo"><v-icon size="18">mdi-notebook</v-icon></div>
            <div class="tr-card-titles">
              <h2>Nursing assessment &amp; interventions</h2>
              <p>Free-text clinical documentation</p>
            </div>
            <v-icon size="18" class="tr-chev">{{ open.nursing ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
          </button>

          <div v-if="open.nursing" class="tr-card-body">
            <v-textarea v-model="form.nursing_assessment" label="Initial nursing assessment" variant="outlined" density="comfortable" rounded="lg" rows="3" hide-details class="mb-3" />
            <v-textarea v-model="form.interventions" label="Interventions given" variant="outlined" density="comfortable" rounded="lg" rows="2" hide-details class="mb-3" />
            <v-textarea v-model="form.patient_education" label="Patient education provided" variant="outlined" density="comfortable" rounded="lg" rows="2" hide-details />
          </div>
        </section>

        <!-- Notes -->
        <section class="tr-card">
          <button type="button" class="tr-card-head tr-card-head--btn" @click="open.notes = !open.notes">
            <div class="tr-card-icon is-grey"><v-icon size="18">mdi-note-edit</v-icon></div>
            <div class="tr-card-titles">
              <h2>Additional notes</h2>
              <p>Anything else the clinician should know</p>
            </div>
            <v-icon size="18" class="tr-chev">{{ open.notes ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
          </button>

          <div v-if="open.notes" class="tr-card-body">
            <v-textarea v-model="form.notes" label="Notes" variant="outlined" density="comfortable" rounded="lg" rows="3" hide-details />
          </div>
        </section>
      </div>

      <!-- ─────────── Right rail ─────────── -->
      <aside class="tr-rail">
        <!-- Acuity -->
        <section class="tr-card tr-card--rail">
          <div class="tr-card-head tr-card-head--tight">
            <div class="tr-card-icon is-primary"><v-icon size="17">mdi-gauge</v-icon></div>
            <div class="tr-card-titles">
              <h2>Acuity snapshot</h2>
            </div>
          </div>

          <div class="tr-card-body">
            <div class="tr-dials">
              <div class="tr-dial">
                <v-progress-circular
                  :model-value="news2Pct"
                  :size="86"
                  :width="7"
                  :color="news2Hex"
                  class="tr-dial-ring"
                >
                  <div class="tr-dial-inner">
                    <span class="tr-dial-num" :style="{ color: news2Hex }">{{ news2Score }}</span>
                    <span class="tr-dial-label">NEWS2</span>
                  </div>
                </v-progress-circular>
                <span class="tr-dial-caption">{{ news2Cat.label }}</span>
              </div>

              <div class="tr-dial">
                <div class="tr-esi-big" :style="{ '--esi': esiHex }">
                  <span class="tr-esi-big-num">{{ form.esi_level || '—' }}</span>
                  <span class="tr-esi-big-label">ESI</span>
                </div>
                <span class="tr-dial-caption">{{ esiMeta ? esiMeta.label : 'Not assigned' }}</span>
              </div>
            </div>

            <p class="tr-dial-note">{{ news2Cat.description }}</p>

            <div class="tr-divider"></div>

            <div class="tr-snap">
              <div v-for="row in vitalSnapshot" :key="row.key" class="tr-snap-row">
                <span class="tr-snap-dot" :class="row.status"></span>
                <span class="tr-snap-label">{{ row.label }}</span>
                <span class="tr-snap-value" :class="row.status">{{ row.text }}</span>
              </div>
            </div>

            <div v-if="abnormalVitals.length" class="tr-rail-warn" :class="{ 'is-critical': criticalVitalCount }">
              <v-icon size="14">mdi-alert</v-icon>
              <span>
                {{ abnormalVitals.length }} abnormal
                {{ abnormalVitals.length === 1 ? 'value' : 'values' }}
                <em v-if="criticalVitalCount">· {{ criticalVitalCount }} critical</em>
              </span>
            </div>
          </div>
        </section>

        <!-- Readiness -->
        <section class="tr-card tr-card--rail">
          <div class="tr-card-head tr-card-head--tight">
            <div class="tr-card-icon is-success"><v-icon size="17">mdi-shield-check</v-icon></div>
            <div class="tr-card-titles">
              <h2>Triage readiness</h2>
            </div>
            <span class="tr-rail-badge">{{ readinessDone }}/{{ readiness.length }}</span>
          </div>

          <div class="tr-card-body">
            <ul class="tr-checks">
              <li v-for="item in readiness" :key="item.key" :class="{ done: item.done }">
                <span class="tr-check-dot">
                  <v-icon size="11">{{ item.done ? 'mdi-check' : 'mdi-circle-small' }}</v-icon>
                </span>
                <span class="tr-check-label">{{ item.label }}</span>
                <span class="tr-check-hint">{{ item.hint }}</span>
              </li>
            </ul>
          </div>
        </section>

        <!-- Handoff clinician -->
        <section class="tr-card tr-card--rail">
          <div class="tr-card-head tr-card-head--tight">
            <div class="tr-card-icon is-blue"><v-icon size="17">mdi-doctor</v-icon></div>
            <div class="tr-card-titles">
              <h2>Handoff clinician</h2>
            </div>
            <span class="tr-req" :class="{ done: !!form.doctor }">
              <v-icon size="12">{{ form.doctor ? 'mdi-check' : 'mdi-asterisk' }}</v-icon>
              {{ form.doctor ? 'Assigned' : 'Required' }}
            </span>
          </div>

          <div class="tr-card-body">
            <!-- Selected clinician summary -->
            <div v-if="selectedDoctor" class="tr-hd-selected" :class="{ 'is-busy': selectedDoctor.load > 0 }">
              <div class="tr-hd-avatar">
                {{ initialsOf(selectedDoctor.full_name) }}
                <span class="tr-hd-presence" :class="selectedDoctor.engaged ? 'on' : 'off'"></span>
              </div>
              <div class="tr-hd-selected-id">
                <div class="tr-hd-selected-name">{{ selectedDoctor.full_name }}</div>
                <div class="tr-hd-selected-meta">
                  {{ selectedDoctor.department || roleLabel(selectedDoctor.role) }}
                  · {{ presenceText(selectedDoctor) }}
                </div>
              </div>
              <button type="button" class="tr-hd-clear" title="Unassign" @click="form.doctor = null">
                <v-icon size="14">mdi-close</v-icon>
              </button>
              <div class="tr-hd-selected-stats">
                <div class="tr-hd-stat">
                  <span class="tr-hd-stat-num">{{ selectedDoctor.waiting }}</span>
                  <span class="tr-hd-stat-label">Waiting</span>
                </div>
                <div class="tr-hd-stat">
                  <span class="tr-hd-stat-num">{{ selectedDoctor.in_progress }}</span>
                  <span class="tr-hd-stat-label">In consult</span>
                </div>
                <div class="tr-hd-stat">
                  <span class="tr-hd-stat-num">{{ selectedDoctor.load }}</span>
                  <span class="tr-hd-stat-label">Total load</span>
                </div>
              </div>
            </div>

            <!-- Recommendation banner -->
            <div v-if="suggestedDoctor && !form.doctor" class="tr-hd-suggest">
              <div class="tr-hd-suggest-head">
                <v-icon size="14">mdi-auto-fix</v-icon>
                <span>Suggested · shortest queue</span>
              </div>
              <div class="tr-hd-suggest-name">{{ suggestedDoctor.full_name }}</div>
              <div class="tr-hd-suggest-why">
                {{ suggestionReason }}
              </div>
              <button type="button" class="tr-hd-accept" @click="form.doctor = suggestedDoctor.id">
                <v-icon size="13">mdi-account-check</v-icon>
                Assign {{ suggestedDoctor.full_name.split(' ')[0] }}
              </button>
            </div>

            <div class="tr-hd-toolbar">
              <span class="tr-mini-label">
                {{ workloadCount }} {{ workloadCount === 1 ? 'clinician' : 'clinicians' }}
                <span v-if="workloadTenantName" class="tr-hd-scope">· {{ workloadTenantName }}</span>
              </span>
              <button type="button" class="tr-ghostbtn" :disabled="workloadLoading" @click="loadWorkload">
                <v-icon size="13">{{ workloadLoading ? 'mdi-loading mdi-spin' : 'mdi-refresh' }}</v-icon>
                Refresh
              </button>
            </div>

            <div v-if="workloadLoading && !doctors.length" class="tr-empty">Loading clinician workload…</div>
            <div v-else-if="!doctors.length" class="tr-empty">
              No clinicians on this clinic's roster yet
            </div>

            <ul v-else class="tr-hd-list">
              <li
                v-for="d in doctors"
                :key="d.id"
                class="tr-hd-row"
                :class="{ on: form.doctor === d.id, recommended: d.recommended && form.doctor !== d.id }"
                role="button"
                tabindex="0"
                @click="form.doctor = form.doctor === d.id ? null : d.id"
                @keydown.enter.prevent="form.doctor = form.doctor === d.id ? null : d.id"
              >
                <span class="tr-hd-dot" :class="d.engaged ? 'on' : 'off'" :title="presenceText(d)"></span>
                <span class="tr-hd-row-id">
                  <span class="tr-hd-row-name">{{ d.full_name }}</span>
                  <span class="tr-hd-row-sub">
                    <template v-if="d.department">{{ d.department }} · </template>{{ presenceText(d) }}
                  </span>
                </span>

                <span class="tr-hd-loadbar" :title="`${d.load} patient(s) in this doctor's queue`">
                  <span
                    v-for="n in loadSegments(d)"
                    :key="n"
                    class="tr-hd-seg"
                    :class="n <= d.in_progress ? 'busy' : 'waiting'"
                  ></span>
                  <span v-for="n in 5 - loadSegments(d)" :key="'e' + n" class="tr-hd-seg empty"></span>
                </span>

                <span class="tr-hd-queue" :class="queueTone(d)">{{ d.load }}</span>
                <v-icon v-if="form.doctor === d.id" size="15" class="tr-hd-tick">mdi-check-circle</v-icon>
              </li>
            </ul>

            <button
              v-if="form.doctor"
              type="button"
              class="tr-consult"
              :disabled="!canComplete || startingConsult"
              @click="startConsultation"
            >
              <v-icon size="15">mdi-clipboard-text-play</v-icon>
              {{ startingConsult ? 'Starting…' : 'Start consultation' }}
            </button>

            <p class="tr-rail-hint">
              <v-icon size="12">mdi-information-outline</v-icon>
              Required — the patient cannot be routed without a receiving clinician.
              <template v-if="engagedCount"> {{ engagedCount }} {{ engagedCount === 1 ? 'clinician is' : 'clinicians are' }} engaged right now.</template>
            </p>
          </div>
        </section>
      </aside>
    </div>

    <!-- ══ Sticky action bar ═════════════════════════════════════════ -->
    <div class="tr-actionbar">
      <div class="tr-actionbar-inner">
        <div class="tr-actionbar-left">
          <div class="tr-actionring">
            <v-progress-circular :model-value="completionPct" :size="34" :width="3.5" :color="canComplete ? 'success' : 'primary'">
              <span class="tr-actionring-num">{{ completionPct }}</span>
            </v-progress-circular>
          </div>
          <div class="tr-actionbar-text">
            <strong v-if="canComplete">Ready to complete</strong>
            <strong v-else>{{ remainingCount }} {{ remainingCount === 1 ? 'item' : 'items' }} remaining</strong>
            <span>{{ nextStep }}</span>
          </div>
        </div>

        <div class="tr-actionbar-right">
          <button type="button" class="tr-btn-outline" :disabled="saving" @click="saveDraft">
            <v-icon size="15">mdi-content-save-outline</v-icon>Save draft
          </button>
          <button type="button" class="tr-cta" :disabled="!canComplete || saving" @click="completeTriage">
            <v-icon size="16">mdi-check-circle</v-icon>Complete triage
          </button>
        </div>
      </div>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom" rounded="lg" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import {
  calculateNEWS2, news2Category, suggestedESIFromNEWS2,
  calculateBMI, bmiCategory,
} from '~/composables/useClinicalScoring'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const brand = useBranding()

const triageId = computed(() => route.params.id)
const patientId = computed(() => route.query.patient)
const patient = ref(null)
const activeMeds = ref([])
const doctors = ref([])
const doctorsLoading = ref(false)
const workloadLoading = ref(false)
const engagedWindow = ref(15)
const workloadTenantName = ref('')
const workloadCount = computed(() => doctors.value.length)
const startingConsult = ref(false)
const saving = ref(false)
const overrideConfirmed = ref(false)
const lastSave = ref('')
const now = ref(Date.now())

const open = reactive({ screening: false, nursing: false, notes: false })

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

// ── Brand bridge ─────────────────────────────────────────────────────
// Bound on the page root so sticky children inherit the hero palette.
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

// ── Live wait clock ──────────────────────────────────────────────────
let clockTimer = null
onMounted(() => { clockTimer = setInterval(() => { now.value = Date.now() }, 1000) })
onUnmounted(() => { if (clockTimer) clearInterval(clockTimer) })

const triageStartTime = ref(null)
const waitMinutes = computed(() => {
  if (!triageStartTime.value) return 0
  return Math.max(0, Math.floor((now.value - new Date(triageStartTime.value).getTime()) / 60000))
})
const waitTimeLabel = computed(() => {
  const mins = waitMinutes.value
  if (mins < 1) return 'Just started'
  if (mins < 60) return `${mins}m in triage`
  return `${Math.floor(mins / 60)}h ${mins % 60}m in triage`
})
const waitTimeColor = computed(() => {
  const m = waitMinutes.value
  if (m > 30) return 'error'
  if (m > 15) return 'warning'
  return 'success'
})

// ── Form state ───────────────────────────────────────────────────────
// NOTE: `watch(form, …)` below must stay after this declaration (TDZ guard).
const form = reactive({
  patient: null,
  nurse: null,
  chief_complaint: '',
  arrival_mode: 'walk_in',
  pain_scale: 0,
  avpu: 'alert',
  esi_level: null,
  suggested_esi: null,
  esi_override_reason: '',
  vital_signs: {
    temperature: null, bp_systolic: null, bp_diastolic: null,
    heart_rate: null, respiratory_rate: null, oxygen_saturation: null,
    blood_sugar: null, weight: null, height: null,
  },
  allergies_confirmed: false,
  allergies_updated: [],
  chronic_conditions_updated: [],
  medication_history: [],
  pregnancy_status: '',
  smoking_status: '',
  alcohol_use: '',
  substance_use: '',
  fall_risk: '',
  mental_health_screen: {},
  nursing_assessment: '',
  interventions: '',
  patient_education: '',
  notes: '',
  status: 'draft',
  news2_score: 0,
  bmi: null,
  doctor: null,
})

const arrivalModes = [
  { title: 'Walk-in', value: 'walk_in' },
  { title: 'Ambulance', value: 'ambulance' },
  { title: 'Referral', value: 'referral' },
  { title: 'Police', value: 'police' },
]

const avpuOptions = [
  { label: 'Alert', value: 'alert' },
  { label: 'Voice', value: 'voice', danger: true },
  { label: 'Pain', value: 'pain', danger: true },
  { label: 'Unresponsive', value: 'unresponsive', danger: true },
]

// ── Screening option sets ────────────────────────────────────────────
// Each option carries its own tone so a tap immediately reads as
// green / amber / red without a second lookup.
// Ordered least → most risk. `current` is kept as-is so existing records keep
// reading correctly; the newer values are additive.
const smokingOptions = [
  { title: 'Never', value: 'never', icon: 'mdi-smoking-off', tone: '#16a34a', desc: 'Never smoked' },
  { title: 'Passive', value: 'passive', icon: 'mdi-account-multiple-outline', tone: '#eab308', desc: 'Second-hand exposure only' },
  { title: 'Former', value: 'former', icon: 'mdi-history', tone: '#f59e0b', desc: 'Quit previously' },
  { title: 'Vaping', value: 'vaping', icon: 'mdi-weather-windy', tone: '#f97316', desc: 'E-cigarette or vape' },
  { title: 'Smokeless', value: 'smokeless', icon: 'mdi-leaf', tone: '#f97316', desc: 'Chewing / snuff' },
  { title: 'Some days', value: 'current_occasional', icon: 'mdi-smoking', tone: '#ea580c', desc: 'Smokes occasionally' },
  { title: 'Daily', value: 'current', icon: 'mdi-smoking', tone: '#dc2626', desc: 'Smokes every day' },
  { title: 'Unknown', value: 'unknown', icon: 'mdi-help-circle-outline', tone: '#94a3b8', desc: 'Not asked / declined' },
]
const alcoholOptions = [
  { title: 'None', value: 'none', icon: 'mdi-cup-off-outline', tone: '#16a34a', desc: 'Abstains' },
  { title: 'Occasional', value: 'occasional', icon: 'mdi-glass-wine', tone: '#22c55e', desc: 'Social only' },
  { title: 'Moderate', value: 'moderate', icon: 'mdi-beer-outline', tone: '#f59e0b', desc: 'Weekly intake' },
  { title: 'Heavy', value: 'heavy', icon: 'mdi-glass-mug-variant', tone: '#dc2626', desc: 'Daily / binge' },
]
const fallOptions = [
  { title: 'Low', value: 'low', icon: 'mdi-shield-check-outline', tone: '#16a34a', desc: 'No fall history, steady gait' },
  { title: 'Medium', value: 'medium', icon: 'mdi-shield-alert-outline', tone: '#f59e0b', desc: 'Age 65+, uses an aid' },
  { title: 'High', value: 'high', icon: 'mdi-shield-off-outline', tone: '#dc2626', desc: 'Fell in the last 12 months' },
]
const pregnancyOptions = [
  { title: 'Not pregnant', value: 'not_pregnant', icon: 'mdi-check-circle-outline', tone: '#16a34a', desc: 'Confirmed negative' },
  { title: 'Pregnant', value: 'pregnant', icon: 'mdi-baby-carriage', tone: '#3b82f6', desc: 'Confirmed positive' },
  { title: 'Unknown', value: 'unknown', icon: 'mdi-help-circle-outline', tone: '#f59e0b', desc: 'Not yet tested' },
  { title: 'N/A', value: 'not_applicable', icon: 'mdi-minus-circle-outline', tone: '#94a3b8', desc: 'Not applicable' },
]
const substanceOptions = [
  { title: 'None reported', value: 'none' },
  { title: 'Cannabis', value: 'cannabis' },
  { title: 'Opioids', value: 'opioids' },
  { title: 'Stimulants', value: 'stimulants' },
  { title: 'Injected drugs', value: 'intravenous' },
  { title: 'Inhalants', value: 'inhalants' },
  { title: 'Other', value: 'other' },
]

// PHQ-2 — the validated two-item depression screen (score range 0–6).
const phq2Questions = [
  { key: 'phq2_q1', text: 'Little interest or pleasure in doing things' },
  { key: 'phq2_q2', text: 'Feeling down, depressed, or hopeless' },
]
const phq2Scale = [
  { value: 0, title: 'Not at all' },
  { value: 1, title: 'Several days' },
  { value: 2, title: 'More than half the days' },
  { value: 3, title: 'Nearly every day' },
]

function optionMeta(list, value) {
  return list.find(o => o.value === value) || null
}
const smokingMeta = computed(() => optionMeta(smokingOptions, form.smoking_status))
const alcoholMeta = computed(() => optionMeta(alcoholOptions, form.alcohol_use))
const fallMeta = computed(() => optionMeta(fallOptions, form.fall_risk))
const pregnancyMeta = computed(() => optionMeta(pregnancyOptions, form.pregnancy_status))

// Pregnancy only makes sense on a female chart; unknown gender still shows it.
const showPregnancy = computed(() => {
  const g = String(patient.value?.gender || '').toLowerCase()
  return g === 'female' || g === 'f' || g === ''
})

/** Toggle a tile group — tapping the active option clears it. */
function toggleChoice(field, value) {
  form[field] = form[field] === value ? '' : value
}

// ── PHQ-2 ────────────────────────────────────────────────────────────
function phqAnswer(key) {
  const v = (form.mental_health_screen || {})[key]
  return typeof v === 'number' ? v : null
}
function setPhq(key, value) {
  const base = (form.mental_health_screen && typeof form.mental_health_screen === 'object')
    ? { ...form.mental_health_screen }
    : {}
  base[key] = base[key] === value ? null : value
  // Replace wholesale so the deep auto-save watcher always sees the change.
  form.mental_health_screen = base
}

const phq2Answers = computed(() => phq2Questions.map(q => phqAnswer(q.key)))
const phq2Complete = computed(() => phq2Answers.value.every(v => typeof v === 'number'))
const phq2Score = computed(() => phq2Answers.value.reduce((sum, v) => sum + (typeof v === 'number' ? v : 0), 0))
const phq2Positive = computed(() => phq2Complete.value && phq2Score.value >= 3)
const phq2Tone = computed(() => {
  if (!phq2Complete.value) return 'is-idle'
  if (phq2Score.value >= 5) return 'is-bad'
  if (phq2Score.value >= 3) return 'is-warn'
  return 'is-ok'
})
const phq2Interpretation = computed(() => {
  if (!phq2Complete.value) return ''
  return phq2Positive.value
    ? 'Positive screen (≥ 3) — consider a full PHQ-9 and a mental-health referral'
    : 'Negative screen — no further depression screening indicated today'
})

// ── Screening completion + raised flags ──────────────────────────────
const screeningItems = computed(() => {
  const items = [
    { key: 'smoking', done: !!form.smoking_status },
    { key: 'alcohol', done: !!form.alcohol_use },
    { key: 'substance', done: !!form.substance_use },
    { key: 'fall', done: !!form.fall_risk },
  ]
  if (showPregnancy.value) items.push({ key: 'pregnancy', done: !!form.pregnancy_status })
  items.push({ key: 'phq2', done: phq2Complete.value })
  return items
})
const screeningDone = computed(() => screeningItems.value.filter(i => i.done).length)
const screeningTotal = computed(() => screeningItems.value.length)
const screeningComplete = computed(() => screeningDone.value === screeningTotal.value)
// Everything the nurse has not answered yet, for the collapsed-card hint.
const screeningMissing = computed(() => screeningItems.value.filter(i => !i.done).length)
const SMOKER_VALUES = ['current', 'current_occasional', 'vaping', 'smokeless']

const screeningFlags = computed(() => {
  const flags = []
  if (SMOKER_VALUES.includes(form.smoking_status)) {
    const meta = optionMeta(smokingOptions, form.smoking_status)
    flags.push({
      label: form.smoking_status === 'current'
        ? 'Daily smoker'
        : `Tobacco use · ${meta ? meta.title : form.smoking_status}`,
      tone: '#dc2626',
      icon: 'mdi-smoking',
    })
  }
  if (form.alcohol_use === 'heavy') {
    flags.push({ label: 'Heavy alcohol use', tone: '#dc2626', icon: 'mdi-glass-mug-variant' })
  }
  if (form.fall_risk === 'high') {
    flags.push({ label: 'High fall risk', tone: '#dc2626', icon: 'mdi-shield-off-outline' })
  }
  if (form.substance_use && form.substance_use !== 'none') {
    const meta = optionMeta(substanceOptions, form.substance_use)
    flags.push({ label: `Substance use · ${meta ? meta.title : form.substance_use}`, tone: '#f59e0b', icon: 'mdi-flask-outline' })
  }
  if (phq2Positive.value) {
    flags.push({ label: 'Positive PHQ-2', tone: '#f59e0b', icon: 'mdi-emoticon-sad-outline' })
  }
  return flags
})

// ESI reference — the target times match the standard 5-level triage scale.
const esiLevels = [
  { level: 1, label: 'Resuscitation', target: 'Immediate', color: '#dc2626', desc: 'Dying — needs immediate life-saving intervention' },
  { level: 2, label: 'Emergent', target: '≤ 10 min', color: '#ea580c', desc: 'High risk, confused, severe pain or distress' },
  { level: 3, label: 'Urgent', target: '≤ 30 min', color: '#f59e0b', desc: 'Stable, needs two or more resources' },
  { level: 4, label: 'Less urgent', target: '≤ 60 min', color: '#3b82f6', desc: 'Stable, needs one resource' },
  { level: 5, label: 'Non-urgent', target: '≤ 120 min', color: '#22c55e', desc: 'Stable, examination only' },
]

// ── Auto-save (debounced) ────────────────────────────────────────────
let saveTimer = null
let firstLoad = true
// Flipped off the moment completion starts. A debounced save that fires after
// the complete request would otherwise PATCH the record straight back to draft.
let autoSaveEnabled = true

function cancelPendingSave() {
  autoSaveEnabled = false
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null }
}

watch(form, () => {
  if (firstLoad) { firstLoad = false; return }
  if (!autoSaveEnabled) return
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = setTimeout(autoSave, 5000)
}, { deep: true, flush: 'post' })

function buildPayload(status) {
  // `status` lives on the form so the UI can show "Draft"/"Completed", but it
  // must never ride along with a generic PATCH — that is what silently reverted
  // completed triages back to draft. Transitions go through explicit actions.
  const { status: _status, ...fields } = form
  const payload = {
    ...fields,
    news2_score: news2Score.value,
    suggested_esi: suggestedESI.value,
    bmi: bmi.value,
    // Persist the derived PHQ-2 result alongside the raw answers so the record
    // is self-describing when read outside this UI.
    mental_health_screen: {
      ...(form.mental_health_screen && typeof form.mental_health_screen === 'object'
        ? form.mental_health_screen
        : {}),
      phq2_score: phq2Complete.value ? phq2Score.value : null,
      phq2_positive: phq2Complete.value ? phq2Positive.value : null,
    },
  }
  if (status) payload.status = status
  return payload
}

async function autoSave() {
  if (!autoSaveEnabled) return
  if (!triageId.value || triageId.value === 'new') return
  try {
    await $api.patch(`/triage/${triageId.value}/`, buildPayload())
    lastSave.value = 'just now'
    setTimeout(() => { if (lastSave.value === 'just now') lastSave.value = '10s ago' }, 10000)
    setTimeout(() => { if (lastSave.value === '10s ago') lastSave.value = '20s ago' }, 20000)
    setTimeout(() => { if (lastSave.value === '20s ago') lastSave.value = '30s ago' }, 30000)
  } catch (e) { console.error('Auto-save failed', e) }
}

// ── Scoring ──────────────────────────────────────────────────────────
// AVPU lives beside `vital_signs` in the form model but is part of the NEWS2
// calculation, so it is merged in here rather than silently ignored.
const news2Score = computed(() => calculateNEWS2({ ...form.vital_signs, avpu: form.avpu }))
const news2Cat = computed(() => news2Category(news2Score.value))
const suggestedESI = computed(() => suggestedESIFromNEWS2(news2Score.value))
const bmi = computed(() => form.bmi || calculateBMI(form.vital_signs.weight, form.vital_signs.height))

// 7 is the top of the NEWS2 scale that matters for escalation.
const news2Pct = computed(() => Math.min(100, Math.round((news2Score.value / 7) * 100)))
const news2Hex = computed(() => {
  const s = news2Score.value
  if (s >= 7) return '#dc2626'
  if (s >= 5) return '#ea580c'
  if (s >= 1) return '#f59e0b'
  return '#22c55e'
})
const news2Color = computed(() => (news2Score.value >= 7 ? 'error' : news2Score.value >= 5 ? 'orange' : news2Score.value >= 1 ? 'warning' : 'success'))

const esiMeta = computed(() => esiLevels.find(e => e.level === Number(form.esi_level)) || null)
const esiHex = computed(() => (esiMeta.value ? esiMeta.value.color : 'rgba(var(--v-theme-on-surface), 0.25)'))
const esiTone = computed(() => {
  const map = { 1: 'error', 2: 'error', 3: 'warning', 4: 'info', 5: 'success' }
  return map[Number(form.esi_level)] || 'muted'
})

function pickESI(level) {
  form.esi_level = level
  // Returning to the suggested level cancels the override workflow.
  if (level === suggestedESI.value) {
    overrideConfirmed.value = false
    form.esi_override_reason = ''
  }
}

// Each abnormal value carries a plain-language finding plus the immediate
// nursing action, so the alert is actionable rather than just descriptive.
// `severity` drives colour: critical values are ones that can deteriorate fast.
const ABNORMAL_RULES = [
  {
    key: 'temperature', label: 'Temperature', unit: '°C', severity: 'critical',
    low: 35, high: 38.5,
    lowText: 'Hypothermia', lowNote: 'Core temp below 35 °C — rewarm actively, check capillary glucose and consider sepsis.',
    highText: 'Fever', highNote: 'Pyrexia above 38.5 °C — give an antipyretic, screen for sepsis, consider cultures before antibiotics.',
  },
  {
    key: 'bp_systolic', label: 'Systolic BP', unit: 'mmHg', severity: 'critical',
    low: 90, high: 180,
    lowText: 'Hypotension', lowNote: 'Below 90 mmHg — lay the patient flat, raise the legs, secure IV access and reassess perfusion.',
    highText: 'Hypertensive urgency', highNote: 'Above 180 mmHg — repeat after 5 minutes rest and notify the clinician now.',
  },
  {
    key: 'heart_rate', label: 'Pulse', unit: 'bpm', severity: 'warning',
    low: 50, high: 120,
    lowText: 'Bradycardia', lowNote: 'Below 50 bpm — obtain a 12-lead ECG and ask about dizziness, syncope or beta-blocker use.',
    highText: 'Tachycardia', highNote: 'Above 120 bpm — obtain an ECG and assess fluid status, pain and temperature.',
  },
  {
    key: 'respiratory_rate', label: 'Resp rate', unit: '/min', severity: 'critical',
    low: 10, high: 25,
    lowText: 'Bradypnoea', lowNote: 'Below 10 /min — assess airway and ventilation; consider opioid effect and reversal.',
    highText: 'Tachypnoea', highNote: 'Above 25 /min — sit the patient upright, recheck SpO₂ and prepare oxygen.',
  },
  {
    key: 'oxygen_saturation', label: 'SpO₂', unit: '%', severity: 'critical',
    low: 92, high: null,
    lowText: 'Hypoxaemia', lowNote: 'Below 92 % — apply oxygen titrated to 94–98 %, sit upright and reassess within 5 minutes.',
    highText: '', highNote: '',
  },
]

const abnormalVitals = computed(() => {
  const v = form.vital_signs
  const out = []
  for (const rule of ABNORMAL_RULES) {
    const raw = v[rule.key]
    if (raw === null || raw === undefined || raw === '') continue
    const n = Number(raw)
    if (!Number.isFinite(n)) continue

    const low = rule.low !== null && n < rule.low
    const high = rule.high !== null && n > rule.high
    if (!low && !high) continue

    out.push({
      key: rule.key,
      label: rule.label,
      value: `${n} ${rule.unit}`,
      direction: low ? 'low' : 'high',
      finding: low ? rule.lowText : rule.highText,
      note: low ? rule.lowNote : rule.highNote,
      severity: rule.severity,
      arrow: low ? 'mdi-arrow-down-bold' : 'mdi-arrow-up-bold',
    })
  }
  return out
})

/** One-line summary used by the rail badge. */
const abnormalVitalNames = computed(() =>
  abnormalVitals.value.map(a => `${a.label} ${a.direction === 'low' ? 'low' : 'high'}`))

const criticalVitalCount = computed(() =>
  abnormalVitals.value.filter(a => a.severity === 'critical').length)

// Physiological limits mirrored from the VitalInput props. Anything outside
// these is not a measurement at all (SpO₂ 111%, systolic 0), so it is surfaced
// separately from merely "abnormal" values — and blocks completion.
const VITAL_BOUNDS = {
  temperature: { label: 'Temperature', min: 30, max: 45 },
  bp_systolic: { label: 'Systolic BP', min: 40, max: 300 },
  bp_diastolic: { label: 'Diastolic BP', min: 20, max: 200 },
  heart_rate: { label: 'Pulse', min: 20, max: 300 },
  respiratory_rate: { label: 'Resp rate', min: 4, max: 80 },
  oxygen_saturation: { label: 'SpO₂', min: 50, max: 100 },
  blood_sugar: { label: 'Blood sugar', min: 0.5, max: 50 },
  weight: { label: 'Weight', min: 0.5, max: 500 },
  height: { label: 'Height', min: 20, max: 250 },
}

const impossibleVitals = computed(() => {
  const v = form.vital_signs
  const bad = []
  for (const [key, b] of Object.entries(VITAL_BOUNDS)) {
    const raw = v[key]
    if (raw === null || raw === undefined || raw === '') continue
    const n = Number(raw)
    if (!Number.isFinite(n)) continue
    if (n < b.min || n > b.max) bad.push(`${b.label} ${n}`)
  }
  return bad
})

// True while the nurse's level is above the system suggestion. The panel stays
// visible after confirmation so the override remains auditable on screen.
const isOverriding = computed(() => {
  if (!form.esi_level || !suggestedESI.value) return false
  return form.esi_level > suggestedESI.value
})
const showOverrideWarning = computed(() => isOverriding.value && !overrideConfirmed.value)

// ── Patient identity ─────────────────────────────────────────────────
const patientName = computed(() => {
  if (!patient.value) return ''
  const u = patient.value.user
  return `${u?.first_name || ''} ${u?.last_name || ''}`.trim() || patient.value.user_name || ''
})
const initials = computed(() => {
  const parts = patientName.value.trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return ''
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase()
})
const patientAge = computed(() => {
  if (!patient.value?.date_of_birth) return '—'
  const d = new Date(patient.value.date_of_birth)
  return `${Math.floor((Date.now() - d) / 315576000000)}y`
})
const arrivalModeLabel = computed(() => {
  const hit = arrivalModes.find(a => a.value === form.arrival_mode)
  return hit ? hit.title : 'Walk-in'
})
const heroMeta = computed(() => {
  const p = patient.value
  const out = []
  if (p?.gender) {
    const g = String(p.gender)
    out.push(g.charAt(0).toUpperCase() + g.slice(1))
  }
  if (patientAge.value !== '—') out.push(patientAge.value)
  if (p?.blood_type) out.push(`Blood ${p.blood_type}`)
  if (p?.patient_number) out.push(p.patient_number)
  out.push(arrivalModeLabel.value)
  return out
})
const statusLabel = computed(() => (form.status === 'completed' ? 'Completed' : 'Draft in progress'))

const allergyList = computed(() => form.allergies_updated || [])
const conditionList = computed(() => form.chronic_conditions_updated || [])

// Section completion flags driving the "Required / Captured" badges.
const complaintDone = computed(() => !!String(form.chief_complaint || '').trim())
const vitalsDone = computed(() => !!(form.vital_signs.temperature && form.vital_signs.heart_rate))

// ── Clinical catalogs (mirror the front-desk register fields) ────────
// Both lists come from the clinic's own tenant catalog so the nurse picks the
// same vocabulary the clinical catalog pages manage. Free text is still
// allowed for one-off findings.
const allergyOptions = ref([])
const conditionOptions = ref([])
const catalogLoading = ref(false)

function prettyCategory(c) {
  return String(c || '').replace(/_/g, ' ')
}

// Renders the category as a second line inside the dropdown.
function clinicalItemProps(item) {
  return item?.subtitle ? { subtitle: item.subtitle } : {}
}

/**
 * Coerce whatever Vuetify puts in the model into a clean array of name strings.
 *
 * With object `items` + `item-props`, VCombobox can hand back the whole option
 * object on selection. Storing that would persist `{title, value, subtitle}`
 * into `Triage.allergies_updated` and render as JSON on the patient chart — so
 * every write is normalised here.
 */
function toNameList(value) {
  const arr = Array.isArray(value) ? value : (value ? [value] : [])
  const out = []
  for (const v of arr) {
    const name = typeof v === 'string' ? v : (v?.value ?? v?.title ?? '')
    const clean = String(name).trim()
    if (clean && !out.some(n => n.toLowerCase() === clean.toLowerCase())) out.push(clean)
  }
  return out
}

const allergiesModel = computed({
  get: () => toNameList(form.allergies_updated),
  set: (v) => { form.allergies_updated = toNameList(v) },
})
const conditionsModel = computed({
  get: () => toNameList(form.chronic_conditions_updated),
  set: (v) => { form.chronic_conditions_updated = toNameList(v) },
})

async function loadClinicalCatalogs() {
  catalogLoading.value = true
  try {
    const [allergyRes, conditionRes] = await Promise.all([
      $api.get('/clinic-catalog/allergies/', {
        params: { page_size: 500, ordering: 'name', is_active: 'True' },
      }),
      $api.get('/clinic-catalog/chronic-conditions/', {
        params: { page_size: 500, ordering: 'name', is_active: 'True' },
      }),
    ])
    const rows = (payload) => (Array.isArray(payload) ? payload : (payload?.results || []))
    allergyOptions.value = rows(allergyRes.data).map(a => ({
      title: a.name,
      value: a.name,
      subtitle: prettyCategory(a.category),
    }))
    conditionOptions.value = rows(conditionRes.data).map(c => ({
      title: c.name,
      value: c.name,
      subtitle: c.icd_code
        ? `${prettyCategory(c.category)} · ${c.icd_code}`
        : prettyCategory(c.category),
    }))
  } catch {
    // Non-critical: both comboboxes still accept free text.
  } finally {
    catalogLoading.value = false
  }
}

// ── Pain scale helpers ───────────────────────────────────────────────
function painWord(v) {
  const n = Number(v) || 0
  if (n === 0) return 'No pain'
  if (n <= 3) return 'Mild'
  if (n <= 6) return 'Moderate'
  if (n <= 8) return 'Severe'
  return 'Worst imaginable'
}
const painLabel = computed(() => painWord(form.pain_scale))
function painColor(v) {
  const n = Number(v) || 0
  if (n === 0) return '#22c55e'
  if (n <= 3) return '#84cc16'
  if (n <= 6) return '#f59e0b'
  if (n <= 8) return '#ea580c'
  return '#dc2626'
}

// ── Readiness model ──────────────────────────────────────────────────
// `canComplete` is derived from this list so the rail, the hero progress and
// the action bar can never disagree with the submit guard.
const readiness = computed(() => {
  const items = [
    { key: 'complaint', label: 'Chief complaint', hint: 'required', done: !!String(form.chief_complaint || '').trim() },
    { key: 'temp', label: 'Temperature', hint: 'required', done: !!form.vital_signs.temperature },
    { key: 'pulse', label: 'Pulse', hint: 'required', done: !!form.vital_signs.heart_rate },
    // Values outside the physiological bounds cannot be signed off.
    { key: 'vitals-range', label: 'Vitals in range', hint: 'required', done: impossibleVitals.value.length === 0 },
    { key: 'esi', label: 'ESI level', hint: 'required', done: !!form.esi_level },
    { key: 'allergies', label: 'Allergies confirmed', hint: 'required', done: !!form.allergies_confirmed },
    { key: 'screening', label: 'Screening completed', hint: 'required', done: screeningComplete.value },
    { key: 'doctor', label: 'Clinician assigned', hint: 'required', done: !!form.doctor },
  ]
  if (isOverriding.value) {
    items.push({ key: 'override', label: 'Override reason', hint: 'required', done: !!overrideConfirmed.value })
  }
  return items
})
const REQUIRED_KEYS = ['complaint', 'temp', 'pulse', 'vitals-range', 'esi', 'allergies', 'screening', 'doctor', 'override']
const canComplete = computed(() => readiness.value.every(i => !REQUIRED_KEYS.includes(i.key) || i.done))
const readinessDone = computed(() => readiness.value.filter(i => i.done).length)
const completionPct = computed(() => {
  const total = readiness.value.length
  return total ? Math.round((readinessDone.value / total) * 100) : 0
})
const remainingCount = computed(() => readiness.value.filter(i => !i.done && i.hint === 'required').length)
const nextStep = computed(() => {
  const missing = readiness.value.find(i => !i.done && REQUIRED_KEYS.includes(i.key))
  if (!missing) return 'All required fields captured'
  return `Next: ${missing.label.toLowerCase()}`
})

// ── Vitals snapshot (rail) ───────────────────────────────────────────
function vitalStatus(value, lo, hi) {
  if (!value) return 'none'
  return value < lo || value > hi ? 'bad' : 'ok'
}
const vitalSnapshot = computed(() => {
  const v = form.vital_signs
  return [
    { key: 'temp', label: 'Temperature', text: v.temperature ? `${v.temperature} °C` : '—', status: vitalStatus(v.temperature, 36.1, 38) },
    { key: 'bp', label: 'Blood pressure', text: v.bp_systolic ? `${v.bp_systolic}/${v.bp_diastolic ?? '—'}` : '—', status: vitalStatus(v.bp_systolic, 110, 140) },
    { key: 'hr', label: 'Pulse', text: v.heart_rate ? `${v.heart_rate} bpm` : '—', status: vitalStatus(v.heart_rate, 60, 100) },
    { key: 'rr', label: 'Resp. rate', text: v.respiratory_rate ? `${v.respiratory_rate} /min` : '—', status: vitalStatus(v.respiratory_rate, 12, 20) },
    { key: 'spo2', label: 'SpO₂', text: v.oxygen_saturation ? `${v.oxygen_saturation} %` : '—', status: vitalStatus(v.oxygen_saturation, 95, 100) },
  ]
})
const bmiHint = computed(() => {
  const c = bmiCategory(bmi.value)
  return c ? c.label : ''
})

// ── Mutations ────────────────────────────────────────────────────────
function updateBMI() {
  form.bmi = calculateBMI(form.vital_signs.weight, form.vital_signs.height)
}

function addMed() {
  form.medication_history.push({ name: '', dose: '', frequency: '' })
}

const assignedDoctorName = computed(() => {
  if (!form.doctor) return ''
  const d = doctors.value.find(x => x.id === form.doctor)
  return d ? d.full_name : (form.doctor_name || '')
})

// ── Handoff workload ─────────────────────────────────────────────────
// `GET /triage/doctor-workload/` returns one row per clinician with queue
// counts and an engagement flag derived from the audit log (JWTs mean Django
// sessions are empty, so `last_login` would always read as stale).
const selectedDoctor = computed(() =>
  doctors.value.find(d => d.id === form.doctor) || null)

const suggestedDoctor = computed(() =>
  doctors.value.find(d => d.recommended) || null)

const engagedCount = computed(() => doctors.value.filter(d => d.engaged).length)

const ROLE_LABELS = {
  doctor: 'Doctor',
  clinical_officer: 'Clinical officer',
  dentist: 'Dentist',
  midwife: 'Midwife',
  nurse: 'Nurse',
}
function roleLabel(role) {
  return ROLE_LABELS[role] || String(role || 'Clinician').replace(/_/g, ' ')
}

function presenceText(d) {
  if (!d) return ''
  if (d.presence === 'in_consult') return 'In consultation'
  if (d.engaged) return 'Engaged now'
  const m = d.last_seen_minutes
  if (m === null || m === undefined) return 'Not signed in today'
  if (m < 1) return 'Active just now'
  if (m < 60) return `Idle ${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return `Idle ${h}h`
  return `Idle ${Math.floor(h / 24)}d`
}

function initialsOf(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return ''
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase()
}

// Five segments: filled ones are the doctor's load, split into consultations
// in flight vs patients physically waiting.
function loadSegments(d) {
  return Math.min(5, Math.max(0, d.load || 0))
}
function queueTone(d) {
  if (!d.load) return 'is-free'
  if (d.load <= 1) return 'is-light'
  if (d.load <= 3) return 'is-busy'
  return 'is-heavy'
}

const suggestionReason = computed(() => {
  const d = suggestedDoctor.value
  if (!d) return ''
  const bits = []
  bits.push(d.load === 0 ? 'Empty queue' : `${d.load} in queue`)
  if (d.in_progress) bits.push(`${d.in_progress} in consult`)
  bits.push(d.engaged ? 'engaged now' : presenceText(d).toLowerCase())
  return bits.join(' · ')
})

async function loadWorkload() {
  workloadLoading.value = true
  try {
    const { data } = await $api.get('/triage/doctor-workload/')
    doctors.value = data.results || []
    if (data.engaged_window_minutes) engagedWindow.value = data.engaged_window_minutes
    workloadTenantName.value = data.tenant?.name || ''
  } catch (e) {
    console.error('Failed to load clinician workload', e)
    // Fall back to the plain staff list so the field still works.
    try {
      const { data } = await $api.get('/auth/staff/', {
        params: { roles: 'doctor,clinical_officer,dentist,midwife', page_size: 1000 },
      })
      doctors.value = (data.results || []).map(u => ({
        ...u, waiting: 0, in_progress: 0, load: 0, engaged: false,
        last_seen_minutes: null, recommended: false,
      }))
    } catch { /* the rail shows an empty state */ }
  } finally {
    workloadLoading.value = false
  }
}

// ── Persistence ──────────────────────────────────────────────────────
async function saveDraft() {
  saving.value = true
  try {
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/`, buildPayload())
      lastSave.value = 'just now'
      notify('Draft saved')
    } else {
      const { data } = await $api.post('/triage/', buildPayload())
      router.replace(`/clinics/triage/workspace/${data.id}`)
      notify('Draft created')
    }
  } catch (e) {
    console.error('Save draft failed', e)
    notify('Could not save the draft', 'error')
  } finally {
    saving.value = false
  }
}

async function completeTriage() {
  // Kill the pending debounce first — otherwise it fires after the complete
  // request and reverts the record to draft.
  cancelPendingSave()
  saving.value = true
  try {
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/complete/`, buildPayload('completed'))
      await router.push('/clinics/triage')
    } else {
      const { data } = await $api.post('/triage/', buildPayload())
      await $api.patch(`/triage/${data.id}/complete/`, buildPayload('completed'))
      await router.push('/clinics/triage')
    }
  } catch (e) {
    console.error('Complete triage failed', e)
    // Re-arm auto-save so the nurse does not silently lose edits on failure.
    autoSaveEnabled = true
    notify('Could not complete triage', 'error')
  } finally {
    saving.value = false
  }
}

async function startConsultation() {
  if (!form.doctor) return
  startingConsult.value = true
  try {
    // Save first so the assignment survives even if navigation is aborted.
    if (triageId.value && triageId.value !== 'new') {
      await $api.patch(`/triage/${triageId.value}/`, buildPayload())
    }
    const { data } = await $api.get('/consultations/', { params: { triage: triageId.value, page_size: 1 } })
    if (data.results?.length) {
      router.push(`/clinics/consultations/workspace/${data.results[0].id}`)
    } else {
      const { data: consult } = await $api.post('/consultations/', {
        patient: form.patient,
        triage: Number(triageId.value),
        doctor: form.doctor,
        chief_complaint: form.chief_complaint || '',
        vital_signs: form.vital_signs,
        status: 'draft',
      })
      router.push(`/clinics/consultations/workspace/${consult.id}`)
    }
  } catch (e) {
    console.error('Failed to start consultation', e)
    notify('Could not start the consultation', 'error')
  } finally {
    startingConsult.value = false
  }
}

// ── Load ─────────────────────────────────────────────────────────────
onMounted(async () => {
  if (patientId.value) form.patient = Number(patientId.value)

  if (triageId.value && triageId.value !== 'new') {
    try {
      const { data } = await $api.get(`/triage/${triageId.value}/`)
      Object.assign(form, data)
      if (data.vital_signs) Object.assign(form.vital_signs, data.vital_signs)
      if (data.triage_time) triageStartTime.value = data.triage_time
      if (data.doctor) form.doctor = data.doctor
      // A persisted override reason means this override was already accepted —
      // the confirmation flag itself is client-only.
      if (String(data.esi_override_reason || '').trim()) overrideConfirmed.value = true
    } catch (e) { console.error('Failed to load triage', e) }
  }

  if (form.patient) {
    try {
      const { data } = await $api.get(`/patients/${form.patient}/`)
      patient.value = data
      if (!form.allergies_updated.length && data.allergies) form.allergies_updated = [...data.allergies]
      if (!form.chronic_conditions_updated.length && data.chronic_conditions) {
        form.chronic_conditions_updated = [...data.chronic_conditions]
      }
    } catch (e) { console.error('Failed to load patient', e) }

    try {
      const { data } = await $api.get('/prescriptions/', { params: { patient: form.patient, page_size: 100 } })
      activeMeds.value = data.results?.filter(p => p.status === 'active' || p.status === 'sent_to_exchange') || []
      if (!form.medication_history.length) {
        form.medication_history = activeMeds.value.map(p => ({
          name: p.items?.[0]?.medication_name || '—',
          dose: p.items?.[0]?.dosage || '',
          frequency: p.items?.[0]?.frequency || '',
        }))
      }
    } catch { /* medications are optional context */ }
  }

  // Clinicians with live workload — replaces the plain staff list so the rail
  // can show queues and engagement.
  loadWorkload()

  loadClinicalCatalogs()
})
</script>

<style scoped>
/* ══ Page shell ══════════════════════════════════════════════════════ */
.tr-page {
  width: 100%;
  padding-bottom: 24px;
}

/* ══ Critical allergy strip ══════════════════════════════════════════ */
.tr-critical {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 11px 16px;
  margin-bottom: 14px;
  border-radius: 14px;
  color: #fff;
  background: linear-gradient(100deg, #b91c1c 0%, #dc2626 55%, #ef4444 100%);
  box-shadow: 0 10px 26px rgba(185, 28, 28, 0.28);
  overflow: hidden;
}
.tr-critical::after {
  content: '';
  position: absolute;
  inset: 0;
  background: repeating-linear-gradient(
    -45deg,
    rgba(255, 255, 255, 0.07) 0 10px,
    transparent 10px 20px
  );
  pointer-events: none;
}
.tr-critical-icon {
  width: 34px; height: 34px;
  border-radius: 10px;
  display: grid; place-items: center;
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.3);
  flex-shrink: 0;
}
.tr-critical-text { min-width: 0; flex: 1; }
.tr-critical-eyebrow {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.1px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.82);
}
.tr-critical-body {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.35;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-critical-count {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 700;
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

/* ══ Hero ════════════════════════════════════════════════════════════ */
.tr-hero {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
  padding: 18px 20px 14px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #1e3a8a) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #60a5fa) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
  margin-bottom: 16px;
}
.tr-hero-glow {
  position: absolute;
  width: 360px; height: 360px;
  border-radius: 50%;
  right: -120px; top: -190px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.tr-hero-glow-2 {
  right: auto; left: -150px; top: auto; bottom: -240px;
  width: 320px; height: 320px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(96, 165, 250, 0.24)), transparent 70%);
}
.tr-hero-top {
  position: relative;
  display: flex;
  align-items: center;
  gap: 14px;
}
.tr-back { color: rgba(255, 255, 255, 0.85); flex-shrink: 0; }
.tr-back:hover { color: #fff; background: rgba(255, 255, 255, 0.12); }
.tr-hero-avatar {
  width: 54px; height: 54px;
  border-radius: 16px;
  display: grid; place-items: center;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: 0.5px;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.tr-hero-id { min-width: 0; flex: 1; }
.tr-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.3px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.72);
}
.tr-patient {
  font-size: 24px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.3px;
  margin: 3px 0 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0;
  font-size: 12.5px;
  color: rgba(255, 255, 255, 0.8);
}
.tr-meta span + span::before {
  content: '·';
  margin: 0 7px;
  opacity: 0.55;
}

.tr-hero-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.tr-glass,
.tr-solid {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 38px;
  padding: 0 15px;
  border-radius: 11px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: transform 0.15s ease, background 0.18s ease, opacity 0.15s ease;
  white-space: nowrap;
}
.tr-glass {
  color: #fff;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.32);
  backdrop-filter: blur(6px);
}
.tr-glass:hover:not(:disabled) { background: rgba(255, 255, 255, 0.26); transform: translateY(-1px); }
.tr-solid {
  color: var(--hero-ink, #1e3a8a);
  background: #fff;
  border: 1px solid #fff;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.16);
}
.tr-solid:hover:not(:disabled) { transform: translateY(-1px); }
.tr-glass:disabled,
.tr-solid:disabled { opacity: 0.45; cursor: not-allowed; }

.tr-hero-foot {
  position: relative;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 7px;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.tr-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 700;
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(4px);
}
.tr-chip--muted { opacity: 0.78; font-weight: 600; }
.tr-chip.is-error { background: rgba(220, 38, 38, 0.85); border-color: rgba(255, 255, 255, 0.42); }
.tr-chip.is-warning { background: rgba(245, 158, 11, 0.85); border-color: rgba(255, 255, 255, 0.42); }
.tr-chip.is-orange { background: rgba(234, 88, 12, 0.85); border-color: rgba(255, 255, 255, 0.42); }
.tr-chip.is-info { background: rgba(59, 130, 246, 0.85); border-color: rgba(255, 255, 255, 0.42); }
.tr-chip.is-success { background: rgba(34, 197, 94, 0.8); border-color: rgba(255, 255, 255, 0.42); }
.tr-chip.is-muted { opacity: 0.72; }

.tr-pulse {
  width: 7px; height: 7px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 0 0 0 rgba(255, 255, 255, 0.7);
  animation: trPulse 1.8s infinite;
}
@keyframes trPulse {
  0% { box-shadow: 0 0 0 0 rgba(255, 255, 255, 0.65); }
  70% { box-shadow: 0 0 0 7px rgba(255, 255, 255, 0); }
  100% { box-shadow: 0 0 0 0 rgba(255, 255, 255, 0); }
}

.tr-hero-progress {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}
.tr-hero-progress-bar {
  width: 110px;
  height: 6px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.22);
  overflow: hidden;
}
.tr-hero-progress-bar span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: #fff;
  transition: width 0.35s ease;
}
.tr-hero-progress-label {
  font-size: 11px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.88);
  white-space: nowrap;
}

/* ══ Grid ════════════════════════════════════════════════════════════ */
.tr-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 336px;
  gap: 16px;
  align-items: start;
}
.tr-main { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
.tr-rail {
  position: sticky;
  top: 78px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

/* ══ Card ════════════════════════════════════════════════════════════ */
.tr-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 16px;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  overflow: hidden;
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.tr-card:hover { border-color: rgba(var(--v-theme-on-surface), 0.14); }
.tr-card--rail { border-radius: 15px; }

.tr-card-head {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 13px 16px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
}
.tr-card-head--tight { padding: 11px 14px; }
.tr-card-head--btn {
  width: 100%;
  text-align: left;
  cursor: pointer;
  font: inherit;
  color: inherit;
  background: none;
  border-left: 0; border-right: 0; border-top: 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tr-card-head--btn:hover { background: rgba(var(--v-theme-on-surface), 0.035); }
.tr-chev { opacity: 0.4; }

.tr-card-icon {
  width: 34px; height: 34px;
  border-radius: 10px;
  display: grid; place-items: center;
  flex-shrink: 0;
}
.tr-card-icon.is-primary { background: color-mix(in srgb, var(--hero-main, #2f6dff) 13%, transparent); color: var(--hero-ink, #1e3a8a); }
.tr-card-icon.is-error { background: rgba(220, 38, 38, 0.1); color: #dc2626; }
.tr-card-icon.is-warning { background: rgba(245, 158, 11, 0.13); color: #b45309; }
.tr-card-icon.is-purple { background: rgba(147, 51, 234, 0.1); color: #9333ea; }
.tr-card-icon.is-teal { background: rgba(13, 148, 136, 0.1); color: #0d9488; }
.tr-card-icon.is-indigo { background: rgba(79, 70, 229, 0.1); color: #4f46e5; }
.tr-card-icon.is-grey { background: rgba(var(--v-theme-on-surface), 0.07); color: rgba(var(--v-theme-on-surface), 0.6); }
.tr-card-icon.is-success { background: rgba(34, 197, 94, 0.12); color: #16a34a; }
.tr-card-icon.is-blue { background: rgba(59, 130, 246, 0.11); color: #2563eb; }

.tr-card-titles { min-width: 0; flex: 1; }
.tr-card-titles h2 {
  font-size: 14px;
  font-weight: 800;
  letter-spacing: -0.1px;
  margin: 0;
  line-height: 1.3;
}
.tr-card-titles p {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin: 1px 0 0;
  line-height: 1.35;
}

.tr-req {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  padding: 3px 9px;
  border-radius: 999px;
  color: #b45309;
  background: rgba(245, 158, 11, 0.12);
  border: 1px solid rgba(245, 158, 11, 0.24);
}
.tr-req.done {
  color: #15803d;
  background: rgba(34, 197, 94, 0.12);
  border-color: rgba(34, 197, 94, 0.26);
}

.tr-card-body { padding: 16px; }
.tr-card--rail .tr-card-body { padding: 14px; }

.tr-subblock + .tr-subblock { margin-top: 0; }
.tr-subblock--gap { margin-top: 16px; }
.tr-subhead {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 9px;
}
.tr-mini-label {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.46);
}
.tr-count {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 7px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.tr-divider {
  height: 1px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  margin: 14px 0;
}
.tr-empty {
  font-size: 12.5px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  padding: 10px 0 2px;
}

/* ══ Chief complaint ═════════════════════════════════════════════════ */
.tr-split {
  display: grid;
  grid-template-columns: 210px minmax(0, 1fr);
  gap: 16px;
  align-items: start;
  margin-top: 14px;
}

.tr-pain { min-width: 0; }
.tr-pain-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 5px;
}
.tr-pain-value {
  font-size: 13px;
  font-weight: 800;
  display: inline-flex;
  align-items: baseline;
  gap: 5px;
}
.tr-pain-value em {
  font-style: normal;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  opacity: 0.75;
}
.tr-pain-scale {
  display: grid;
  grid-template-columns: repeat(11, 1fr);
  gap: 3px;
}
.tr-pain-btn {
  height: 30px;
  border-radius: 7px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.13);
  background: rgb(var(--v-theme-surface));
  font-size: 11.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
  cursor: pointer;
  transition: all 0.13s ease;
  padding: 0;
}
.tr-pain-btn:hover {
  border-color: var(--pn);
  color: var(--pn);
  transform: translateY(-1px);
}
.tr-pain-btn.on {
  background: var(--pn);
  border-color: var(--pn);
  color: #fff;
  box-shadow: 0 3px 9px color-mix(in srgb, var(--pn) 40%, transparent);
}

/* ══ Vitals ══════════════════════════════════════════════════════════ */
.tr-vitals {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 12px;
}
.tr-vitals-foot {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1.1fr);
  gap: 18px;
  align-items: end;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}

.tr-seg {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 6px;
}
.tr-seg-btn {
  padding: 5px 12px;
  border-radius: 8px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  background: rgb(var(--v-theme-surface));
  font-size: 11.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.62);
  cursor: pointer;
  transition: all 0.13s ease;
}
.tr-seg-btn:hover { border-color: var(--hero-main, #2f6dff); color: var(--hero-ink, #1e3a8a); }
.tr-seg-btn.on {
  background: var(--hero-main, #2f6dff);
  border-color: var(--hero-main, #2f6dff);
  color: #fff;
}
.tr-seg-btn.on.danger {
  background: #dc2626;
  border-color: #dc2626;
  box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
}

.tr-news-top {
  display: flex;
  align-items: baseline;
  gap: 7px;
  margin-bottom: 7px;
}
.tr-news-score { font-size: 18px; font-weight: 800; line-height: 1; }
.tr-news-cat {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.tr-news-track {
  position: relative;
  display: flex;
  gap: 3px;
  height: 8px;
}
.tr-news-zone { border-radius: 999px; height: 100%; }
.tr-news-zone.z1 { flex: 5; background: rgba(34, 197, 94, 0.35); }
.tr-news-zone.z2 { flex: 2; background: rgba(245, 158, 11, 0.4); }
.tr-news-zone.z3 { flex: 3; background: rgba(220, 38, 38, 0.35); }
.tr-news-dot {
  position: absolute;
  top: -4px;
  width: 12px; height: 16px;
  border-radius: 5px;
  border: 2px solid #fff;
  transition: left 0.3s ease, background 0.3s ease;
  box-shadow: 0 1px 5px rgba(0, 0, 0, 0.25);
}
.tr-news-legend {
  display: flex;
  justify-content: space-between;
  margin-top: 5px;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.36);
}

/* ══ Alerts ══════════════════════════════════════════════════════════ */
.tr-alert {
  display: flex;
  align-items: flex-start;
  gap: 9px;
  margin-top: 14px;
  padding: 11px 13px;
  border-radius: 12px;
  font-size: 12.5px;
  line-height: 1.45;
}
.tr-alert > div { min-width: 0; flex: 1; }
.tr-alert strong { display: block; font-weight: 800; margin-bottom: 1px; }
.tr-alert span { color: inherit; opacity: 0.85; }
.tr-alert.is-error {
  color: #991b1b;
  background: rgba(220, 38, 38, 0.09);
  border: 1px solid rgba(220, 38, 38, 0.2);
}
.tr-alert.is-warning {
  color: #92400e;
  background: rgba(245, 158, 11, 0.11);
  border: 1px solid rgba(245, 158, 11, 0.26);
}

.tr-override { flex: 1; }

/* ── Abnormal vitals with recommendations ── */
.tr-abn {
  margin-top: 14px;
  border-radius: 13px;
  border: 1px solid rgba(220, 38, 38, 0.22);
  background: rgba(220, 38, 38, 0.05);
  overflow: hidden;
}
.tr-abn-head {
  display: flex;
  align-items: flex-start;
  gap: 9px;
  padding: 11px 13px;
  color: #991b1b;
  background: rgba(220, 38, 38, 0.09);
  border-bottom: 1px solid rgba(220, 38, 38, 0.16);
}
.tr-abn-headtext { min-width: 0; }
.tr-abn-headtext strong {
  display: block;
  font-size: 12.5px;
  font-weight: 800;
  line-height: 1.3;
}
.tr-abn-headtext span {
  display: block;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(153, 27, 27, 0.78);
  margin-top: 1px;
}

.tr-abn-list {
  list-style: none;
  margin: 0;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.tr-abn-item {
  padding: 8px 10px;
  border-radius: 9px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-left: 3px solid #f59e0b;
}
.tr-abn-item.is-critical { border-left-color: #dc2626; }

.tr-abn-item-top {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}
.tr-abn-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 17px; height: 17px;
  border-radius: 5px;
  flex-shrink: 0;
  color: #fff;
  background: #f59e0b;
}
.tr-abn-item.is-critical .tr-abn-arrow { background: #dc2626; }
.tr-abn-label {
  font-size: 12px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
.tr-abn-value {
  font-size: 11.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  padding: 1px 7px;
  border-radius: 6px;
  color: #b45309;
  background: rgba(245, 158, 11, 0.14);
}
.tr-abn-item.is-critical .tr-abn-value {
  color: #b91c1c;
  background: rgba(220, 38, 38, 0.12);
}
.tr-abn-tag {
  margin-left: auto;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
}
.tr-abn-note {
  display: flex;
  align-items: flex-start;
  gap: 5px;
  font-size: 11px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.tr-abn-note .v-icon { color: #b45309; flex-shrink: 0; margin-top: 1px; }
.tr-abn-item.is-critical .tr-abn-note .v-icon { color: #dc2626; }
.tr-mini-cta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 9px;
  padding: 4px 11px;
  border-radius: 8px;
  border: none;
  font-size: 11.5px;
  font-weight: 700;
  color: #fff;
  background: #b45309;
  cursor: pointer;
}
.tr-mini-cta:hover { background: #92400e; }
.tr-mini-cta:disabled {
  opacity: 0.4;
  cursor: not-allowed;
  background: #b45309;
}
.tr-confirmed {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 9px;
  font-size: 11.5px;
  font-weight: 700;
  color: #15803d;
}
.tr-confirmed em {
  font-style: normal;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.5);
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ══ ESI ═════════════════════════════════════════════════════════════ */
.tr-esi-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  grid-auto-rows: 1fr;
  gap: 9px;
}
.tr-esi {
  position: relative;
  text-align: left;
  padding: 11px 11px 12px;
  border-radius: 13px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.11);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: all 0.16s ease;
  overflow: hidden;
}
.tr-esi::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  background: var(--esi);
  opacity: 0.5;
  transition: opacity 0.16s ease;
}
.tr-esi:hover {
  transform: translateY(-2px);
  border-color: var(--esi);
  box-shadow: 0 8px 20px color-mix(in srgb, var(--esi) 20%, transparent);
}
.tr-esi.suggested { border-color: color-mix(in srgb, var(--esi) 55%, transparent); }
.tr-esi.on {
  border-color: var(--esi);
  background: color-mix(in srgb, var(--esi) 9%, rgb(var(--v-theme-surface)));
  box-shadow: 0 8px 22px color-mix(in srgb, var(--esi) 24%, transparent);
}
.tr-esi.on::before { opacity: 1; width: 4px; }
.tr-esi-flag {
  position: absolute;
  top: 0; right: 0;
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 2px 7px 3px;
  border-bottom-left-radius: 9px;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: #fff;
  background: var(--esi);
  opacity: 0.9;
}
.tr-esi-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 5px;
}
.tr-esi-num {
  font-size: 22px;
  font-weight: 800;
  line-height: 1;
  color: var(--esi);
}
.tr-esi-check { color: var(--esi); }
.tr-esi-name {
  font-size: 12px;
  font-weight: 800;
  margin-bottom: 1px;
  color: rgba(var(--v-theme-on-surface), 0.85);
}
.tr-esi-time {
  font-size: 10.5px;
  font-weight: 700;
  color: var(--esi);
  margin-bottom: 4px;
}
.tr-esi-desc {
  font-size: 10px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.45);
}

/* ══ Allergies & meds ════════════════════════════════════════════════ */
/* Action pinned inside the allergy dropdown, matching the register field. */
.tr-cb-foot {
  padding: 6px;
  margin-top: 4px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgb(var(--v-theme-surface));
}
.tr-cb-link {
  font-size: 11.5px !important;
  color: rgba(var(--v-theme-on-surface), 0.62) !important;
}
.tr-cb-link:hover {
  color: var(--hero-main, rgb(var(--v-theme-primary))) !important;
}

.tr-cb-note {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 8px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
}

/* Allergy chips inside the combobox read as clinical alerts. */
.tr-subblock :deep(.v-chip) {
  font-weight: 700;
}

.tr-confirm {
  display: flex;
  align-items: flex-start;
  gap: 9px;
  margin-top: 12px;
  padding: 11px 13px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.11);
  background: rgba(var(--v-theme-on-surface), 0.02);
  cursor: pointer;
  transition: all 0.15s ease;
}
.tr-confirm.on {
  border-color: rgba(34, 197, 94, 0.4);
  background: rgba(34, 197, 94, 0.07);
}
.tr-confirm input { display: none; }
.tr-confirm-box {
  width: 19px; height: 19px;
  border-radius: 6px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.24);
  display: grid; place-items: center;
  color: transparent;
  flex-shrink: 0;
  margin-top: 1px;
  transition: all 0.15s ease;
}
.tr-confirm.on .tr-confirm-box {
  background: #16a34a;
  border-color: #16a34a;
  color: #fff;
}
.tr-confirm-label {
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.8);
}
.tr-confirm-label em {
  display: block;
  font-style: normal;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
  margin-top: 1px;
}

.tr-ghostbtn {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px;
  border-radius: 8px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.13);
  background: transparent;
  font-size: 11px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.62);
  cursor: pointer;
}
.tr-ghostbtn:hover {
  border-color: var(--hero-main, #2f6dff);
  color: var(--hero-ink, #1e3a8a);
}

.tr-meds { display: flex; flex-direction: column; gap: 8px; }
.tr-med {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 0.8fr) minmax(0, 1fr) 32px;
  gap: 8px;
  align-items: center;
}
.tr-del {
  width: 32px; height: 32px;
  display: grid; place-items: center;
  border-radius: 8px;
  border: 1px solid transparent;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.35);
  cursor: pointer;
}
.tr-del:hover {
  color: #dc2626;
  background: rgba(220, 38, 38, 0.08);
  border-color: rgba(220, 38, 38, 0.2);
}

/* ══ Screening ═══════════════════════════════════════════════════════ */
.tr-screen-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  padding: 3px 9px;
  border-radius: 999px;
  color: #b45309;
  background: rgba(245, 158, 11, 0.13);
  border: 1px solid rgba(245, 158, 11, 0.26);
  white-space: nowrap;
}
.tr-screen-badge.done {
  color: #15803d;
  background: rgba(34, 197, 94, 0.13);
  border-color: rgba(34, 197, 94, 0.28);
}
.tr-screen-count {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.42);
}

.tr-flags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 16px;
  padding-bottom: 14px;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.tr-flag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--tone) 30%, transparent);
}

.tr-field-block + .tr-field-block { margin-top: 16px; }
.tr-field-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 8px;
}
.tr-field-label {
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: 0.2px;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.tr-field-value {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45);
}

/* Choice tiles — one tap, no dropdown. */
.tr-tiles {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(118px, 1fr));
  gap: 8px;
}
/* Explicit counts keep option sets tidy (8 smoking options → 4 × 2, never a
   lone stretched tile on the last row). */
.tr-tiles--4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
.tr-tiles--3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.tr-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 1px;
  padding: 10px 11px 11px;
  border-radius: 12px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.11);
  background: rgb(var(--v-theme-surface));
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease,
    transform 0.15s ease, box-shadow 0.15s ease;
}
.tr-tile:hover {
  transform: translateY(-1px);
  border-color: color-mix(in srgb, var(--tone) 55%, transparent);
  box-shadow: 0 6px 16px color-mix(in srgb, var(--tone) 14%, transparent);
}
.tr-tile-icon { color: rgba(var(--v-theme-on-surface), 0.35); margin-bottom: 3px; transition: color 0.15s ease; }
.tr-tile-label {
  font-size: 12.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.82);
  line-height: 1.2;
}
.tr-tile-desc {
  font-size: 10px;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.tr-tile.on {
  border-color: var(--tone);
  background: color-mix(in srgb, var(--tone) 8%, rgb(var(--v-theme-surface)));
  box-shadow: 0 6px 18px color-mix(in srgb, var(--tone) 20%, transparent);
}
.tr-tile.on .tr-tile-icon { color: var(--tone); }
.tr-tile.on .tr-tile-label { color: var(--tone); }
.tr-tile.on .tr-tile-desc { color: color-mix(in srgb, var(--tone) 70%, rgba(var(--v-theme-on-surface), 0.4)); }

/* PHQ-2 */
.tr-phq-chip {
  font-size: 10.5px;
  font-weight: 800;
  padding: 2px 9px;
  border-radius: 999px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.tr-phq-chip.is-ok { color: #15803d; background: rgba(34, 197, 94, 0.13); }
.tr-phq-chip.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.15); }
.tr-phq-chip.is-bad { color: #b91c1c; background: rgba(220, 38, 38, 0.13); }

.tr-phq-intro {
  margin: 0 0 10px;
  font-size: 11px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.45);
}

.tr-phq-q {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 12px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.tr-phq-q + .tr-phq-q { margin-top: 8px; }
.tr-phq-text {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  font-weight: 600;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.tr-phq-opts { display: flex; gap: 4px; flex-shrink: 0; }
.tr-phq-btn {
  width: 30px;
  height: 30px;
  border-radius: 8px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.14);
  background: rgb(var(--v-theme-surface));
  font-size: 11.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.55);
  cursor: pointer;
  transition: all 0.13s ease;
  padding: 0;
}
.tr-phq-btn:hover {
  border-color: var(--hero-main, rgb(var(--v-theme-primary)));
  color: var(--hero-ink, rgb(var(--v-theme-primary)));
}
.tr-phq-btn.on {
  color: #fff;
  background: var(--hero-main, rgb(var(--v-theme-primary)));
  border-color: var(--hero-main, rgb(var(--v-theme-primary)));
  box-shadow: 0 3px 10px color-mix(in srgb, var(--hero-main, #2f6dff) 34%, transparent);
}

.tr-phq-result {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin-top: 11px;
  padding: 8px 11px;
  border-radius: 10px;
  font-size: 11.5px;
  font-weight: 600;
  line-height: 1.4;
}
.tr-phq-result.is-ok {
  color: #15803d;
  background: rgba(34, 197, 94, 0.08);
  border: 1px solid rgba(34, 197, 94, 0.22);
}
.tr-phq-result.is-warn {
  color: #92400e;
  background: rgba(245, 158, 11, 0.11);
  border: 1px solid rgba(245, 158, 11, 0.28);
}
.tr-phq-result.is-idle {
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.13);
}

/* ══ Rail ════════════════════════════════════════════════════════════ */
.tr-rail-badge {
  font-size: 11px;
  font-weight: 800;
  padding: 2px 9px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  color: rgba(var(--v-theme-on-surface), 0.6);
}

.tr-dials {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  justify-items: center;
}
.tr-dial { display: flex; flex-direction: column; align-items: center; gap: 5px; }
.tr-dial-inner { display: flex; flex-direction: column; align-items: center; line-height: 1; }
.tr-dial-num { font-size: 24px; font-weight: 800; }
.tr-dial-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.8px;
  color: rgba(var(--v-theme-on-surface), 0.4);
  margin-top: 2px;
}
.tr-dial-caption {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  text-align: center;
}
.tr-esi-big {
  width: 86px; height: 86px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 1px;
  border: 4px solid var(--esi);
  background: color-mix(in srgb, var(--esi) 8%, rgb(var(--v-theme-surface)));
}
.tr-esi-big-num {
  font-size: 27px;
  font-weight: 800;
  line-height: 1;
  color: var(--esi);
}
.tr-esi-big-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.8px;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

.tr-dial-note {
  font-size: 11.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.5);
  text-align: center;
  margin: 10px 0 0;
  padding: 0 4px;
}

.tr-snap { display: flex; flex-direction: column; gap: 7px; }
.tr-snap-row {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12px;
}
.tr-snap-dot {
  width: 6px; height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
  background: rgba(var(--v-theme-on-surface), 0.22);
}
.tr-snap-dot.ok { background: #22c55e; }
.tr-snap-dot.bad { background: #dc2626; }
.tr-snap-label { color: rgba(var(--v-theme-on-surface), 0.52); font-weight: 600; }
.tr-snap-value {
  margin-left: auto;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.8);
}
.tr-snap-value.bad { color: #dc2626; }
.tr-snap-value.ok { color: rgba(var(--v-theme-on-surface), 0.8); }
.tr-snap-value.none { color: rgba(var(--v-theme-on-surface), 0.3); font-weight: 600; }

.tr-rail-warn {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 12px;
  padding: 7px 10px;
  border-radius: 9px;
  font-size: 11px;
  font-weight: 700;
  color: #92400e;
  background: rgba(245, 158, 11, 0.11);
  border: 1px solid rgba(245, 158, 11, 0.26);
}
.tr-rail-warn.is-critical {
  color: #991b1b;
  background: rgba(220, 38, 38, 0.09);
  border-color: rgba(220, 38, 38, 0.2);
}
.tr-rail-warn em {
  font-style: normal;
  font-weight: 800;
  text-transform: uppercase;
  font-size: 9.5px;
  letter-spacing: 0.4px;
  opacity: 0.8;
}

.tr-checks { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 7px; }
.tr-checks li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
}
.tr-check-dot {
  width: 17px; height: 17px;
  border-radius: 50%;
  display: grid; place-items: center;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.3);
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.16);
  transition: all 0.15s ease;
}
.tr-checks li.done .tr-check-dot {
  color: #fff;
  background: #16a34a;
  border-color: #16a34a;
}
.tr-check-label { color: rgba(var(--v-theme-on-surface), 0.72); font-weight: 600; }
.tr-checks li.done .tr-check-label {
  color: rgba(var(--v-theme-on-surface), 0.45);
  text-decoration: line-through;
  text-decoration-color: rgba(var(--v-theme-on-surface), 0.22);
}
.tr-check-hint {
  margin-left: auto;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.26);
}

.tr-doctor-state {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 10px;
  padding: 7px 10px;
  border-radius: 9px;
  font-size: 11.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.5);
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
}
.tr-doctor-state.assigned {
  color: #15803d;
  background: rgba(34, 197, 94, 0.09);
  border: 1px solid rgba(34, 197, 94, 0.26);
}

.tr-consult {
  width: 100%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  margin-top: 9px;
  height: 36px;
  border-radius: 10px;
  border: none;
  font-size: 12.5px;
  font-weight: 700;
  color: #fff;
  cursor: pointer;
  background: linear-gradient(120deg, var(--hero-deep, #1e3a8a), var(--hero-main, #2f6dff));
  transition: transform 0.15s ease, opacity 0.15s ease;
}
.tr-consult:hover:not(:disabled) { transform: translateY(-1px); }
.tr-consult:disabled { opacity: 0.45; cursor: not-allowed; }

/* ── Handoff clinician picker ── */
.tr-hd-selected {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  grid-template-areas:
    'avatar id clear'
    'stats stats stats';
  gap: 4px 9px;
  padding: 10px 11px;
  margin-bottom: 11px;
  border-radius: 12px;
  border: 1px solid rgba(34, 197, 94, 0.34);
  background: rgba(34, 197, 94, 0.07);
}
.tr-hd-selected.is-busy {
  border-color: rgba(245, 158, 11, 0.36);
  background: rgba(245, 158, 11, 0.07);
}
.tr-hd-avatar {
  grid-area: avatar;
  position: relative;
  width: 34px; height: 34px;
  border-radius: 50%;
  display: grid; place-items: center;
  font-size: 12px;
  font-weight: 800;
  color: #fff;
  background: linear-gradient(135deg, var(--hero-deep, #1e3a8a), var(--hero-main, #2f6dff));
}
.tr-hd-presence {
  position: absolute;
  right: -1px; bottom: -1px;
  width: 10px; height: 10px;
  border-radius: 50%;
  border: 2px solid rgb(var(--v-theme-surface));
  background: #94a3b8;
}
.tr-hd-presence.on { background: #22c55e; }
.tr-hd-selected-id { grid-area: id; min-width: 0; display: flex; flex-direction: column; justify-content: center; }
.tr-hd-selected-name {
  font-size: 12.5px;
  font-weight: 800;
  line-height: 1.25;
  color: rgba(var(--v-theme-on-surface), 0.85);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-hd-selected-meta {
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tr-hd-clear {
  grid-area: clear;
  width: 24px; height: 24px;
  display: grid; place-items: center;
  border-radius: 7px;
  border: none;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.4);
  cursor: pointer;
}
.tr-hd-clear:hover { color: #dc2626; background: rgba(220, 38, 38, 0.1); }
.tr-hd-selected-stats {
  grid-area: stats;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  margin-top: 7px;
  padding-top: 8px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.tr-hd-stat { display: flex; flex-direction: column; align-items: center; gap: 0; }
.tr-hd-stat-num {
  font-size: 15px;
  font-weight: 800;
  line-height: 1;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.82);
}
.tr-hd-stat-label {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.4);
  margin-top: 2px;
}

.tr-hd-suggest {
  padding: 10px 11px;
  margin-bottom: 12px;
  border-radius: 12px;
  border: 1px dashed color-mix(in srgb, var(--hero-main, #2f6dff) 45%, transparent);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 6%, transparent);
}
.tr-hd-suggest-head {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: var(--hero-ink, #1e3a8a);
  opacity: 0.85;
}
.tr-hd-suggest-name {
  font-size: 13px;
  font-weight: 800;
  margin: 3px 0 1px;
  color: rgba(var(--v-theme-on-surface), 0.85);
}
.tr-hd-suggest-why {
  font-size: 10.5px;
  font-weight: 600;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.tr-hd-accept {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: 8px;
  height: 28px;
  padding: 0 11px;
  border-radius: 8px;
  border: none;
  font-size: 11.5px;
  font-weight: 800;
  color: #fff;
  cursor: pointer;
  background: var(--hero-main, #2f6dff);
  transition: transform 0.14s ease;
}
.tr-hd-accept:hover { transform: translateY(-1px); }

.tr-hd-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 7px;
}
/* The roster source sits next to the count so it is obvious the list is
   scoped to this clinic. */
.tr-hd-toolbar .tr-mini-label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.tr-hd-scope {
  text-transform: none;
  letter-spacing: 0;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.38);
}

.tr-hd-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 5px; }
.tr-hd-row {
  display: grid;
  grid-template-columns: 8px minmax(0, 1fr) auto auto 16px;
  align-items: center;
  gap: 7px;
  padding: 7px 9px;
  border-radius: 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: border-color 0.14s ease, background 0.14s ease, transform 0.14s ease;
}
.tr-hd-row:hover {
  transform: translateY(-1px);
  border-color: color-mix(in srgb, var(--hero-main, #2f6dff) 45%, transparent);
}
.tr-hd-row.recommended {
  border-color: color-mix(in srgb, var(--hero-main, #2f6dff) 35%, transparent);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 4%, transparent);
}
.tr-hd-row.on {
  border-color: var(--hero-main, #2f6dff);
  background: color-mix(in srgb, var(--hero-main, #2f6dff) 8%, transparent);
  box-shadow: 0 4px 14px color-mix(in srgb, var(--hero-main, #2f6dff) 18%, transparent);
}
.tr-hd-dot {
  width: 8px; height: 8px;
  border-radius: 50%;
  background: rgba(var(--v-theme-on-surface), 0.2);
}
.tr-hd-dot.on { background: #22c55e; box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.16); }
.tr-hd-row-id { min-width: 0; display: flex; flex-direction: column; }
.tr-hd-row-name {
  font-size: 12px;
  font-weight: 700;
  line-height: 1.25;
  color: rgba(var(--v-theme-on-surface), 0.82);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-hd-row-sub {
  font-size: 9.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.42);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.tr-hd-loadbar { display: flex; gap: 2px; }
.tr-hd-seg {
  width: 5px;
  height: 14px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.1);
}
.tr-hd-seg.busy { background: #f59e0b; }
.tr-hd-seg.waiting { background: #3b82f6; }
.tr-hd-seg.empty { background: rgba(var(--v-theme-on-surface), 0.09); }

.tr-hd-queue {
  min-width: 20px;
  text-align: center;
  font-size: 12px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  padding: 1px 5px;
  border-radius: 6px;
}
.tr-hd-queue.is-free { color: #15803d; background: rgba(34, 197, 94, 0.13); }
.tr-hd-queue.is-light { color: #1d4ed8; background: rgba(59, 130, 246, 0.13); }
.tr-hd-queue.is-busy { color: #b45309; background: rgba(245, 158, 11, 0.15); }
.tr-hd-queue.is-heavy { color: #b91c1c; background: rgba(220, 38, 38, 0.13); }
.tr-hd-tick { color: var(--hero-main, #2f6dff); }

.tr-rail-hint {
  display: flex;
  align-items: flex-start;
  gap: 5px;
  margin: 10px 0 0;
  font-size: 10.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

/* ══ Sticky action bar ═══════════════════════════════════════════════ */
.tr-actionbar {
  position: sticky;
  bottom: 0;
  z-index: 40;
  margin-top: 16px;
  border-radius: 15px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgba(var(--v-theme-surface), 0.94);
  box-shadow: 0 -6px 26px rgba(15, 23, 42, 0.1);
  backdrop-filter: blur(10px);
}
.tr-actionbar-inner {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 11px 24px;
}
.tr-actionbar-left {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.tr-actionring { flex-shrink: 0; }
.tr-actionring-num { font-size: 10px; font-weight: 800; }
.tr-actionbar-text {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.3;
}
.tr-actionbar-text strong {
  font-size: 12.5px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.82);
  white-space: nowrap;
}
.tr-actionbar-text span {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.tr-actionbar-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }

.tr-btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 40px;
  padding: 0 16px;
  border-radius: 11px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.16);
  background: rgb(var(--v-theme-surface));
  font-size: 13px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.72);
  cursor: pointer;
  transition: all 0.15s ease;
}
.tr-btn-outline:hover:not(:disabled) {
  border-color: var(--hero-main, #2f6dff);
  color: var(--hero-ink, #1e3a8a);
}
.tr-btn-outline:disabled { opacity: 0.45; cursor: not-allowed; }

.tr-cta {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 40px;
  padding: 0 20px;
  border-radius: 11px;
  border: none;
  font-size: 13px;
  font-weight: 800;
  color: #fff;
  cursor: pointer;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #1e3a8a) 0%,
    var(--hero-main, #2f6dff) 60%,
    var(--hero-accent, #60a5fa) 100%
  );
  box-shadow: var(--hero-shadow, 0 8px 20px rgba(47, 109, 255, 0.3));
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.tr-cta:hover:not(:disabled) { transform: translateY(-1px); }
.tr-cta:disabled {
  opacity: 0.45;
  cursor: not-allowed;
  box-shadow: none;
  filter: grayscale(0.35);
}

/* ══ Responsive ══════════════════════════════════════════════════════ */
@media (max-width: 1180px) {
  .tr-grid { grid-template-columns: minmax(0, 1fr); }
  .tr-rail { position: static; }
  .tr-esi-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (max-width: 900px) {
  .tr-hero-top { flex-wrap: wrap; }
  .tr-hero-actions { width: 100%; }
  .tr-glass, .tr-solid { flex: 1; justify-content: center; }
  .tr-split { grid-template-columns: minmax(0, 1fr); }
  .tr-vitals-foot { grid-template-columns: minmax(0, 1fr); gap: 14px; }
  .tr-hero-progress { margin-left: 0; width: 100%; }
  .tr-hero-progress-bar { flex: 1; }
}
@media (max-width: 640px) {
  .tr-patient { font-size: 20px; }
  .tr-esi-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .tr-tiles--4, .tr-tiles--3 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  /* The requirement badge is what matters when collapsed — drop the count and
     the subtitle so the title keeps a single line. */
  .tr-card-head--screening .tr-screen-count { display: none; }
  .tr-card-head--screening .tr-card-titles p { display: none; }
  .tr-card-head--screening .tr-screen-badge { font-size: 9px; padding: 2px 7px; }
  .tr-med { grid-template-columns: minmax(0, 1fr) 32px; }
  .tr-med .v-input:nth-child(2),
  .tr-med .v-input:nth-child(3) { grid-column: 1; }
  .tr-actionbar-inner { flex-direction: column; align-items: stretch; padding: 10px 14px; }
  .tr-actionbar-right { width: 100%; }
  .tr-btn-outline, .tr-cta { flex: 1; justify-content: center; }
  .tr-pain-btn { height: 26px; font-size: 10.5px; }
  .tr-critical-body { font-size: 13px; }
}
</style>

<style>
/* The VitalInput component bumps its own font size — keep it consistent
   with the premium vitals grid. */
.tr-vitals .v-text-field input {
  font-size: 1.15rem;
  font-weight: 700;
  text-align: center;
}
</style>
