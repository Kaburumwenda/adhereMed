<template>
  <div class="hc-enrol pa-4 pa-md-6">
    <!-- Hero -->
    <div class="hc-hero pa-5 pa-md-6 mb-5">
      <div class="d-flex align-center flex-wrap ga-4">
        <v-avatar size="56" class="hc-hero-icon">
          <v-icon icon="mdi-account-plus" color="white" size="28" />
        </v-avatar>
        <div class="flex-grow-1">
          <div class="text-overline text-white-soft">HOMECARE · NEW PATIENT</div>
          <h1 class="text-h4 font-weight-bold text-white ma-0">Enrol a patient</h1>
          <p class="text-body-2 text-white-soft mb-0 mt-1">
            Set up the patient profile, clinical context, care team and emergency contacts.
          </p>
        </div>
        <v-btn variant="flat" rounded="pill" prepend-icon="mdi-arrow-left"
               color="rgba(255,255,255,0.18)" class="text-none" to="/homecare/patients">
          <span class="text-white">Back</span>
        </v-btn>
      </div>
    </div>

    <v-row>
      <!-- Left: stepper -->
      <v-col cols="12" md="3">
        <v-card rounded="xl" :elevation="0" class="hc-card pa-4 sticky-top">
          <div class="text-overline text-medium-emphasis mb-2">Progress</div>
          <div v-for="(s, i) in steps" :key="s.key"
               class="hc-step d-flex align-start ga-3 pa-2 rounded-lg mb-1"
               :class="{ 'hc-step-active': step === i, 'hc-step-done': step > i }"
               @click="goTo(i)">
            <div class="hc-step-num">
              <v-icon v-if="step > i" icon="mdi-check" size="16" />
              <span v-else>{{ i + 1 }}</span>
            </div>
            <div class="flex-grow-1 min-w-0">
              <div class="text-body-2 font-weight-bold">{{ s.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.hint }}</div>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis mb-1">Completion</div>
          <v-progress-linear :model-value="completion" color="teal" rounded height="8" />
          <div class="text-caption text-medium-emphasis mt-1">{{ completion }}%</div>
        </v-card>
      </v-col>

      <!-- Right: form -->
      <v-col cols="12" md="9">
        <v-card rounded="xl" :elevation="0" class="hc-card pa-5 pa-md-6">
          <v-form ref="formRef" @submit.prevent="submit">
            <!-- ───── Step 0 : Personal info ───── -->
            <section v-show="step === 0">
              <SectionHead title="Personal information" icon="mdi-card-account-details"
                           subtitle="Account & basic demographics for the patient." color="#0d9488" />
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.first_name" label="First name *" variant="outlined"
                                density="comfortable" rounded="lg" prepend-inner-icon="mdi-account"
                                :error-messages="errors.first_name" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.last_name" label="Last name *" variant="outlined"
                                density="comfortable" rounded="lg"
                                :error-messages="errors.last_name" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.user_email" label="Email *" type="email"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-email"
                                :error-messages="errors.user_email" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                                density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-phone" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-text-field v-model="form.date_of_birth" label="Date of birth" type="date"
                                variant="outlined" density="comfortable" rounded="lg" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-select v-model="form.gender" label="Gender"
                            :items="['Male','Female','Other','Prefer not to say']"
                            variant="outlined" density="comfortable" rounded="lg" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-text-field v-model="form.password" label="Initial password"
                                variant="outlined" density="comfortable" rounded="lg"
                                hint="Patient can change it later" persistent-hint
                                prepend-inner-icon="mdi-lock" />
                </v-col>

                <v-col cols="12" md="4">
                  <v-select v-model="form.id_type" label="Identification type *"
                            :items="idTypes" item-title="label" item-value="value"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-card-account-details"
                            :error-messages="errors.id_type">
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.label">
                        <template #prepend>
                          <v-icon :icon="item.raw.icon" />
                        </template>
                      </v-list-item>
                    </template>
                  </v-select>
                </v-col>
                <v-col cols="12" md="4">
                  <v-text-field v-model="form.id_number" :label="`${idNumberLabel} *`"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-pound"
                                :error-messages="errors.id_number" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-autocomplete v-model="form.nationality" label="Nationality"
                                  :items="nationalities" item-title="name" item-value="code"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-flag">
                    <template #selection="{ item }">
                      <span class="mr-2" style="font-size:18px;">{{ item.raw.flag }}</span>
                      {{ item.raw.name }}
                    </template>
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.name">
                        <template #prepend>
                          <span class="mr-2" style="font-size:20px;">{{ item.raw.flag }}</span>
                        </template>
                      </v-list-item>
                    </template>
                  </v-autocomplete>
                </v-col>

                <v-col cols="12">
                  <AddressAutocomplete v-model="form.address"
                                       label="Home address"
                                       placeholder="Start typing the patient's home address…"
                                       hint="Pick a suggestion or type freely"
                                       @select="onPatientAddressSelect" />
                  <div v-if="form.address_lat" class="text-caption text-medium-emphasis ml-3 mt-n1">
                    <v-icon icon="mdi-crosshairs-gps" size="12" color="teal" class="mr-1" />
                    {{ Number(form.address_lat).toFixed(5) }}, {{ Number(form.address_lng).toFixed(5) }}
                  </div>
                </v-col>
              </v-row>
            </section>

            <!-- ───── Step 1 : Clinical info ───── -->
            <section v-show="step === 1">
              <SectionHead title="Clinical information" icon="mdi-stethoscope"
                           subtitle="Diagnosis, history and risk profile." color="#0ea5e9" />
              <v-row dense>
                <v-col cols="12" md="8">
                  <v-combobox v-model="form.primary_diagnosis"
                              :items="diagnosisItems"
                              :loading="loadingDiagnoses"
                              item-title="name"
                              item-value="name"
                              :return-object="false"
                              @update:search="onDiagnosisSearch"
                              hide-no-data
                              label="Primary diagnosis"
                              hint="Pick from the catalog or type your own"
                              persistent-hint
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-clipboard-pulse">
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.name">
                        <template #subtitle>
                          <span v-if="item.raw.icd_code" class="text-caption mr-2">{{ item.raw.icd_code }}</span>
                          <span class="text-caption text-medium-emphasis">{{ item.raw.category }}</span>
                        </template>
                      </v-list-item>
                    </template>
                  </v-combobox>
                </v-col>
                <v-col cols="12" md="4">
                  <v-select v-model="form.risk_level" label="Risk level"
                            :items="riskLevels" item-title="label" item-value="value"
                            variant="outlined" density="comfortable" rounded="lg">
                    <template #selection="{ item }">
                      <v-icon :icon="item.raw.icon" :color="item.raw.color" size="16" class="mr-1" />
                      {{ item.raw.label }}
                    </template>
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip">
                        <template #prepend>
                          <v-icon :icon="item.raw.icon" :color="item.raw.color" />
                        </template>
                      </v-list-item>
                    </template>
                  </v-select>
                </v-col>

                <v-col cols="12">
                  <div class="text-caption text-medium-emphasis mb-1 ml-1">Allergies</div>
                  <v-combobox v-model="form.allergiesList"
                              :items="allergyItems"
                              :loading="loadingAllergies"
                              item-title="name"
                              item-value="name"
                              :return-object="false"
                              @update:search="onAllergySearch"
                              hide-no-data
                              chips closable-chips multiple
                              label="Pick from catalog or type & press enter"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-alert-octagon">
                    <template #chip="{ props: cp, item }">
                      <v-chip v-bind="cp" color="error" variant="tonal" size="small">
                        <v-icon icon="mdi-alert" size="14" class="mr-1" />
                        {{ item.title }}
                      </v-chip>
                    </template>
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.name"
                                   :subtitle="item.raw.category" />
                    </template>
                  </v-combobox>
                </v-col>

              </v-row>
            </section>

            <!-- ───── Step 2 : Medical history ───── -->
            <section v-show="step === 2">
              <SectionHead title="Medical history" icon="mdi-history"
                           subtitle="Background, comorbidities and past treatment."
                           color="#0891b2" />
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.comorbidities" label="Comorbidities"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-format-list-bulleted-type"
                              hint="Other chronic conditions (e.g. HTN, DM)" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.presenting_complaint" label="Presenting complaint"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-comment-alert"
                              hint="Reason for current homecare enrolment" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.past_conditions" label="Past conditions"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-clipboard-text-clock"
                              hint="Past illnesses, surgeries, hospitalisations" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.social_family_history" label="Social / family history"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-account-group"
                              hint="Lifestyle, occupation, hereditary conditions" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.past_medication" label="Past medication"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-pill"
                              hint="Previous drugs or treatments" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.history.other" label="Any other"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-note-text"
                              hint="Additional clinical notes" persistent-hint />
                </v-col>
              </v-row>
            </section>

            <!-- ───── Step 3 : Doctor ───── -->
            <section v-show="step === 3">
              <SectionHead title="Responsible doctor" icon="mdi-doctor"
                           subtitle="Physician overseeing this patient's care."
                           color="#1d4ed8" />

              <v-btn-toggle v-model="doctorMode" mandatory color="indigo"
                            density="comfortable" rounded="lg" class="mb-3">
                <v-btn value="directory" class="text-none" prepend-icon="mdi-account-search">
                  Select from directory
                </v-btn>
                <v-btn value="manual" class="text-none" prepend-icon="mdi-pencil-plus">
                  Enter manually
                </v-btn>
              </v-btn-toggle>

              <v-row v-if="doctorMode === 'directory'" dense>
                <v-col cols="12">
                  <v-autocomplete v-model="form.assigned_doctor"
                                  :items="doctors" item-title="name" item-value="user"
                                  label="Responsible doctor"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-doctor" clearable
                                  :loading="loadingDoctors"
                                  hint="Searchable list of verified doctors accepting patients"
                                  persistent-hint>
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.name"
                                   :subtitle="`${item.raw.specialization || 'General'} · ${item.raw.qualification || ''}`">
                        <template #prepend>
                          <v-avatar size="36" color="indigo" variant="tonal">
                            <v-icon icon="mdi-doctor" />
                          </v-avatar>
                        </template>
                      </v-list-item>
                    </template>
                  </v-autocomplete>
                </v-col>
                <v-col v-if="selectedDoctor" cols="12">
                  <div class="hc-team-card pa-4 d-flex align-center ga-3 rounded-lg">
                    <v-avatar size="56" color="indigo" variant="tonal">
                      <v-icon icon="mdi-doctor" size="28" />
                    </v-avatar>
                    <div class="min-w-0 flex-grow-1">
                      <div class="text-subtitle-1 font-weight-bold">
                        {{ selectedDoctor.name }}
                        <v-chip v-if="selectedDoctor.is_verified" size="x-small" color="success"
                                variant="tonal" class="ml-1">Verified</v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis">
                        {{ selectedDoctor.specialization || 'General practitioner' }}
                        <span v-if="selectedDoctor.qualification"> · {{ selectedDoctor.qualification }}</span>
                        <span v-if="selectedDoctor.years_of_experience">
                          · {{ selectedDoctor.years_of_experience }} yrs exp
                        </span>
                      </div>
                      <div class="text-caption text-medium-emphasis mt-1">
                        <v-icon v-if="selectedDoctor.email" icon="mdi-email" size="12" class="mr-1" />
                        {{ selectedDoctor.email }}
                        <span v-if="selectedDoctor.phone" class="ml-2">
                          <v-icon icon="mdi-phone" size="12" class="mr-1" />
                          {{ selectedDoctor.phone }}
                        </span>
                        <span v-if="selectedDoctor.hospital_name" class="ml-2">
                          <v-icon icon="mdi-hospital-building" size="12" class="mr-1" />
                          {{ selectedDoctor.hospital_name }}
                        </span>
                      </div>
                    </div>
                  </div>
                </v-col>
                <v-col v-else cols="12">
                  <v-alert type="info" variant="tonal" density="compact" icon="mdi-information">
                    Can't find the doctor? Switch to <strong>Enter manually</strong> above.
                  </v-alert>
                </v-col>
              </v-row>

              <v-row v-else dense>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.manual_doctor.name" label="Doctor full name *"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-doctor" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-combobox v-model="form.manual_doctor.specialization" label="Specialization"
                              :items="specializationOptions"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-stethoscope"
                              hint="Pick from the list or type your own" persistent-hint />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.manual_doctor.phone" label="Phone"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-phone" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.manual_doctor.email" label="Email" type="email"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-email" />
                </v-col>
                <v-col cols="12">
                  <v-text-field v-model="form.manual_doctor.hospital" label="Hospital / clinic"
                                variant="outlined" density="comfortable" rounded="lg"
                                prepend-inner-icon="mdi-hospital-building" />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="form.manual_doctor.notes" label="Additional notes"
                              rows="2" auto-grow variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-note-text"
                              hint="Anything else worth recording about this doctor"
                              persistent-hint />
                </v-col>
                <v-col cols="12">
                  <v-alert type="warning" variant="tonal" density="compact" icon="mdi-alert">
                    This doctor is recorded for reference only and won't have a system login.
                  </v-alert>
                </v-col>
              </v-row>
            </section>

            <!-- ───── Step 4 : Care team ───── -->
            <section v-show="step === 4">
              <SectionHead title="Care team" icon="mdi-account-multiple-plus"
                           subtitle="Primary caregiver plus additional nurses or carers."
                           color="#7c3aed" />

              <v-row dense>
                <v-col cols="12">
                  <v-autocomplete v-model="form.assigned_caregiver"
                                  :items="caregivers" item-title="full_name" item-value="id"
                                  label="Primary caregiver / nurse"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-account-star" clearable
                                  :loading="loadingCaregivers">
                    <template #item="{ item, props: ip }">
                      <v-list-item v-bind="ip" :title="item.raw.full_name"
                                   :subtitle="item.raw.specialties">
                        <template #prepend>
                          <v-avatar size="36" color="teal" variant="tonal">
                            <v-icon icon="mdi-account-tie" />
                          </v-avatar>
                        </template>
                      </v-list-item>
                    </template>
                  </v-autocomplete>
                </v-col>

                <v-col cols="12">
                  <v-autocomplete v-model="form.additional_caregivers"
                                  :items="additionalChoices" item-title="full_name" item-value="id"
                                  label="Additional caregivers / nurses"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-account-group" multiple chips closable-chips
                                  :loading="loadingCaregivers"
                                  hint="Select one or more — they'll all see this patient on their roster."
                                  persistent-hint>
                    <template #chip="{ props: cp, item }">
                      <v-chip v-bind="cp" color="purple" variant="tonal" size="small">
                        <v-avatar start size="22" color="purple" variant="tonal">
                          <v-icon icon="mdi-account-tie" size="14" />
                        </v-avatar>
                        {{ item.raw.full_name }}
                      </v-chip>
                    </template>
                  </v-autocomplete>
                </v-col>

                <v-col v-if="selectedCaregiverDetails.length" cols="12">
                  <div class="text-caption text-medium-emphasis mt-2 mb-1">Assigned care team</div>
                  <v-row dense>
                    <v-col v-for="c in selectedCaregiverDetails" :key="c.id"
                           cols="12" sm="6" md="4">
                      <div class="hc-team-card pa-3 d-flex align-center ga-3 rounded-lg">
                        <v-avatar size="40" color="teal" variant="tonal">
                          <v-icon icon="mdi-account-tie" />
                        </v-avatar>
                        <div class="min-w-0 flex-grow-1">
                          <div class="text-body-2 font-weight-bold text-truncate">
                            {{ c.full_name }}
                          </div>
                          <div class="text-caption text-medium-emphasis">
                            {{ c.role }}
                          </div>
                        </div>
                      </div>
                    </v-col>
                  </v-row>
                </v-col>
              </v-row>
            </section>

            <!-- ───── Step 5 : Next of kin ───── -->
            <section v-show="step === 5">
              <SectionHead title="Next of kin & emergency contacts" icon="mdi-phone-alert"
                           subtitle="People to call in an emergency. Add as many as you need."
                           color="#ef4444" />

              <div v-for="(c, idx) in form.emergency_contacts" :key="idx"
                   class="hc-kin pa-3 pa-md-4 rounded-xl mb-3">
                <div class="d-flex align-center mb-2">
                  <v-avatar size="32" color="red" variant="tonal" class="mr-2">
                    <v-icon icon="mdi-account-heart" />
                  </v-avatar>
                  <div class="text-subtitle-2 font-weight-bold flex-grow-1">
                    Contact {{ idx + 1 }}
                  </div>
                  <v-btn icon="mdi-delete-outline" variant="text" size="small"
                         color="error" @click="removeContact(idx)" />
                </div>
                <v-row dense>
                  <v-col cols="12" md="4">
                    <v-text-field v-model="c.name" label="Full name *" variant="outlined"
                                  density="comfortable" rounded="lg" />
                  </v-col>
                  <v-col cols="12" md="3">
                    <v-combobox v-model="c.relationship" label="Relationship"
                                :items="relationships" variant="outlined"
                                density="comfortable" rounded="lg" />
                  </v-col>
                  <v-col cols="12" md="3">
                    <v-text-field v-model="c.phone" label="Phone *" variant="outlined"
                                  density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-phone" />
                  </v-col>
                  <v-col cols="12" md="2">
                    <v-switch v-model="c.is_primary" label="Primary"
                              color="teal" density="comfortable" hide-details
                              @update:model-value="(v) => v && markPrimary(idx)" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="c.email" label="Email" type="email"
                                  variant="outlined" density="comfortable" rounded="lg"
                                  prepend-inner-icon="mdi-email" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <AddressAutocomplete v-model="c.address"
                                         label="Address (optional)"
                                         placeholder="Start typing an address…"
                                         @select="(p) => onContactAddressSelect(c, p)" />
                    <div v-if="c.address_lat" class="text-caption text-medium-emphasis ml-3 mt-n1">
                      <v-icon icon="mdi-crosshairs-gps" size="12" color="teal" class="mr-1" />
                      {{ Number(c.address_lat).toFixed(5) }}, {{ Number(c.address_lng).toFixed(5) }}
                    </div>
                  </v-col>
                </v-row>
              </div>

              <v-btn variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-plus"
                     class="text-none" @click="addContact">Add another contact</v-btn>

              <v-alert v-if="!form.emergency_contacts.length" type="info" variant="tonal"
                       density="compact" class="mt-3" icon="mdi-information">
                It's strongly recommended to add at least one emergency contact.
              </v-alert>
            </section>

            <!-- Footer -->
            <v-alert v-if="topError" type="error" variant="tonal" density="compact"
                     class="mt-5" icon="mdi-alert-circle">
              {{ topError }}
            </v-alert>

            <v-divider class="my-5" />
            <div class="d-flex flex-wrap ga-2">
              <v-btn variant="text" rounded="lg" class="text-none"
                     prepend-icon="mdi-arrow-left"
                     :disabled="step === 0" @click="step--">Previous</v-btn>
              <v-spacer />
              <v-btn variant="text" rounded="lg" class="text-none"
                     to="/homecare/patients">Cancel</v-btn>
              <v-btn v-if="step < steps.length - 1" color="teal" rounded="lg"
                     class="text-none" append-icon="mdi-arrow-right"
                     @click="next">Next</v-btn>
              <v-btn v-else type="submit" color="teal" rounded="lg" class="text-none"
                     :loading="saving" prepend-icon="mdi-check-circle">
                Enrol patient
              </v-btn>
            </div>
          </v-form>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const router = useRouter()
const { $api } = useNuxtApp()

const steps = [
  { key: 'person',   title: 'Personal',     hint: 'Account & demographics' },
  { key: 'clinical', title: 'Clinical',     hint: 'Diagnosis & allergies' },
  { key: 'history',  title: 'Medical history', hint: 'Comorbidities & background' },
  { key: 'doctor',   title: 'Doctor',       hint: 'Responsible physician' },
  { key: 'team',     title: 'Care team',    hint: 'Caregivers & nurses' },
  { key: 'kin',      title: 'Next of kin',  hint: 'Emergency contacts' }
]
const step = ref(0)
const doctorMode = ref('directory')

const form = reactive({
  user_email: '', first_name: '', last_name: '', phone: '', password: '',
  date_of_birth: '', gender: '', address: '', address_lat: null, address_lng: null,
  id_type: 'national_id', id_number: '', nationality: 'KE',
  primary_diagnosis: '',
  // Structured medical history (will be serialised into a single text blob for the API).
  history: {
    comorbidities: '',
    presenting_complaint: '',
    past_conditions: '',
    social_family_history: '',
    past_medication: '',
    other: ''
  },
  allergiesList: [],
  risk_level: 'low',
  assigned_doctor: null,
  manual_doctor: {
    name: '', specialization: '',
    phone: '', email: '', hospital: '', notes: ''
  },
  assigned_caregiver: null,
  additional_caregivers: [],
  emergency_contacts: [
    { name: '', relationship: '', phone: '', email: '', address: '',
      address_lat: null, address_lng: null, is_primary: true }
  ]
})

const errors = ref({})
const topError = ref('')
const saving = ref(false)
const formRef = ref(null)
const caregivers = ref([])
const loadingCaregivers = ref(false)
const doctors = ref([])
const loadingDoctors = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

const riskLevels = [
  { value: 'low',      label: 'Low',      color: 'success', icon: 'mdi-shield-check' },
  { value: 'medium',   label: 'Medium',   color: 'warning', icon: 'mdi-shield-alert-outline' },
  { value: 'high',     label: 'High',     color: 'orange',  icon: 'mdi-shield-alert' },
  { value: 'critical', label: 'Critical', color: 'error',   icon: 'mdi-shield-off' }
]
const relationships = ['Spouse','Parent','Child','Sibling','Guardian','Friend','Other']

const idTypes = [
  { value: 'national_id',     label: 'National ID',      icon: 'mdi-card-account-details' },
  { value: 'alien_id',        label: 'Alien ID',         icon: 'mdi-passport' },
  { value: 'passport',        label: 'Passport',         icon: 'mdi-passport-biometric' },
  { value: 'driving_license', label: 'Driving licence',  icon: 'mdi-card-account-details-star' },
  { value: 'birth_cert',      label: 'Birth certificate', icon: 'mdi-certificate' },
  { value: 'military_id',     label: 'Military ID',      icon: 'mdi-shield-account' },
  { value: 'other',           label: 'Other',            icon: 'mdi-card-text' }
]

const idNumberLabels = {
  national_id: 'ID number',
  alien_id: 'Alien ID number',
  passport: 'Passport number',
  driving_license: 'Driving licence number',
  birth_cert: 'Birth certificate number',
  military_id: 'Military ID number',
  other: 'Identification number'
}
const idNumberLabel = computed(() => idNumberLabels[form.id_type] || 'Identification number')

const nationalities = [
  { code: 'KE', name: 'Kenya',         flag: '🇰🇪' },
  { code: 'UG', name: 'Uganda',        flag: '🇺🇬' },
  { code: 'TZ', name: 'Tanzania',      flag: '🇹🇿' },
  { code: 'RW', name: 'Rwanda',        flag: '🇷🇼' },
  { code: 'BI', name: 'Burundi',       flag: '🇧🇮' },
  { code: 'SS', name: 'South Sudan',   flag: '🇸🇸' },
  { code: 'ET', name: 'Ethiopia',      flag: '🇪🇹' },
  { code: 'SO', name: 'Somalia',       flag: '🇸🇴' },
  { code: 'DJ', name: 'Djibouti',      flag: '🇩🇯' },
  { code: 'ER', name: 'Eritrea',       flag: '🇪🇷' },
  { code: 'SD', name: 'Sudan',         flag: '🇸🇩' },
  { code: 'EG', name: 'Egypt',         flag: '🇪🇬' },
  { code: 'NG', name: 'Nigeria',       flag: '🇳🇬' },
  { code: 'GH', name: 'Ghana',         flag: '🇬🇭' },
  { code: 'ZA', name: 'South Africa',  flag: '🇿🇦' },
  { code: 'CD', name: 'DR Congo',      flag: '🇨🇩' },
  { code: 'CM', name: 'Cameroon',      flag: '🇨🇲' },
  { code: 'GB', name: 'United Kingdom',flag: '🇬🇧' },
  { code: 'US', name: 'United States', flag: '🇺🇸' },
  { code: 'CA', name: 'Canada',        flag: '🇨🇦' },
  { code: 'IN', name: 'India',         flag: '🇮🇳' },
  { code: 'CN', name: 'China',         flag: '🇨🇳' },
  { code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪' },
  { code: 'SA', name: 'Saudi Arabia',  flag: '🇸🇦' },
  { code: 'OTHER', name: 'Other',      flag: '🌐' }
]

const specializationOptions = [
  'General Practitioner', 'Family Medicine', 'Internal Medicine', 'Paediatrics',
  'Obstetrics & Gynaecology', 'Surgery', 'Orthopaedics', 'Cardiology',
  'Neurology', 'Psychiatry', 'Dermatology', 'Oncology', 'Endocrinology',
  'Gastroenterology', 'Nephrology', 'Pulmonology', 'Rheumatology',
  'Urology', 'ENT', 'Ophthalmology', 'Anaesthesiology', 'Radiology',
  'Pathology', 'Emergency Medicine', 'Geriatrics', 'Palliative Care', 'Other'
]

// ─────── Catalog (API-backed) ───────
const diagnosisItems = ref([])
const loadingDiagnoses = ref(false)
const allergyItems = ref([])
const loadingAllergies = ref(false)
let diagSearchTimer = null, alleSearchTimer = null

async function fetchDiagnoses(q = '') {
  loadingDiagnoses.value = true
  try {
    const { data } = await $api.get('/homecare/diagnoses/search/', { params: { q } })
    diagnosisItems.value = Array.isArray(data) ? data : (data?.results || [])
  } catch { /* silent */ } finally { loadingDiagnoses.value = false }
}
async function fetchAllergies(q = '') {
  loadingAllergies.value = true
  try {
    const { data } = await $api.get('/homecare/allergies/search/', { params: { q } })
    allergyItems.value = Array.isArray(data) ? data : (data?.results || [])
  } catch { /* silent */ } finally { loadingAllergies.value = false }
}
function onDiagnosisSearch(q) {
  clearTimeout(diagSearchTimer)
  diagSearchTimer = setTimeout(() => fetchDiagnoses(q || ''), 220)
}
function onAllergySearch(q) {
  clearTimeout(alleSearchTimer)
  alleSearchTimer = setTimeout(() => fetchAllergies(q || ''), 220)
}

onMounted(async () => {
  fetchDiagnoses()
  fetchAllergies()
  loadingCaregivers.value = true
  try {
    const { data } = await $api.get('/homecare/caregivers/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    caregivers.value = items.map(c => ({
      id: c.id,
      full_name: c.user?.full_name || c.user?.email || `Caregiver #${c.id}`,
      role: (c.specialties || []).join(', ') || 'Caregiver',
      specialties: (c.specialties || []).join(', ')
    }))
  } catch { /* ignore */ }
  finally { loadingCaregivers.value = false }

  loadingDoctors.value = true
  try {
    const { data } = await $api.get('/doctors/directory/', { params: { page_size: 200 } })
    const items = data?.results || data || []
    doctors.value = items.map(d => ({
      id: d.id,
      user: d.user,
      name: d.name || d.email || `Doctor #${d.id}`,
      email: d.email,
      phone: d.phone,
      specialization: d.specialization,
      qualification: d.qualification,
      years_of_experience: d.years_of_experience,
      hospital_name: d.hospital_name,
      is_verified: d.is_verified,
    }))
  } catch { /* ignore */ }
  finally { loadingDoctors.value = false }
})

const selectedDoctor = computed(() =>
  doctors.value.find(d => d.user === form.assigned_doctor) || null)

const additionalChoices = computed(() =>
  caregivers.value.filter(c => c.id !== form.assigned_caregiver))

const selectedCaregiverDetails = computed(() => {
  const ids = [form.assigned_caregiver, ...form.additional_caregivers].filter(Boolean)
  return ids.map(id => caregivers.value.find(c => c.id === id)).filter(Boolean)
})

const completion = computed(() => {
  let pts = 0, total = 6
  if (form.first_name && form.last_name) pts++
  if (form.user_email) pts++
  if (form.primary_diagnosis) pts++
  if (form.assigned_caregiver) pts++
  if (form.emergency_contacts.some(c => c.name && c.phone)) pts++
  if (form.date_of_birth || form.address) pts++
  return Math.round((pts / total) * 100)
})

function goTo(i) { step.value = i }
function next()  { step.value = Math.min(steps.length - 1, step.value + 1) }
function addContact() {
  form.emergency_contacts.push({
    name: '', relationship: '', phone: '', email: '', address: '',
    address_lat: null, address_lng: null,
    is_primary: form.emergency_contacts.length === 0
  })
}
function removeContact(i) { form.emergency_contacts.splice(i, 1) }
function markPrimary(i) {
  form.emergency_contacts.forEach((c, idx) => { c.is_primary = idx === i })
}

function buildMedicalHistory(h) {
  const parts = []
  const push = (label, val) => {
    const v = (val || '').trim()
    if (v) parts.push(`${label}:\n${v}`)
  }
  push('Comorbidities', h.comorbidities)
  push('Presenting complaint', h.presenting_complaint)
  push('Past conditions', h.past_conditions)
  push('Social / family history', h.social_family_history)
  push('Past medication', h.past_medication)
  push('Other', h.other)
  return parts.join('\n\n')
}

function onPatientAddressSelect(place) {
  form.address_lat = place.lat ?? null
  form.address_lng = place.lon ?? null
}

function onContactAddressSelect(contact, place) {
  contact.address_lat = place.lat ?? null
  contact.address_lng = place.lon ?? null
}

function validate() {
  errors.value = {}
  const e = {}
  if (!form.first_name) e.first_name = ['Required']
  if (!form.last_name)  e.last_name  = ['Required']
  if (!form.user_email) e.user_email = ['Required']
  if (!form.id_type)    e.id_type    = ['Required']
  if (!form.id_number)  e.id_number  = ['Required']
  errors.value = e
  if (Object.keys(e).length) {
    step.value = 0
    topError.value = 'Please fill the required fields highlighted in red.'
    return false
  }
  return true
}

async function submit() {
  topError.value = ''
  if (!validate()) return
  saving.value = true
  try {
    const payload = {
      user_email: form.user_email,
      first_name: form.first_name,
      last_name: form.last_name,
      phone: form.phone,
      password: form.password,
      date_of_birth: form.date_of_birth || null,
      gender: form.gender,
      address: form.address,
      address_lat: form.address_lat,
      address_lng: form.address_lng,
      id_type: form.id_type,
      id_number: form.id_number,
      nationality: form.nationality,
      primary_diagnosis: form.primary_diagnosis,
      medical_history: buildMedicalHistory(form.history),
      allergies: (form.allergiesList || []).join(', '),
      risk_level: form.risk_level,
      assigned_doctor_user_id: doctorMode.value === 'directory' ? (form.assigned_doctor || null) : null,
      assigned_doctor_info: doctorMode.value === 'manual' && form.manual_doctor.name
        ? { ...form.manual_doctor }
        : null,
      assigned_caregiver: form.assigned_caregiver,
      additional_caregivers: form.additional_caregivers,
      emergency_contacts: form.emergency_contacts
        .filter(c => c.name && c.phone)
        .map(c => ({
          name: c.name,
          relationship: c.relationship || '',
          phone: c.phone,
          email: c.email || '',
          address: c.address || '',
          address_lat: c.address_lat ?? null,
          address_lng: c.address_lng ?? null,
          is_primary: !!c.is_primary
        }))
    }
    if (!payload.date_of_birth) delete payload.date_of_birth
    const { data } = await $api.post('/homecare/patients/enroll/', payload)
    snack.text = 'Patient enrolled successfully'
    snack.color = 'success'
    snack.show = true
    setTimeout(() => router.push(`/homecare/patients/${data.id}`), 600)
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object' && !data.detail) errors.value = data
    topError.value = data?.detail || (typeof data === 'string' ? data : 'Enrolment failed.')
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.hc-enrol { min-height: calc(100vh - 64px); }

.hc-hero {
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background:
    radial-gradient(circle at 0% 0%, rgba(255,255,255,0.18) 0%, transparent 45%),
    radial-gradient(circle at 100% 100%, rgba(255,255,255,0.08) 0%, transparent 50%),
    linear-gradient(135deg, #0d9488 0%, #0ea5a4 35%, #0284c7 100%);
  box-shadow: 0 18px 40px -18px rgba(13,148,136,0.55);
}
.hc-hero-icon {
  background: rgba(255,255,255,0.18) !important;
  border: 1px solid rgba(255,255,255,0.28);
  backdrop-filter: blur(12px);
}
.text-white-soft { color: rgba(255,255,255,0.82) !important; }

.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}
.sticky-top { position: sticky; top: 16px; }

.hc-step {
  cursor: pointer;
  transition: background 0.15s ease;
}
.hc-step:hover { background: rgba(13,148,136,0.06); }
.hc-step-num {
  width: 28px; height: 28px; border-radius: 50%;
  background: rgba(15,23,42,0.06);
  color: rgba(15,23,42,0.6);
  display: flex; align-items: center; justify-content: center;
  font-weight: 700; font-size: 13px; flex-shrink: 0;
}
.hc-step-active { background: rgba(13,148,136,0.12); }
.hc-step-active .hc-step-num { background: #0d9488; color: white; }
.hc-step-done .hc-step-num { background: #10b981; color: white; }

:global(.v-theme--dark) .hc-step-num {
  background: rgba(255,255,255,0.08);
  color: rgba(255,255,255,0.6);
}
:global(.v-theme--dark) .hc-step:hover { background: rgba(13,148,136,0.18); }
:global(.v-theme--dark) .hc-step-active { background: rgba(13,148,136,0.22); }

.hc-team-card {
  background: rgba(13,148,136,0.06);
  border: 1px solid rgba(13,148,136,0.18);
}
:global(.v-theme--dark) .hc-team-card {
  background: rgba(13,148,136,0.18);
  border-color: rgba(13,148,136,0.35);
}

.hc-kin {
  background: rgba(239,68,68,0.04);
  border: 1px dashed rgba(239,68,68,0.35);
}
:global(.v-theme--dark) .hc-kin {
  background: rgba(239,68,68,0.10);
  border-color: rgba(239,68,68,0.45);
}

.min-w-0 { min-width: 0; }
</style>

