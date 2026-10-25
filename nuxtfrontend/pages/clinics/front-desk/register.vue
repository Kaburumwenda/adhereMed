<template>
  <v-container fluid class="pa-4 pa-md-6 rx-page" :style="heroTheme">
    <!-- ═══════════════ HERO ═══════════════
         Brand-tinted gradient from the tenant palette
         (/clinics/organization/branding), matching the catalog + front-desk
         heroes so reception reads as one product surface.
         The palette CSS vars live on the page root (not the hero) so the
         sticky action bar and the summary avatar inherit them too. -->
    <div class="rx-hero mb-4">
      <span class="rx-hero-glow" />
      <span class="rx-hero-glow rx-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="rx-hero-icon">
            <v-icon size="30">mdi-account-plus</v-icon>
          </div>
          <div style="min-width:0">
            <div class="rx-hero-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              RECEPTION · REGISTRATION
            </div>
            <h1 class="rx-hero-title">Register Patient</h1>
            <div class="rx-hero-sub">
              Check a patient into today's queue — identity, contact, clinical flags and visit details
              in one pass.
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn variant="flat" elevation="0" rounded="lg" class="text-none rx-hero-btn-glass"
                 prepend-icon="mdi-arrow-left" @click="goBack">Back to front desk</v-btn>
        </div>
      </div>

      <div class="rx-hero-foot">
        <span class="rx-hero-chip">
          <v-icon size="14">mdi-calendar-today</v-icon>{{ todayLabel }}
        </span>
        <span class="rx-hero-chip">
          <v-icon size="14">mdi-cash</v-icon>
          {{ formatMoney(reg.consultation_fee, settings.currency) }} fee
        </span>
        <span class="rx-hero-chip">
          <v-icon size="14">{{ regMode === 'new' ? 'mdi-account-plus-outline' : 'mdi-account-search' }}</v-icon>
          {{ regMode === 'new' ? 'New patient' : 'Existing patient' }}
        </span>
        <span v-if="regMode === 'new'" class="rx-hero-chip" :class="{ 'rx-hero-chip--on': isPaediatric }">
          <v-icon size="14">{{ isPaediatric ? 'mdi-human-baby-changing-table' : 'mdi-account' }}</v-icon>
          {{ isPaediatric ? 'Paediatrics' : 'General' }}
        </span>
        <span v-else class="rx-hero-chip" :class="{ 'rx-hero-chip--on': regIsPaediatric }">
          <v-icon size="14">{{ regIsPaediatric ? 'mdi-human-baby-changing-table' : 'mdi-account' }}</v-icon>
          {{ regIsPaediatric ? 'Paediatrics' : 'General' }}
        </span>
        <span class="rx-hero-chip" :class="{ 'rx-hero-chip--on': portalEnabled }">
          <v-icon size="14">mdi-monitor-dashboard</v-icon>
          {{ portalEnabled ? 'Portal enabled' : 'No portal access' }}
        </span>
        <span class="rx-hero-chip rx-hero-chip--progress">
          <v-icon size="14">mdi-progress-check</v-icon>
          {{ completionPct }}% complete
        </span>
      </div>
    </div>

    <v-row dense class="rx-layout">
      <!-- ═══════════ FORM COLUMN ═══════════ -->
      <v-col cols="12" lg="8">

        <!-- ── Mode switcher ── -->
        <div class="rx-modebar mb-3">
          <button type="button" class="rx-mode" :class="{ 'rx-mode--on': regMode === 'existing' }"
                  @click="regMode = 'existing'">
            <span class="rx-mode-icon"><v-icon size="19">mdi-account-search</v-icon></span>
            <span class="rx-mode-text">
              <span class="rx-mode-title">Existing patient</span>
              <span class="rx-mode-sub">Already in this clinic's records</span>
            </span>
            <v-icon v-if="regMode === 'existing'" class="rx-mode-check" size="18">mdi-check-circle</v-icon>
          </button>
          <button type="button" class="rx-mode" :class="{ 'rx-mode--on': regMode === 'new' }"
                  @click="regMode = 'new'">
            <span class="rx-mode-icon"><v-icon size="19">mdi-account-plus-outline</v-icon></span>
            <span class="rx-mode-text">
              <span class="rx-mode-title">New patient</span>
              <span class="rx-mode-sub">Create a fresh clinic record</span>
            </span>
            <v-icon v-if="regMode === 'new'" class="rx-mode-check" size="18">mdi-check-circle</v-icon>
          </button>
        </div>

        <!-- ═══════════ EXISTING PATIENT ═══════════ -->
        <template v-if="regMode === 'existing'">
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': !!reg.patient }">
                <v-icon v-if="reg.patient" size="15">mdi-check</v-icon>
                <template v-else>1</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Find the patient</div>
                <div class="rx-card-sub">Search by name, patient number or phone</div>
              </div>
            </header>

            <div class="rx-card-body">
              <v-autocomplete v-model="reg.patient" :items="patientItems" :loading="patientsLoading"
                              item-title="label" item-value="id" label="Patient"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-magnify" no-data-text="No patient found"
                              v-model:search="patientQuery" @update:search="onPatientSearch" />

              <div v-if="selectedPatient" class="rx-selected mt-3">
                <div class="rx-selected-avatar">{{ initialsOf(selectedPatient.label) }}</div>
                <div class="min-w-0 flex-grow-1">
                  <div class="rx-selected-name">{{ selectedPatient.label.split(' · ')[0] }}</div>
                  <div class="rx-selected-meta">{{ selectedPatient.label.split(' · ').slice(1).join(' · ') }}</div>
                </div>
                <v-chip v-if="regIsPaediatric" size="x-small" variant="tonal" color="info">
                  <v-icon start size="12">mdi-human-baby-changing-table</v-icon>Paediatric
                </v-chip>
                <v-icon color="success" size="20">mdi-check-decagram</v-icon>
              </div>
            </div>
          </section>

          <!-- ── Clinical stream for this visit (existing patients) ── -->
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step">2</span>
              <div class="min-w-0">
                <div class="rx-card-title">Clinical stream</div>
                <div class="rx-card-sub">
                  General or paediatrics — updates the patient record for this visit
                </div>
              </div>
            </header>

            <div class="rx-card-body">
              <div class="rx-cats">
                <button
                  v-for="c in patientCategories"
                  :key="`x-${c.value}`"
                  type="button"
                  class="rx-cat"
                  :class="{ 'rx-cat--on': reg.patient_category === c.value }"
                  :aria-pressed="reg.patient_category === c.value"
                  @click="setRegCategory(c.value)"
                >
                  <span class="rx-cat-icon"><v-icon size="20">{{ c.icon }}</v-icon></span>
                  <span class="rx-cat-body">
                    <span class="rx-cat-title">{{ c.title }}</span>
                    <span class="rx-cat-sub">{{ c.subtitle }}</span>
                  </span>
                  <v-icon v-if="reg.patient_category === c.value" class="rx-cat-check" size="19">
                    mdi-check-circle
                  </v-icon>
                </button>
              </div>

              <v-alert v-if="regIsPaediatric" type="info" variant="tonal" density="compact"
                       rounded="lg" class="mt-4">
                Paediatric visit — confirm the guardian below. Returning children usually
                arrive with the adult already on file.
              </v-alert>

              <template v-if="regIsPaediatric">
                <v-row dense class="mt-1">
                  <v-col cols="12" sm="5">
                    <v-text-field v-model="reg.guardian_name" label="Guardian full name *"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-account-supervisor"
                                  :error-messages="errors.guardian_name"
                                  @update:model-value="clearError('guardian_name')" />
                  </v-col>
                  <v-col cols="12" sm="4">
                    <v-text-field v-model="reg.guardian_phone" label="Guardian phone *"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-phone"
                                  :error-messages="errors.guardian_phone"
                                  @update:model-value="clearError('guardian_phone')" />
                  </v-col>
                  <v-col cols="12" sm="3">
                    <v-combobox v-model="reg.guardian_relationship" :items="guardianRelationships"
                                label="Relationship" variant="outlined" density="comfortable"
                                rounded="lg" :hide-no-data="false"
                                prepend-inner-icon="mdi-account-heart-outline" />
                  </v-col>
                </v-row>
              </template>
            </div>
          </section>

          <!-- ── Billing ── -->
          <BillingPanel
            class="mb-3"
            :step="3"
            :state="reg"
            :currency="settings.currency"
            :errors="errors"
            :allow-waiver="settings.allow_fee_waiver !== false"
            :patient="billingPatient"
          />

          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': visitDone }">
                <v-icon v-if="visitDone" size="15">mdi-check</v-icon>
                <template v-else>4</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Visit details</div>
                <div class="rx-card-sub">What brings them in today and how quickly they need care</div>
              </div>
            </header>

            <div class="rx-card-body">
              <v-textarea v-model="reg.chief_complaint" label="Reason for visit (service)" rows="2" auto-grow
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-text-box-outline"
                          hint="Reception records the service requested — symptoms are captured in triage"
                          persistent-hint />

              <ReasonChips v-model="reg.chief_complaint" class="mt-3"
                           :groups="serviceReasonGroups"
                           title="Common services"
                           hint="tap to add · tap again to remove"
                           icon="mdi-clipboard-list-outline" />

              <div class="rx-field-row">
                <v-row dense align="start">
                  <v-col cols="12" sm="6">
                    <v-select v-model="reg.priority" :items="priorities"
                              item-title="title" item-value="value" :item-props="priorityProps"
                              label="Priority" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-flag" hide-details />
                  </v-col>
                </v-row>

                <div class="rx-prio-note" :class="`rx-prio-note--${reg.priority}`">
                  <v-icon size="14">{{ selectedPriority.icon }}</v-icon>
                  <span>
                    <strong>{{ selectedPriority.title }}</strong> · {{ selectedPriority.subtitle }}
                  </span>
                </div>
              </div>
            </div>
          </section>
        </template>

        <!-- ═══════════ NEW PATIENT ═══════════ -->
        <template v-else>
          <!-- ── Registration type ── -->
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step">{{ stepNo('type') }}</span>
              <div class="min-w-0">
                <div class="rx-card-title">Registration type</div>
                <div class="rx-card-sub">
                  General or paediatrics, and whether this patient can log into the portal
                </div>
              </div>
            </header>

            <div class="rx-card-body">
              <div class="rx-sublabel">Clinical stream</div>
              <div class="rx-cats">
                <button
                  v-for="c in patientCategories"
                  :key="c.value"
                  type="button"
                  class="rx-cat"
                  :class="{ 'rx-cat--on': np.patient_category === c.value }"
                  :aria-pressed="np.patient_category === c.value"
                  @click="setCategory(c.value)"
                >
                  <span class="rx-cat-icon"><v-icon size="20">{{ c.icon }}</v-icon></span>
                  <span class="rx-cat-body">
                    <span class="rx-cat-title">{{ c.title }}</span>
                    <span class="rx-cat-sub">{{ c.subtitle }}</span>
                  </span>
                  <v-icon v-if="np.patient_category === c.value" class="rx-cat-check" size="19">
                    mdi-check-circle
                  </v-icon>
                </button>
              </div>

              <div class="rx-sublabel mt-5">Portal access</div>
              <div class="rx-types">
                <button type="button" class="rx-type" :class="{ 'rx-type--on': regType === 'clinic' }"
                        @click="regType = 'clinic'">
                  <span class="rx-type-icon"><v-icon>mdi-home-heart</v-icon></span>
                  <span class="rx-type-body">
                    <span class="rx-type-title">Clinic only</span>
                    <span class="rx-type-sub">
                      In-house record with no portal login. A system password is
                      generated and never shared.
                    </span>
                    <v-chip size="x-small" variant="tonal" color="grey" class="mt-2">
                      <v-icon start size="13">mdi-shield-lock</v-icon> No portal access
                    </v-chip>
                  </span>
                  <v-icon v-if="regType === 'clinic'" class="rx-type-check" size="20">mdi-check-circle</v-icon>
                </button>

                <button type="button" class="rx-type" :class="{ 'rx-type--on': regType === 'portal' }"
                        @click="regType = 'portal'">
                  <span class="rx-type-icon"><v-icon>mdi-monitor-dashboard</v-icon></span>
                  <span class="rx-type-body">
                    <span class="rx-type-title">Patient dashboard</span>
                    <span class="rx-type-sub">
                      Gets a login with a password you set, and sees the health
                      data you choose to share.
                    </span>
                    <v-chip size="x-small" variant="tonal" color="primary" class="mt-2">
                      <v-icon start size="13">mdi-login</v-icon> Portal enabled
                    </v-chip>
                  </span>
                  <v-icon v-if="regType === 'portal'" class="rx-type-check" size="20">mdi-check-circle</v-icon>
                </button>
              </div>
            </div>
          </section>

          <!-- ── Identity ── -->
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': identityDone }">
                <v-icon v-if="identityDone" size="15">mdi-check</v-icon>
                <template v-else>{{ stepNo('identity') }}</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Identity</div>
                <div class="rx-card-sub">
                  Required — first name, last name and date of birth
                  <template v-if="portalEnabled"> · email needed for portal access</template>
                  <template v-if="isPaediatric"> · paediatric patients must be under 18</template>
                </div>
              </div>
              <v-chip v-if="identityDone" size="x-small" variant="tonal" color="success" class="ml-auto">
                Complete
              </v-chip>
            </header>

            <div class="rx-card-body">
              <v-row dense>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="np.first_name" label="First name *" variant="outlined"
                                density="comfortable" rounded="lg" prepend-inner-icon="mdi-account"
                                :error-messages="errors.first_name" @update:model-value="clearError('first_name')" />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="np.middle_name" label="Middle name" variant="outlined"
                                density="comfortable" rounded="lg"
                                hint="Optional" persistent-hint
                                prepend-inner-icon="mdi-account-outline" />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="np.last_name" label="Last name *" variant="outlined"
                                density="comfortable" rounded="lg" prepend-inner-icon="mdi-account"
                                :error-messages="errors.last_name" @update:model-value="clearError('last_name')" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.date_of_birth" label="Date of birth *" type="date"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-calendar"
                                :hint="dobHint" :persistent-hint="!!dobHint"
                                :error-messages="errors.date_of_birth" @update:model-value="clearError('date_of_birth')" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-select v-model="np.gender" :items="genders" label="Gender"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-gender-male-female" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.email" :label="portalEnabled ? 'Email *' : 'Email'"
                                type="email" variant="outlined"
                                density="comfortable" rounded="lg" prepend-inner-icon="mdi-email"
                                :hint="portalEnabled ? '' : 'Optional — only needed for a dashboard login'"
                                :persistent-hint="!portalEnabled"
                                :error-messages="errors.email" @update:model-value="clearError('email')" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.phone" label="Phone" variant="outlined"
                                density="comfortable" rounded="lg" prepend-inner-icon="mdi-phone"
                                :hint="isPaediatric ? 'Guardian phone is captured below' : ''"
                                :persistent-hint="isPaediatric" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.national_id" label="National ID" variant="outlined"
                                density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-card-account-details-outline" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-select v-model="np.blood_type" :items="bloodTypes" label="Blood group"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-water-outline" clearable />
                </v-col>
              </v-row>
            </div>
          </section>

          <!-- ── Contact ── -->
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': contactDone }">
                <v-icon v-if="contactDone" size="15">mdi-check</v-icon>
                <template v-else>{{ stepNo('contact') }}</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Contact &amp; emergency</div>
                <div class="rx-card-sub">Where they live and who to call</div>
              </div>
            </header>

            <div class="rx-card-body">
              <v-autocomplete
                v-model="addressSelection"
                v-model:search="addressQuery"
                :items="addressPredictions"
                :loading="loadingPlaces"
                item-title="description"
                item-value="place_id"
                label="Home address — search with Google Places"
                placeholder="Start typing an address…"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-map-marker-outline"
                return-object
                hide-no-data
                hide-details="auto"
                no-filter
                clearable
                @update:search="onAddressSearch"
                @update:model-value="onAddressPicked"
              >
                <template #append-inner>
                  <v-tooltip text="Use my current location" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-crosshairs-gps" variant="text" size="small"
                             color="primary" :loading="locating" @click.stop="useMyLocation" />
                    </template>
                  </v-tooltip>
                </template>
                <template #item="{ props: ip, item }">
                  <v-list-item v-bind="ip" prepend-icon="mdi-map-marker-outline">
                    <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                      {{ item.raw.structured_formatting.secondary_text }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </template>
              </v-autocomplete>

              <v-textarea v-model="np.address" label="Address (editable)" rows="2" auto-grow
                          variant="outlined" density="comfortable" rounded="lg" class="mt-2"
                          prepend-inner-icon="mdi-home-map-marker"
                          hint="Free text is kept if you do not pick a Google result"
                          persistent-hint />

              <div class="rx-geo" :class="{ 'rx-geo--ok': hasCoords }">
                <v-icon size="14">{{ hasCoords ? 'mdi-map-marker-check' : 'mdi-map-marker-question' }}</v-icon>
                <span v-if="hasCoords">
                  Coordinates captured · {{ Number(np.latitude).toFixed(5) }},
                  {{ Number(np.longitude).toFixed(5) }}
                </span>
                <span v-else>
                  No coordinates yet — pick a suggested address to pin the home location
                  for homecare and outreach.
                </span>
                <v-btn v-if="hasCoords" variant="text" size="x-small" class="text-none ml-auto"
                       prepend-icon="mdi-close-circle-outline" @click="clearCoords">
                  Clear
                </v-btn>
              </div>

              <div class="rx-sublabel mt-4">Emergency contact</div>
              <v-row dense>
                <v-col cols="12" sm="5">
                  <v-text-field v-model="np.emergency_contact_name" label="Contact name"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-account-alert" />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="np.emergency_contact_phone" label="Phone"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-phone" />
                </v-col>
                <v-col cols="12" sm="3">
                  <v-text-field v-model="np.emergency_contact_relation" label="Relationship"
                                variant="outlined" density="comfortable" rounded="lg" />
                </v-col>
              </v-row>
            </div>
          </section>

          <!-- ── Parent / guardian (paediatrics only) ── -->
          <section v-if="isPaediatric" class="rx-card rx-card--paeds mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': guardianDone }">
                <v-icon v-if="guardianDone" size="15">mdi-check</v-icon>
                <template v-else>{{ stepNo('guardian') }}</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Parent / guardian</div>
                <div class="rx-card-sub">
                  Required for paediatric registration — the adult responsible for this child
                </div>
              </div>
              <v-chip v-if="guardianDone" size="x-small" variant="tonal" color="success" class="ml-auto">
                Complete
              </v-chip>
            </header>

            <div class="rx-card-body">
              <v-row dense>
                <v-col cols="12" sm="5">
                  <v-text-field v-model="np.guardian_name" label="Guardian full name *"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-account-supervisor"
                                :error-messages="errors.guardian_name"
                                @update:model-value="clearError('guardian_name')" />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field v-model="np.guardian_phone" label="Guardian phone *"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-phone"
                                :error-messages="errors.guardian_phone"
                                @update:model-value="clearError('guardian_phone')" />
                </v-col>
                <v-col cols="12" sm="3">
                  <v-combobox v-model="np.guardian_relationship" :items="guardianRelationships"
                              label="Relationship" variant="outlined" density="comfortable"
                              rounded="lg" :hide-no-data="false"
                              prepend-inner-icon="mdi-account-heart-outline" />
                </v-col>
              </v-row>

              <v-row dense class="mt-1">
                <v-col cols="12" sm="6">
                  <v-select v-model="np.immunisation_status" :items="immunisationOptions"
                            item-title="title" item-value="value" label="Immunisation status"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-needle" hide-details />
                </v-col>
                <v-col cols="12" sm="6">
                  <div class="rx-same-as-emergency">
                    <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                           prepend-icon="mdi-account-arrow-right"
                           :disabled="!np.emergency_contact_name.trim()"
                           @click="useEmergencyContactAsGuardian">
                      Use emergency contact
                    </v-btn>
                    <span class="rx-same-hint">
                      {{ np.emergency_contact_name.trim()
                        ? 'Copies the name, phone and relationship above'
                        : 'Fill in the emergency contact first' }}
                    </span>
                  </div>
                </v-col>
              </v-row>

              <div class="rx-law-note">
                <v-icon size="14">mdi-shield-account-outline</v-icon>
                <span>
                  Paediatric records are charged and communicated through the guardian.
                  The child's own phone and email are optional.
                </span>
              </div>
            </div>
          </section>

          <!-- ── Billing ── -->
          <BillingPanel
            class="mb-3"
            :step="stepNo('billing')"
            :state="np"
            :currency="settings.currency"
            :errors="errors"
            :allow-waiver="settings.allow_fee_waiver !== false"
            :patient="billingPatient"
          />

          <!-- ── Portal access ── -->
          <section v-if="portalEnabled" class="rx-card rx-card--portal mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': portalDone }">
                <v-icon v-if="portalDone" size="15">mdi-check</v-icon>
                <template v-else>{{ stepNo('portal') }}</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Portal access</div>
                <div class="rx-card-sub">Set the login password and choose what the patient can see</div>
              </div>
              <v-chip v-if="portalDone" size="x-small" variant="tonal" color="success" class="ml-auto">
                Ready
              </v-chip>
            </header>

            <div class="rx-card-body">
              <v-row dense>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.password" :type="showPwd ? 'text' : 'password'"
                                label="Portal password *" variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-lock-outline"
                                :append-inner-icon="showPwd ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
                                :error="pwdTooShort"
                                :error-messages="errors.password || (pwdTooShort ? 'Minimum 8 characters' : '')"
                                @click:append-inner="showPwd = !showPwd"
                                @update:model-value="clearError('password')" />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field v-model="np.password_confirm" :type="showPwd ? 'text' : 'password'"
                                label="Confirm password *" variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-lock-check-outline"
                                :error="pwdMismatch"
                                :error-messages="pwdMismatch ? 'Passwords do not match' : ''" />
                </v-col>
              </v-row>

              <div class="rx-strength">
                <div class="rx-strength-bars">
                  <span v-for="i in 4" :key="i" class="rx-strength-bar"
                        :style="i <= pwdStrength ? { background: pwdStrengthColor } : undefined" />
                </div>
                <span class="rx-strength-label">{{ pwdStrengthLabel }}</span>
              </div>

              <div class="rx-share-head">
                <div>
                  <div class="rx-sublabel" style="margin:0">Data shared on the dashboard</div>
                  <div class="rx-card-sub">
                    {{ np.shared_fields.length }} of {{ shareCategories.length }} categories
                  </div>
                </div>
                <div class="d-flex ga-1">
                  <v-btn variant="text" size="x-small" class="text-none"
                         prepend-icon="mdi-select-all" @click="selectAllShared">Select all</v-btn>
                  <v-btn variant="text" size="x-small" class="text-none"
                         prepend-icon="mdi-select-off" @click="clearAllShared">Clear</v-btn>
                </div>
              </div>

              <div class="rx-share-grid">
                <button v-for="cat in shareCategories" :key="cat.key" type="button"
                        class="rx-share" :class="{ 'rx-share--on': np.shared_fields.includes(cat.key) }"
                        @click="toggleShared(cat.key)">
                  <v-icon size="19" class="rx-share-icon">{{ cat.icon }}</v-icon>
                  <span class="rx-share-label">{{ cat.label }}</span>
                  <v-icon v-if="np.shared_fields.includes(cat.key)" class="rx-share-check"
                          size="15">mdi-check-circle</v-icon>
                </button>
              </div>
            </div>
          </section>

          <!-- ── Visit ── -->
          <section class="rx-card mb-3">
            <header class="rx-card-head">
              <span class="rx-step" :class="{ 'rx-step--done': visitDone }">
                <v-icon v-if="visitDone" size="15">mdi-check</v-icon>
                <template v-else>{{ stepNo('visit') }}</template>
              </span>
              <div class="min-w-0">
                <div class="rx-card-title">Visit information</div>
                <div class="rx-card-sub">Places the patient in today's front-desk queue</div>
              </div>
            </header>

            <div class="rx-card-body">
              <v-textarea v-model="reg.chief_complaint" label="Reason for visit (service)" rows="2" auto-grow
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-text-box-outline"
                          hint="Reception records the service requested — symptoms are captured in triage"
                          persistent-hint />

              <ReasonChips v-model="reg.chief_complaint" class="mt-3"
                           :groups="serviceReasonGroups"
                           title="Common services"
                           hint="tap to add · tap again to remove"
                           icon="mdi-clipboard-list-outline" />

              <div class="rx-field-row">
                <v-row dense align="start">
                  <v-col cols="12" sm="6">
                    <v-select v-model="reg.priority" :items="priorities"
                              item-title="title" item-value="value" :item-props="priorityProps"
                              label="Priority" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-flag" hide-details />
                  </v-col>
                </v-row>

                <div class="rx-prio-note" :class="`rx-prio-note--${reg.priority}`">
                  <v-icon size="14">{{ selectedPriority.icon }}</v-icon>
                  <span>
                    <strong>{{ selectedPriority.title }}</strong> · {{ selectedPriority.subtitle }}
                  </span>
                </div>
              </div>
            </div>
          </section>
        </template>

        <v-alert v-if="registerError" type="error" variant="tonal" rounded="lg"
                 density="compact" class="mb-3" closable @click:close="registerError = ''">
          {{ registerError }}
        </v-alert>
      </v-col>

      <!-- ═══════════ SUMMARY RAIL ═══════════ -->
      <v-col cols="12" lg="4">
        <div class="rx-rail">
          <div class="rx-summary">
            <div class="rx-summary-head">
              <div class="rx-summary-avatar" :class="{ 'rx-summary-avatar--empty': !previewInitials }">
                <template v-if="previewInitials">{{ previewInitials }}</template>
                <v-icon v-else size="22">mdi-account-outline</v-icon>
              </div>
              <div class="min-w-0 flex-grow-1">
                <div class="rx-summary-name">{{ previewName || 'Unnamed patient' }}</div>
                <div class="rx-summary-meta">
                  {{ regMode === 'new'
                    ? 'New record'
                    : (selectedPatient ? 'Existing record' : 'No patient selected') }}
                </div>
              </div>
            </div>

            <!-- Progress ring -->
            <div class="rx-progress">
              <v-progress-circular :model-value="completionPct" :size="54" :width="5"
                                   :color="completionPct === 100 ? 'success' : 'primary'">
                <span class="rx-progress-pct">{{ completionPct }}%</span>
              </v-progress-circular>
              <div class="min-w-0">
                <div class="rx-progress-title">
                  {{ completionPct === 100 ? 'Ready to check in' : 'In progress' }}
                </div>
                <div class="rx-progress-sub">
                  {{ checklistDone }} of {{ checklist.length }} items complete
                </div>
              </div>
            </div>

            <!-- Checklist -->
            <ul class="rx-checklist">
              <li v-for="item in checklist" :key="item.key" class="rx-check"
                  :class="{ 'rx-check--done': item.done }">
                <v-icon size="16">{{ item.done ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                <span class="flex-grow-1">{{ item.label }}</span>
                <span class="rx-check-hint">{{ item.hint }}</span>
              </li>
            </ul>

            <!-- Visit snapshot -->
            <div class="rx-snapshot">
              <div class="rx-snap-row">
                <span class="rx-snap-label">Priority</span>
                <v-chip size="x-small" variant="tonal" :color="priorityColor(reg.priority)"
                        class="text-capitalize">{{ reg.priority }}</v-chip>
              </div>
              <div class="rx-snap-row">
                <span class="rx-snap-label">Payer</span>
                <v-chip size="x-small" variant="tonal" :color="payerColor">
                  {{ payerLabel }}
                </v-chip>
              </div>
              <div v-if="activeBilling.payer === 'corporate' && activeBilling.corporate"
                   class="rx-snap-row">
                <span class="rx-snap-label">Corporate</span>
                <v-chip size="x-small" variant="tonal"
                        :color="activeBilling.corporate_verified ? 'success' : 'warning'">
                  {{ activeBilling.corporate_verified ? 'Verified' : 'Not verified' }}
                </v-chip>
              </div>
              <div class="rx-snap-row">
                <span class="rx-snap-label">Consultation fee</span>
                <span class="rx-snap-value">{{ formatMoney(activeBilling.consultation_fee, settings.currency) }}</span>
              </div>
              <div class="rx-snap-row">
                <span class="rx-snap-label">Payment method</span>
                <span class="rx-snap-value">{{ billingMethodText }}</span>
              </div>
              <div class="rx-snap-row">
                <span class="rx-snap-label">Collect at reception</span>
                <v-chip size="x-small" variant="tonal"
                        :color="activeBilling.collectNow ? 'success' : 'grey'">
                  {{ activeBilling.collectNow ? 'Now' : 'At billing desk' }}
                </v-chip>
              </div>
              <div v-if="regMode === 'new'" class="rx-snap-row">
                <span class="rx-snap-label">Clinical stream</span>
                <v-chip size="x-small" variant="tonal"
                        :color="isPaediatric ? 'info' : 'grey'">
                  {{ isPaediatric ? 'Paediatrics' : 'General' }}
                </v-chip>
              </div>
              <div v-if="regMode === 'new' && isPaediatric" class="rx-snap-row">
                <span class="rx-snap-label">Guardian</span>
                <span class="rx-snap-value rx-snap-value--ellipsis">
                  {{ np.guardian_name.trim() || 'Not captured' }}
                </span>
              </div>
              <div v-if="regMode === 'new'" class="rx-snap-row">
                <span class="rx-snap-label">Portal</span>
                <v-chip size="x-small" variant="tonal"
                        :color="portalEnabled ? 'primary' : 'grey'">
                  {{ portalEnabled ? `${np.shared_fields.length} shared` : 'Disabled' }}
                </v-chip>
              </div>
            </div>
          </div>

          <div class="rx-hint">
            <v-icon size="16" color="primary">mdi-lightbulb-on-outline</v-icon>
            <span>
              Checked-in patients appear instantly on the front-desk board with a queue number
              and waiting timer.
            </span>
          </div>
        </div>
      </v-col>
    </v-row>

    <!-- ═══════════ STICKY ACTION BAR ═══════════ -->
    <div class="rx-actionbar">
      <div class="rx-actionbar-inner">
        <div class="rx-actionbar-left">
          <v-icon size="18" :color="completionPct === 100 ? 'success' : 'primary'">
            {{ completionPct === 100 ? 'mdi-check-decagram' : 'mdi-progress-check' }}
          </v-icon>
          <span class="rx-actionbar-text">
            {{ completionPct === 100
              ? 'All details captured — ready to check in'
              : `${checklistDone}/${checklist.length} items complete` }}
          </span>
        </div>
        <div class="d-flex align-center ga-2">
          <v-btn variant="text" class="text-none" @click="goBack">Cancel</v-btn>
          <v-btn class="text-none rx-cta" rounded="lg" size="large"
                 :loading="registering" prepend-icon="mdi-account-check"
                 @click="submitRegister">
            Check in patient
          </v-btn>
        </div>
      </div>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500" rounded="lg">
      <div class="d-flex align-center" style="gap:8px">
        <v-icon size="18">{{ snack.color === 'error' ? 'mdi-alert-circle' : 'mdi-check-circle' }}</v-icon>
        {{ snack.text }}
      </div>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRouter } from '#app'
import { formatMoney } from '~/utils/format'
import BillingPanel from '~/components/front-desk/BillingPanel.vue'

const { $api } = useNuxtApp()
const router = useRouter()
const brand = useBranding()

const todayLabel = (() => {
  const d = new Date()
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
})()

// ── Brand bridge (same CSS-variable pattern as the other clinic heroes) ──
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

// ── Settings ─────────────────────────────────────────────────────────
const settings = ref({ consultation_fee: 0, currency: 'KES' })

// ── Registration state ───────────────────────────────────────────────
const registering = ref(false)
const registerError = ref('')
const regMode = ref('existing')
const regType = ref('clinic')
const showPwd = ref(false)
const patientQuery = ref('')
const patientsLoading = ref(false)
const patientItems = ref([])
const errors = reactive({})

const reg = reactive({
  patient: null,
  chief_complaint: '',
  priority: 'routine',
  // Billing (existing-patient flow)
  consultation_fee: 0,
  payer: 'self',
  payment_method: 'cash',
  payment_reference: '',
  waiver_reason: '',
  insurance_provider: '',
  insurance_number: '',
  collectNow: true,
  // Corporate billing — company, staff match and verification outcome
  corporate: null,
  corporate_staff: null,
  corporate_staff_number: '',
  corporate_verified: false,
  corporate_verification: null,
  corporate_authorisation: '',
  corporate_document: null,
  corporate_document_name: '',
  // Clinical stream for this visit
  patient_category: 'general',
  guardian_name: '',
  guardian_phone: '',
  guardian_relationship: '',
})

const np = reactive({
  first_name: '', middle_name: '', last_name: '',
  email: '', phone: '', date_of_birth: '',
  gender: 'female', national_id: '', blood_type: '', address: '',
  // Geocoded home address (Google Places)
  latitude: null, longitude: null, address_place_id: '',
  // Clinical stream — 'general' or 'paediatric'. Paediatric records require a
  // parent/guardian block, so the form grows a section when this flips.
  patient_category: 'general',
  guardian_name: '', guardian_phone: '', guardian_relationship: '',
  immunisation_status: '',
  password: '', password_confirm: '',
  emergency_contact_name: '', emergency_contact_phone: '', emergency_contact_relation: '',
  // Billing
  consultation_fee: 0,
  payer: 'self',
  payment_method: 'cash',
  payment_reference: '',
  waiver_reason: '',
  insurance_provider: '',
  insurance_number: '',
  collectNow: true,
  // Corporate billing
  corporate: null,
  corporate_staff: null,
  corporate_staff_number: '',
  corporate_verified: false,
  corporate_verification: null,
  corporate_authorisation: '',
  corporate_document: null,
  corporate_document_name: '',
  shared_fields: ['profile', 'medications', 'vitals', 'lab_results'],
})

// Reception captures the service requested, not symptoms — clinical findings
// are recorded by the nurse in triage.
const serviceReasonGroups = [
  {
    key: 'core',
    label: 'Consultation',
    items: [
      'Consultation', 'Follow-up visit', 'Second opinion', 'Teleconsultation',
      'Review of results', 'Referral',
    ],
  },
  {
    key: 'procedures',
    label: 'Procedures & treatment',
    items: [
      'Injection', 'Vaccination', 'Dressing / wound care', 'Suture removal',
      'Minor procedure', 'Nebulisation', 'IV therapy', 'Physiotherapy',
    ],
  },
  {
    key: 'diagnostics',
    label: 'Diagnostics',
    items: [
      'Lab test', 'Imaging / X-ray', 'Ultrasound', 'ECG', 'Screening',
    ],
  },
  {
    key: 'admin',
    label: 'Administrative',
    items: [
      'Prescription refill', 'Medical certificate', 'Insurance paperwork',
      'Health check-up', 'Antenatal visit', 'Child welfare visit',
    ],
  },
]

const patientCategories = [
  {
    value: 'general',
    title: 'General',
    subtitle: 'Adults and children registered on the standard clinic pathway',
    icon: 'mdi-account',
  },
  {
    value: 'paediatric',
    title: 'Paediatrics',
    subtitle: 'Child under 18 — captured with a parent or guardian',
    icon: 'mdi-human-baby-changing-table',
  },
]

const guardianRelationships = [
  'Mother', 'Father', 'Grandparent', 'Legal guardian', 'Sibling', 'Aunt', 'Uncle', 'Other',
]

const immunisationOptions = [
  { title: 'Not recorded', value: '' },
  { title: 'Up to date', value: 'up_to_date' },
  { title: 'Due / partial', value: 'due' },
  { title: 'Overdue', value: 'overdue' },
]

const genders = [
  { title: 'Female', value: 'female' },
  { title: 'Male', value: 'male' },
  { title: 'Other', value: 'other' }
]
const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']

// Priority carries a one-line clinical meaning so reception can pick correctly
// without guessing — shown both in the dropdown and under the field.
const priorities = [
  {
    title: 'Routine',
    value: 'routine',
    subtitle: 'Can wait their turn in the queue',
    icon: 'mdi-clock-outline',
  },
  {
    title: 'Urgent',
    value: 'urgent',
    subtitle: 'Should be seen within the hour',
    icon: 'mdi-clock-alert-outline',
  },
  {
    title: 'Emergency',
    value: 'emergency',
    subtitle: 'Needs immediate attention, life-threatening',
    icon: 'mdi-alert-circle-outline',
  },
]

// Vuetify renders these as a second line in the dropdown list.
function priorityProps(item) {
  return { subtitle: item?.subtitle, prependIcon: item?.icon }
}

const shareCategories = [
  { key: 'profile',       label: 'Profile',        icon: 'mdi-account-details' },
  { key: 'medications',   label: 'Medications',    icon: 'mdi-pill-multiple' },
  { key: 'vitals',        label: 'Vitals',         icon: 'mdi-heart-pulse' },
  { key: 'lab_results',   label: 'Lab Results',    icon: 'mdi-flask-outline' },
  { key: 'diagnosis',     label: 'Diagnosis',      icon: 'mdi-clipboard-text' },
  { key: 'consultations', label: 'Consultations',  icon: 'mdi-stethoscope' },
  { key: 'prescriptions', label: 'Prescriptions',  icon: 'mdi-pill-plus' },
  { key: 'billing',       label: 'Billing',        icon: 'mdi-cash' },
]

function toggleShared(key) {
  const idx = np.shared_fields.indexOf(key)
  if (idx === -1) np.shared_fields.push(key)
  else np.shared_fields.splice(idx, 1)
}
function selectAllShared() { np.shared_fields = shareCategories.map(c => c.key) }
function clearAllShared() { np.shared_fields = [] }

// ── Home address geocoding (Google Places) ───────────────────────────
// The address is both a searchable Google Places field and a plain text
// fallback. Picking a suggestion stores the formatted address plus the
// latitude/longitude pair the backend persists on the patient record.
const maps = useGoogleMaps()
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
let placeTimer = null

const hasCoords = computed(
  () => np.latitude !== null && np.latitude !== undefined && np.latitude !== ''
    && np.longitude !== null && np.longitude !== undefined && np.longitude !== '')

function onAddressSearch(input) {
  addressQuery.value = input || ''
  clearTimeout(placeTimer)
  const q = addressQuery.value.trim()
  if (q.length < 3) {
    addressPredictions.value = []
    return
  }
  placeTimer = setTimeout(async () => {
    loadingPlaces.value = true
    try {
      addressPredictions.value = await maps.getPredictions(q)
    } catch {
      // Google unreachable / key missing — the free-text field still works.
      addressPredictions.value = []
    } finally {
      loadingPlaces.value = false
    }
  }, 300)
}

async function onAddressPicked(item) {
  const placeId = typeof item === 'string' ? item : item?.place_id
  if (!placeId) return
  loadingPlaces.value = true
  try {
    const place = await maps.getPlaceDetails(placeId)
    if (place?.address) np.address = place.address
    if (place?.lat !== undefined && place?.lng !== undefined) {
      np.latitude = Number(place.lat.toFixed(6))
      np.longitude = Number(place.lng.toFixed(6))
      np.address_place_id = placeId
    }
  } catch {
    notify('Could not load the selected address — you can type it manually.', 'error')
  } finally {
    loadingPlaces.value = false
  }
}

async function useMyLocation() {
  if (!import.meta.client || !navigator.geolocation) {
    notify('Location is not available in this browser.', 'error')
    return
  }
  locating.value = true
  try {
    const pos = await new Promise((resolve, reject) =>
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 10000,
      }))
    const lat = Number(pos.coords.latitude.toFixed(6))
    const lng = Number(pos.coords.longitude.toFixed(6))
    np.latitude = lat
    np.longitude = lng
    np.address_place_id = ''
    try {
      const address = await maps.reverseGeocode(lat, lng)
      if (address) np.address = address
    } catch {
      // Coordinates are still useful without a formatted address.
    }
  } catch {
    notify('Could not read your location — check browser permissions.', 'error')
  } finally {
    locating.value = false
  }
}

function clearCoords() {
  np.latitude = null
  np.longitude = null
  np.address_place_id = ''
}

// ── Clinical stream (general / paediatrics) ──────────────────────────
// Paediatrics is not a separate form: it is the same registration with a
// guardian block and an under-18 guard, so the clinic can register a child
// without leaving the reception workflow.
const isPaediatric = computed(() => np.patient_category === 'paediatric')

function setCategory(value) {
  np.patient_category = value
  if (value !== 'paediatric') {
    np.guardian_name = ''
    np.guardian_phone = ''
    np.guardian_relationship = ''
    np.immunisation_status = ''
    delete errors.guardian_name
    delete errors.guardian_phone
  } else {
    // Children usually arrive with whoever is in the emergency contact block.
    np.emergency_contact_relation = np.emergency_contact_relation || 'Parent'
  }
}

function useEmergencyContactAsGuardian() {
  np.guardian_name = np.emergency_contact_name
  np.guardian_phone = np.emergency_contact_phone
  np.guardian_relationship = np.emergency_contact_relation || 'Parent'
  delete errors.guardian_name
  delete errors.guardian_phone
}

/** Age in years as a decimal, or null when no DOB has been entered yet. */
function ageFromDob(value) {
  if (!value) return null
  const dob = new Date(`${value}T00:00:00`)
  if (Number.isNaN(dob.getTime())) return null
  const now = new Date()
  let months = (now.getFullYear() - dob.getFullYear()) * 12 + (now.getMonth() - dob.getMonth())
  if (now.getDate() < dob.getDate()) months -= 1
  if (months < 0) return null
  return months / 12
}

const childAge = computed(() => ageFromDob(np.date_of_birth))

const dobHint = computed(() => {
  const age = childAge.value
  if (age === null) return ''
  const years = Math.floor(age)
  const months = Math.round((age - years) * 12)
  const label = years
    ? `${years} year${years === 1 ? '' : 's'}${months ? ` ${months} month${months === 1 ? '' : 's'}` : ''}`
    : `${months} month${months === 1 ? '' : 's'}`
  if (isPaediatric.value && age >= 18) {
    return `${label} — paediatrics is for under-18s. Switch to General for an adult.`
  }
  return `${label} old`
})

const paediatricAgeValid = computed(() => !isPaediatric.value || childAge.value === null || childAge.value < 18)

const guardianDone = computed(() =>
  !!np.guardian_name.trim() && !!np.guardian_phone.trim())

// Step numbers are derived so the paediatrics and portal cards — which appear
// conditionally — never leave a gap in the numbered sequence.
const stepOrder = computed(() => {
  const keys = ['type', 'identity', 'contact']
  if (isPaediatric.value) keys.push('guardian')
  keys.push('billing')
  if (portalEnabled.value) keys.push('portal')
  keys.push('visit')
  return keys
})

function stepNo(key) {
  const idx = stepOrder.value.indexOf(key)
  return idx === -1 ? 1 : idx + 1
}

// ── Portal shortcuts ─────────────────────────────────────────────────
// `>=` cannot appear inside a template binding attribute, so every
// comparison lives in a computed.
const portalEnabled = computed(() => regMode.value === 'new' && regType.value === 'portal')
const pwdTooShort = computed(() => !!np.password && np.password.length < 8)
const pwdMismatch = computed(() => !!np.password_confirm && np.password_confirm !== np.password)
const pwdStrength = computed(() => {
  const p = np.password || ''
  if (!p) return 0
  let score = 0
  if (p.length >= 8) score += 1
  if (p.length >= 12) score += 1
  if (/[A-Z]/.test(p) && /[a-z]/.test(p)) score += 1
  if (/\d/.test(p) || /[^A-Za-z0-9]/.test(p)) score += 1
  return Math.min(4, score)
})
const pwdStrengthLabel = computed(() => {
  if (!np.password) return 'No password set'
  return ['Very weak', 'Weak', 'Fair', 'Strong', 'Excellent'][pwdStrength.value]
})
const pwdStrengthColor = computed(() =>
  ['#ef4444', '#f59e0b', '#eab308', '#22c55e', '#0d9488'][pwdStrength.value])

// ── Billing ──────────────────────────────────────────────────────────
// The active billing object follows the form mode: a new record owns `np`,
// while an existing patient is charged through `reg`.
const activeBilling = computed(() => (regMode.value === 'new' ? np : reg))

const payerLabel = computed(() => ({
  self: 'Self pay',
  insurance: 'Insurance',
  corporate: 'Corporate',
  waiver: 'Waiver',
})[activeBilling.value.payer] || 'Self pay')

const payerColor = computed(() => ({
  self: 'primary',
  insurance: 'info',
  corporate: 'secondary',
  waiver: 'warning',
})[activeBilling.value.payer] || 'primary')

const methodLabel = computed(() => ({
  cash: 'Cash',
  card: 'Card',
  mpesa: 'M-Pesa',
  bank_transfer: 'Bank transfer',
  insurance: 'Insurance cover',
})[activeBilling.value.payment_method] || '')

/** Corporate and waiver visits never carry a patient payment method. */
const billingMethodText = computed(() => {
  const b = activeBilling.value
  if (b.payer === 'corporate') return 'Company invoice'
  if (b.payer === 'waiver') return 'Waived'
  return methodLabel.value || 'Not set'
})

const billingDone = computed(() => {
  const b = activeBilling.value
  if (b.payer === 'waiver') return !!String(b.waiver_reason || '').trim()
  if (b.payer === 'corporate') {
    return !!b.corporate && !!b.corporate_verified
      && (!!b.corporate_document || !!String(b.corporate_authorisation || '').trim())
  }
  return !!b.payment_method
})

// Identity block the billing panel sends when verifying a corporate visit.
const billingPatient = computed(() => {
  if (regMode.value === 'new') {
    return {
      first_name: np.first_name,
      last_name: np.last_name,
      full_name: [np.first_name, np.middle_name, np.last_name].filter(Boolean).join(' '),
      date_of_birth: np.date_of_birth || null,
      national_id: np.national_id,
      phone: np.phone,
    }
  }
  return { patient: reg.patient }
})

// ── Existing-patient clinical stream ─────────────────────────────────
const regIsPaediatric = computed(() => reg.patient_category === 'paediatric')

function setRegCategory(value) {
  reg.patient_category = value
  if (value !== 'paediatric') {
    reg.guardian_name = ''
    reg.guardian_phone = ''
    reg.guardian_relationship = ''
    delete errors.guardian_name
    delete errors.guardian_phone
  }
}

const regGuardianDone = computed(() =>
  !regIsPaediatric.value || (!!reg.guardian_name.trim() && !!reg.guardian_phone.trim()))

// ── Completion model ─────────────────────────────────────────────────
// Email is only required when the patient gets a portal login.
const identityDone = computed(() =>
  !!np.first_name.trim()
  && !!np.last_name.trim()
  && !!np.date_of_birth
  && (!portalEnabled.value || !!np.email.trim()))
const contactDone = computed(() => !!np.phone.trim() || !!np.address.trim())
const portalDone = computed(() =>
  !!np.password && np.password.length >= 8 && np.password === np.password_confirm)
const visitDone = computed(() => !!reg.chief_complaint.trim())

const checklist = computed(() => {
  if (regMode.value === 'existing') {
    return [
      { key: 'patient', label: 'Patient selected', hint: 'required', done: !!reg.patient },
      { key: 'stream', label: 'Clinical stream', hint: 'required', done: regGuardianDone.value },
      { key: 'billing', label: 'Billing', hint: 'required', done: billingDone.value },
      { key: 'reason', label: 'Service requested', hint: 'recommended', done: visitDone.value },
    ]
  }
  const base = [
    { key: 'identity', label: 'Identity details', hint: 'required', done: identityDone.value },
    { key: 'contact', label: 'Contact', hint: 'recommended', done: contactDone.value },
  ]
  if (isPaediatric.value) {
    base.push({ key: 'guardian', label: 'Parent / guardian', hint: 'required', done: guardianDone.value })
  }
  base.push({ key: 'billing', label: 'Billing', hint: 'required', done: billingDone.value })
  if (portalEnabled.value) {
    base.push({ key: 'portal', label: 'Portal password', hint: 'required', done: portalDone.value })
  }
  base.push({ key: 'visit', label: 'Service requested', hint: 'recommended', done: visitDone.value })
  return base
})

const checklistDone = computed(() => checklist.value.filter(i => i.done).length)
const completionPct = computed(() => {
  const total = checklist.value.length
  return total ? Math.round((checklistDone.value / total) * 100) : 0
})

// ── Live preview (summary card) ──────────────────────────────────────
const selectedPatient = computed(() =>
  patientItems.value.find(p => p.id === reg.patient) || null)

const previewName = computed(() => {
  if (regMode.value === 'new') {
    return [np.first_name, np.middle_name, np.last_name].filter(Boolean).join(' ').trim()
  }
  return selectedPatient.value ? selectedPatient.value.label.split(' · ')[0] : ''
})

const previewInitials = computed(() => initialsOf(previewName.value))

function initialsOf(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return ''
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase()
}

function priorityColor(p) {
  return { emergency: 'error', urgent: 'warning', routine: 'primary' }[p] || 'primary'
}

// Full record for the currently chosen priority (drives the caption line).
const selectedPriority = computed(() =>
  priorities.find(p => p.value === reg.priority) || priorities[0])

function clearError(key) {
  if (errors[key]) delete errors[key]
}

// ── Snackbar ─────────────────────────────────────────────────────────
const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

function goBack() { router.push('/clinics/front-desk') }

// ── Patient search ──────────────────────────────────────────────────
let patientTimer = null
function onPatientSearch(q) {
  patientQuery.value = q
  clearTimeout(patientTimer)
  patientTimer = setTimeout(async () => {
    patientsLoading.value = true
    try {
      const { data } = await $api.get('/patients/', {
        params: { search: q || undefined, page_size: 25 }
      })
      const rows = data?.results || data || []
      patientItems.value = rows.map(p => ({
        id: p.id,
        label: `${p.user_name || `${p.user?.first_name || ''} ${p.user?.last_name || ''}`.trim()} · ${p.patient_number}${p.user?.phone ? ` · ${p.user.phone}` : ''}`
      }))
    } catch {
      patientItems.value = []
    } finally {
      patientsLoading.value = false
    }
  }, 300)
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || 'Something went wrong'
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

// Selecting an existing patient pulls their clinical stream and guardian so
// reception only has to confirm them, not retype them.
watch(() => reg.patient, async (id) => {
  if (!id) return
  try {
    const { data } = await $api.get(`/patients/${id}/`)
    reg.patient_category = data.patient_category || 'general'
    reg.guardian_name = data.guardian_name || ''
    reg.guardian_phone = data.guardian_phone || ''
    reg.guardian_relationship = data.guardian_relationship || ''
  } catch {
    // Keep the defaults when the detail lookup fails.
  }
})

// ── Submit ───────────────────────────────────────────────────────────
async function submitRegister() {
  registerError.value = ''
  Object.keys(errors).forEach(k => delete errors[k])

  if (regMode.value === 'new') {
    // Field-level validation so the offending input lights up.
    if (!np.first_name.trim()) errors.first_name = 'First name is required'
    if (!np.last_name.trim()) errors.last_name = 'Last name is required'
    // Email is only compulsory when the patient gets a dashboard login.
    if (portalEnabled.value && !np.email.trim()) errors.email = 'Email is required for portal access'
    if (!np.date_of_birth) errors.date_of_birth = 'Date of birth is required'
    else if (!paediatricAgeValid.value) {
      errors.date_of_birth = 'Paediatrics registration is for patients under 18 — switch to General'
    }
    if (isPaediatric.value) {
      if (!np.guardian_name.trim()) errors.guardian_name = 'Guardian name is required'
      if (!np.guardian_phone.trim()) errors.guardian_phone = 'Guardian phone is required'
    }
    if (np.payer === 'waiver' && !String(np.waiver_reason || '').trim()) {
      errors.waiver_reason = 'Record why the fee is being waived'
    }
    if (np.payer === 'corporate') {
      if (!np.corporate) errors.corporate = 'Choose the corporate client'
      if (!np.corporate_staff_number.trim()) {
        errors.corporate_staff_number = 'Job card number is required'
      }
      if (!np.corporate_verified) {
        registerError.value = 'Verify the corporate and patient details before checking in.'
        return
      }
      if (!np.corporate_document && !String(np.corporate_authorisation || '').trim()) {
        registerError.value = 'Attach the job card or record its reference before checking in.'
        return
      }
    }
    if (portalEnabled.value) {
      if (!np.password || np.password.length < 8) errors.password = 'Minimum 8 characters'
      else if (np.password !== np.password_confirm) errors.password = 'Passwords do not match'
    }
    if (Object.keys(errors).length) {
      registerError.value = 'Please complete the highlighted required fields.'
      return
    }
  } else {
    if (!reg.patient) {
      registerError.value = 'Select a patient before checking in.'
      return
    }
    if (!regGuardianDone.value) {
      errors.guardian_name = 'Guardian name is required'
      if (!reg.guardian_phone.trim()) errors.guardian_phone = 'Guardian phone is required'
      registerError.value = 'Capture the parent or guardian for this paediatric visit.'
      return
    }
    if (reg.payer === 'waiver' && !String(reg.waiver_reason || '').trim()) {
      errors.waiver_reason = 'Record why the fee is being waived'
      registerError.value = 'Record the reason for waiving the fee.'
      return
    }
    if (reg.payer === 'corporate') {
      if (!reg.corporate) {
        errors.corporate = 'Choose the corporate client'
        registerError.value = 'Choose the corporate client for this visit.'
        return
      }
      if (!reg.corporate_staff_number.trim()) {
        errors.corporate_staff_number = 'Job card number is required'
        registerError.value = 'Capture the job card / staff number.'
        return
      }
      if (!reg.corporate_verified) {
        registerError.value = 'Verify the corporate and patient details before checking in.'
        return
      }
      if (!reg.corporate_document && !String(reg.corporate_authorisation || '').trim()) {
        registerError.value = 'Attach the job card or record its reference before checking in.'
        return
      }
    }
  }

  const billing = regMode.value === 'new' ? np : reg

  registering.value = true
  try {
    let patientId = reg.patient
    if (regMode.value === 'new') {
      const payload = {
        ...np,
        blood_type: np.blood_type || '',
        // Blank national IDs must go as NULL — an empty string collides on the
        // unique constraint once more than one patient has no ID.
        national_id: np.national_id?.trim() || null,
        // Blank email is allowed for clinic-only records; the backend stores a
        // non-deliverable placeholder so the unique column stays satisfied.
        email: np.email.trim(),
        patient_category: isPaediatric.value ? 'paediatric' : 'general',
        guardian_name: isPaediatric.value ? np.guardian_name.trim() : '',
        guardian_phone: isPaediatric.value ? np.guardian_phone.trim() : '',
        guardian_relationship: isPaediatric.value ? np.guardian_relationship : '',
        immunisation_status: isPaediatric.value ? np.immunisation_status : '',
        registration_source: 'clinic',
      }

      // Only send a password when portal access is requested — otherwise the
      // backend auto-generates a random one.
      if (portalEnabled.value) {
        payload.password = np.password
        payload.shared_fields = np.shared_fields
      } else {
        delete payload.password
        delete payload.shared_fields
      }

      // Billing fields live on the visit, not the patient record.
      for (const key of [
        'payer', 'payment_method', 'payment_reference', 'waiver_reason',
        'collectNow', 'consultation_fee', 'insurance_provider', 'insurance_number',
        'corporate', 'corporate_staff', 'corporate_staff_number', 'corporate_verified',
        'corporate_verification', 'corporate_authorisation', 'corporate_document',
        'corporate_document_name',
      ]) {
        delete payload[key]
      }

      const { data } = await $api.post('/patients/', payload)
      patientId = data.id
    } else if (regIsPaediatric.value || reg.patient_category) {
      // Keep the patient record in sync with the stream chosen at this visit.
      try {
        await $api.patch(`/patients/${patientId}/`, {
          patient_category: reg.patient_category,
          guardian_name: regIsPaediatric.value ? reg.guardian_name.trim() : '',
          guardian_phone: regIsPaediatric.value ? reg.guardian_phone.trim() : '',
          guardian_relationship: regIsPaediatric.value ? reg.guardian_relationship : '',
        })
      } catch {
        // Non-fatal: the visit can still be registered.
      }
    }
    if (!patientId) throw new Error('Select a patient or fill in the new patient form.')

    const { data: visit } = await $api.post('/visits/', {
      patient: patientId,
      chief_complaint: reg.chief_complaint,
      priority: reg.priority,
      consultation_fee: billing.consultation_fee,
      payer: billing.payer,
      payment_method: billing.payer === 'waiver' || billing.payer === 'corporate'
        ? ''
        : billing.payment_method,
      waiver_reason: billing.payer === 'waiver' ? billing.waiver_reason : '',
      // Corporate verification result captured at reception.
      corporate: billing.payer === 'corporate' ? billing.corporate || null : null,
      corporate_staff: billing.payer === 'corporate' ? billing.corporate_staff || null : null,
      corporate_verified: billing.payer === 'corporate' ? !!billing.corporate_verified : false,
      corporate_authorisation: billing.payer === 'corporate'
        ? (billing.corporate_authorisation || '')
        : '',
      corporate_document: billing.payer === 'corporate' ? billing.corporate_document || null : null,
      corporate_note: billing.payer === 'corporate'
        ? (billing.corporate_verification?.message || '')
        : '',
    })

    // Raise the invoice (a zero amount marks the fee waived), then optionally
    // settle it at reception. Corporate visits are invoiced to the employer so
    // nothing is collected here.
    const fee = billing.payer === 'waiver' ? 0 : Number(billing.consultation_fee) || 0
    await $api.post(`/visits/${visit.id}/charge-fee/`, { amount: fee })

    if (billing.payer !== 'waiver' && billing.payer !== 'corporate'
        && billing.collectNow && fee > 0) {
      await $api.post(`/visits/${visit.id}/collect-payment/`, {
        method: billing.payment_method || 'cash',
        amount: fee,
        reference: billing.payment_reference || '',
        payer: billing.payer,
      })
    }

    const stream = regMode.value === 'new' ? np : reg
    const portalTag = portalEnabled.value ? ' · portal enabled' : ''
    const paedsTag = stream.patient_category === 'paediatric' ? ' · paediatrics' : ''
    const payTag = billing.payer === 'waiver'
      ? ' · fee waived'
      : billing.payer === 'corporate'
        ? ' · billed to company'
        : (billing.collectNow && fee > 0 ? ` · paid ${methodLabel.value}` : ' · billed')
    notify(`Checked in · ${visit.visit_number}${paedsTag}${portalTag}${payTag}`)
    router.push(`/clinics/front-desk/${visit.id}`)
  } catch (e) {
    registerError.value = extractError(e)
  } finally {
    registering.value = false
  }
}

// ── Settings load (default consultation fee) ─────────────────────────
onMounted(async () => {
  reg.consultation_fee = Number(settings.value.consultation_fee || 0)
  try {
    const { data } = await $api.get('/visits/board/', { params: { open: 0 } })
    settings.value = data.settings || settings.value
    reg.consultation_fee = Number(settings.value.consultation_fee || 0)
    np.consultation_fee = reg.consultation_fee
  } catch { /* defaults are fine */ }
  onPatientSearch('')
})
</script>

<style scoped>
.min-w-0 { min-width: 0; }
.rx-page {
  width: 100%;
  padding-bottom: 24px;
}

/* ── Hero ── */
.rx-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #0f766e) 0%,
    var(--hero-main, #0d9488) 52%,
    var(--hero-accent, #14b8a6) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(13, 148, 136, 0.24));
}
.rx-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.rx-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(20, 184, 166, 0.24)), transparent 70%);
}
.rx-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.rx-hero-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.rx-hero-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.rx-hero-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
  max-width: 620px;
}
.rx-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
  transition: background 0.18s ease, transform 0.15s ease;
}
.rx-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26);
  transform: translateY(-1px);
}
.rx-hero-foot {
  position: relative;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.rx-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(4px);
}
.rx-hero-chip--on {
  background: rgba(255, 255, 255, 0.95);
  color: var(--hero-ink, #0f766e);
  border-color: #fff;
}
.rx-hero-chip--progress {
  margin-left: auto;
  background: rgba(255, 255, 255, 0.24);
}

/* ── Mode switcher ── */
.rx-modebar {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding: 6px;
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
}
.rx-mode {
  position: relative;
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1.5px solid transparent;
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: all 0.16s ease;
}
.rx-mode:hover {
  background: rgba(var(--v-theme-on-surface), 0.04);
}
.rx-mode--on {
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 7%, transparent);
}
.rx-mode-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(var(--v-theme-on-surface), 0.06);
  transition: all 0.16s ease;
}
.rx-mode--on .rx-mode-icon {
  color: #fff;
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
}
.rx-mode-text { display: flex; flex-direction: column; min-width: 0; }
.rx-mode-title { font-size: 0.9rem; font-weight: 700; line-height: 1.2; }
.rx-mode-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rx-mode-check {
  position: absolute;
  top: 8px;
  right: 10px;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}

/* ── Section cards ── */
.rx-card {
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  overflow: hidden;
}
.rx-card--portal {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 35%, transparent);
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 2.5%,
    rgb(var(--v-theme-surface)));
}
.rx-card-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.rx-step {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 27px;
  height: 27px;
  border-radius: 9px;
  flex-shrink: 0;
  font-size: 12.5px;
  font-weight: 800;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 11%, transparent);
  transition: all 0.2s ease;
}
.rx-step--done {
  color: #fff;
  background: #16a34a;
}
.rx-card-title { font-size: 0.94rem; font-weight: 700; line-height: 1.25; }
.rx-card-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  line-height: 1.35;
}
.rx-card-body { padding: 18px; }
.rx-sublabel {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-bottom: 8px;
}

/* ── Registration type cards ── */
.rx-types {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 12px;
}
.rx-type {
  position: relative;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
  border-radius: 14px;
  border: 2px solid rgba(var(--v-theme-on-surface), 0.1);
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: all 0.18s ease;
  height: 100%;
}
.rx-type:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 40%, transparent);
  transform: translateY(-1px);
}
.rx-type--on {
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 6%, transparent);
}
.rx-type-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 12px;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.06);
  transition: all 0.18s ease;
}
.rx-type--on .rx-type-icon {
  color: #fff;
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  box-shadow: 0 6px 16px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 40%,
    transparent);
}
.rx-type-body { display: flex; flex-direction: column; min-width: 0; }
.rx-type-title { font-size: 0.92rem; font-weight: 700; }
.rx-type-sub {
  font-size: 12px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.6);
  margin-top: 2px;
}
.rx-type-check {
  position: absolute;
  top: 12px;
  right: 12px;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}

/* ── Clinical stream selector (general / paediatrics) ── */
.rx-cats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 10px;
}
.rx-cat {
  position: relative;
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 12px 14px;
  border-radius: 13px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.1);
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.16s ease, background 0.16s ease, transform 0.16s ease;
}
.rx-cat:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 40%, transparent);
  transform: translateY(-1px);
}
.rx-cat--on {
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 6%, transparent);
}
.rx-cat-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.06);
  transition: all 0.16s ease;
}
.rx-cat--on .rx-cat-icon {
  color: #fff;
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  box-shadow: 0 5px 14px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 38%, transparent);
}
.rx-cat-body { display: flex; flex-direction: column; min-width: 0; }
.rx-cat-title { font-size: 0.9rem; font-weight: 700; line-height: 1.2; }
.rx-cat-sub {
  font-size: 11.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.58);
  margin-top: 1px;
}
.rx-cat-check {
  position: absolute;
  top: 10px;
  right: 10px;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}

/* Paediatric card + guardian helpers */
.rx-card--paeds {
  border-color: color-mix(in srgb, #0ea5e9 32%, transparent);
  background: color-mix(in srgb, #0ea5e9 2.5%, rgb(var(--v-theme-surface)));
}
.rx-same-as-emergency {
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
}
.rx-same-hint {
  font-size: 11px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.rx-law-note {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding: 9px 12px;
  border-radius: 11px;
  font-size: 11.5px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.rx-snap-value--ellipsis {
  max-width: 58%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ── Geocoded address status ── */
.rx-geo {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 10px;
  padding: 8px 12px;
  border-radius: 11px;
  font-size: 11.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
}
.rx-geo--ok {
  color: #0f766e;
  border-style: solid;
  border-color: rgba(13, 148, 136, 0.32);
  background: rgba(13, 148, 136, 0.07);
}
.rx-geo span { min-width: 0; }

/* ── Catalog provenance strip under the clinical selects ── */
.rx-catalog-note {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 7px 10px;
  margin-top: 14px;
  padding: 8px 12px;
  border-radius: 11px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.rx-catalog-text { min-width: 0; }

/* ── Expanded action pinned inside each catalog dropdown ── */
.rx-cb-foot {
  padding: 8px;
  margin-top: 4px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgb(var(--v-theme-surface));
}
.rx-cb-add {
  background: var(--brand-primary, rgb(var(--v-theme-primary))) !important;
  color: #fff !important;
  font-weight: 700;
  font-size: 12.5px;
  letter-spacing: 0.1px;
  box-shadow: 0 3px 10px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 32%, transparent);
}
.rx-cb-link {
  margin-top: 4px;
  font-size: 11.5px !important;
  color: rgba(var(--v-theme-on-surface), 0.62) !important;
}
.rx-cb-link:hover {
  color: var(--brand-primary, rgb(var(--v-theme-primary))) !important;
}

/* ── Dialog type switcher ── */
.rx-type-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding: 5px;
  margin-bottom: 16px;
  border-radius: 13px;
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.rx-type-opt {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  padding: 9px 10px;
  border-radius: 9px;
  border: 1.5px solid transparent;
  background: transparent;
  font-size: 12.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
  cursor: pointer;
  transition: all 0.15s ease;
}
.rx-type-opt:hover { color: var(--brand-primary, rgb(var(--v-theme-primary))); }
.rx-type-opt--on {
  color: #fff;
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  box-shadow: 0 4px 12px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 34%, transparent);
}

/* ── Priority + fee row ──
   Both fields are pinned to the top of their column (`align="start"`) and use
   `hide-details`, so the select and the number field stay perfectly level even
   though the priority dropdown renders two-line options. */
.rx-field-row {
  margin-top: 16px;
  margin-bottom: 30px;
}

.rx-prio-note {
  display: flex;
  align-items: flex-start;
  gap: 7px;
  margin-top: 10px;
  padding: 7px 11px;
  border-radius: 9px;
  font-size: 11.5px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  transition: color 0.18s ease, background 0.18s ease, border-color 0.18s ease;
}
.rx-prio-note strong { font-weight: 700; }

.rx-prio-note--routine {
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 7%, transparent);
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 24%, transparent);
}
.rx-prio-note--urgent {
  color: #b45309;
  background: rgba(245, 158, 11, 0.1);
  border-color: rgba(245, 158, 11, 0.3);
}
.rx-prio-note--emergency {
  color: #b91c1c;
  background: rgba(239, 68, 68, 0.09);
  border-color: rgba(239, 68, 68, 0.3);
}

/* ── Password strength ── */
.rx-strength {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 6px;
}
.rx-strength-bars {
  display: flex;
  gap: 4px;
  flex: 1;
  max-width: 220px;
}
.rx-strength-bar {
  height: 4px;
  flex: 1;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.12);
  transition: background 0.25s ease;
}
.rx-strength-label {
  font-size: 11px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ── Share grid ── */
.rx-share-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 8px;
  margin: 18px 0 10px;
}
.rx-share-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(132px, 1fr));
  gap: 8px;
}
.rx-share {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 11px;
  border-radius: 10px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.11);
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: all 0.15s ease;
}
.rx-share:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 38%, transparent);
}
.rx-share--on {
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 8%, transparent);
}
.rx-share-icon {
  color: rgba(var(--v-theme-on-surface), 0.45);
  flex-shrink: 0;
  transition: color 0.15s ease;
}
.rx-share--on .rx-share-icon {
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}
.rx-share-label { font-size: 12px; font-weight: 600; line-height: 1.2; }
.rx-share-check {
  margin-left: auto;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}

/* ── Selected patient chip ── */
.rx-selected {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 11px 13px;
  border-radius: 12px;
  border: 1px solid rgba(22, 163, 74, 0.35);
  background: rgba(22, 163, 74, 0.07);
}
.rx-selected-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  font-size: 12.5px;
  font-weight: 800;
  color: #fff;
  background: #16a34a;
  flex-shrink: 0;
}
.rx-selected-name { font-size: 0.88rem; font-weight: 700; }
.rx-selected-meta { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.55); }

/* ── Summary rail ── */
.rx-rail {
  position: sticky;
  top: 84px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.rx-summary {
  padding: 16px;
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
}
.rx-summary-head {
  display: flex;
  align-items: center;
  gap: 11px;
  padding-bottom: 13px;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.rx-summary-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 13px;
  font-size: 14px;
  font-weight: 800;
  color: #fff;
  background: linear-gradient(
    135deg,
    var(--hero-main, rgb(var(--v-theme-primary))) 0%,
    var(--hero-accent, rgb(var(--v-theme-primary))) 100%
  );
  flex-shrink: 0;
}
.rx-summary-avatar--empty {
  color: rgba(var(--v-theme-on-surface), 0.4);
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.rx-summary-name {
  font-size: 0.9rem;
  font-weight: 700;
  line-height: 1.25;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rx-summary-meta { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.55); }

.rx-progress {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 13px 0;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.rx-progress-pct { font-size: 12px; font-weight: 800; }
.rx-progress-title { font-size: 0.83rem; font-weight: 700; }
.rx-progress-sub { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.55); }

.rx-checklist {
  list-style: none;
  padding: 11px 0 0;
  margin: 0;
}
.rx-check {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 0;
  font-size: 12.5px;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.rx-check--done { color: rgb(var(--v-theme-success)); }
.rx-check--done .rx-check-hint { color: rgba(22, 163, 74, 0.7); }
.rx-check-hint {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.35);
}

.rx-snapshot {
  margin-top: 13px;
  padding-top: 12px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.rx-snap-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.rx-snap-label { font-size: 12px; color: rgba(var(--v-theme-on-surface), 0.55); }
.rx-snap-value { font-size: 12px; font-weight: 700; }

.rx-charge-now {
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
  width: 100%;
}
.rx-charge-now :deep(.v-label) { font-size: 12.5px; opacity: 0.85; }

.rx-hint {
  display: flex;
  gap: 9px;
  padding: 12px 14px;
  border-radius: 13px;
  font-size: 11.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 6%, transparent);
  border: 1px solid color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 18%,
    transparent);
}

/* ── Sticky action bar ── */
.rx-actionbar {
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
.rx-actionbar-inner {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 24px;
}
.rx-actionbar-left {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.rx-actionbar-text {
  font-size: 12.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.65);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rx-cta {
  background: linear-gradient(
    120deg,
    var(--hero-deep, rgb(var(--v-theme-primary))) 0%,
    var(--hero-main, rgb(var(--v-theme-primary))) 60%,
    var(--hero-accent, rgb(var(--v-theme-primary))) 100%
  ) !important;
  color: #fff !important;
  font-weight: 700;
  box-shadow: var(--hero-shadow, 0 8px 20px rgba(13, 148, 136, 0.3));
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.rx-cta:hover { transform: translateY(-1px); }

/* ── Responsive ── */
@media (max-width: 1279px) {
  .rx-rail { position: static; }
}
@media (max-width: 700px) {
  .rx-page { padding-bottom: 24px; }
  .rx-hero-title { font-size: 21px; }
  .rx-modebar { grid-template-columns: 1fr; }
  .rx-hero-chip--progress { margin-left: 0; }
  .rx-actionbar-inner {
    flex-direction: column;
    align-items: stretch;
    padding: 10px 16px;
  }
  .rx-actionbar-left { justify-content: center; }
  .rx-cta { flex: 1; }
}
</style>
