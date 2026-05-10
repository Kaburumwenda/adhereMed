<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:1440px;">
    <!-- ───────────────────────── Top bar ───────────────────────── -->
    <div class="d-flex flex-wrap align-center mb-4 ga-2">
      <v-btn variant="text" rounded="lg" prepend-icon="mdi-arrow-left"
             class="text-none" to="/homecare/patients">Back</v-btn>
      <v-spacer />
      <v-btn v-if="primaryPhone" variant="tonal" color="success" rounded="lg"
             prepend-icon="mdi-phone" class="text-none"
             :href="`tel:${primaryPhone}`">Call</v-btn>
      <v-btn v-if="patient?.address || hasCoords" variant="tonal" color="indigo" rounded="lg"
             prepend-icon="mdi-directions" class="text-none"
             :href="directionsUrl" target="_blank">Directions</v-btn>
      <v-btn variant="tonal" color="deep-purple" rounded="lg" prepend-icon="mdi-download"
             class="text-none" :loading="fhirBusy" @click="exportFhir">FHIR export</v-btn>
      <v-btn variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-pencil"
             class="text-none" :to="`/homecare/patients/${id}/edit`">Edit</v-btn>
    </div>

    <!-- ───────────────────────── Hero card ───────────────────────── -->
    <v-card v-if="patient" rounded="xl" class="hc-hero pa-5 pa-md-6 mb-4" elevation="0">
      <v-row align="center">
        <v-col cols="12" md="auto">
          <v-avatar size="96" :color="riskColor" variant="flat" class="hc-avatar">
            <span class="text-h4 font-weight-bold text-white">{{ initials }}</span>
          </v-avatar>
        </v-col>
        <v-col cols="12" md>
          <div class="d-flex align-center flex-wrap ga-2">
            <h1 class="text-h4 font-weight-bold mr-2">{{ patientName }}</h1>
            <v-chip size="small" color="white" variant="elevated"
                    class="font-weight-bold" prepend-icon="mdi-identifier"
                    @click="copy(patient.medical_record_number)">
              {{ patient.medical_record_number }}
            </v-chip>
            <StatusChip :status="patient.risk_level" />
            <StatusChip :status="patient.is_active ? 'active' : 'closed'" />
          </div>

          <div class="text-body-2 text-medium-emphasis mt-2">
            <span v-if="patient.primary_diagnosis">
              <v-icon icon="mdi-stethoscope" size="14" class="mr-1" />
              {{ patient.primary_diagnosis }}
            </span>
            <span v-if="patient.gender" class="mx-3">
              <v-icon icon="mdi-human-male-female" size="14" class="mr-1" />
              {{ patient.gender }}
            </span>
            <span v-if="patient.date_of_birth">
              <v-icon icon="mdi-cake-variant" size="14" class="mr-1" />
              {{ patient.date_of_birth }}
              <span v-if="patient.age != null"> · {{ patient.age }} yrs</span>
            </span>
          </div>

          <v-row dense class="mt-3">
            <v-col cols="6" md="3">
              <div class="hc-metric pa-3 rounded-lg">
                <v-icon icon="mdi-percent" :color="adherenceColor" />
                <div class="text-subtitle-1 font-weight-bold mt-1">{{ adherencePct }}</div>
                <div class="text-caption text-medium-emphasis">Adherence</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="hc-metric pa-3 rounded-lg">
                <v-icon icon="mdi-pill" color="indigo" />
                <div class="text-subtitle-1 font-weight-bold mt-1">{{ meds.length }}</div>
                <div class="text-caption text-medium-emphasis">Active meds</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="hc-metric pa-3 rounded-lg">
                <v-icon icon="mdi-alert-octagram" color="error" />
                <div class="text-subtitle-1 font-weight-bold mt-1">
                  {{ overview?.open_escalations?.length || 0 }}
                </div>
                <div class="text-caption text-medium-emphasis">Open escalations</div>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="hc-metric pa-3 rounded-lg">
                <v-icon icon="mdi-account-multiple" color="purple" />
                <div class="text-subtitle-1 font-weight-bold mt-1">{{ careTeamCount }}</div>
                <div class="text-caption text-medium-emphasis">Care team</div>
              </div>
            </v-col>
          </v-row>
        </v-col>
      </v-row>
    </v-card>

    <!-- ───────────────────────── Overview / tabs (full width) ───────────────────────── -->
    <v-card v-if="patient" rounded="xl" elevation="1" class="mb-4">
      <v-tabs v-model="tab" bg-color="transparent" color="teal" grow show-arrows>
        <v-tab value="overview"  prepend-icon="mdi-view-dashboard">Overview</v-tab>
        <v-tab value="careteam"  prepend-icon="mdi-account-tie">Care team</v-tab>
        <v-tab value="plans"     prepend-icon="mdi-clipboard-text">Plans</v-tab>
        <v-tab value="meds"      prepend-icon="mdi-pill">Medications</v-tab>
        <v-tab value="doses"     prepend-icon="mdi-pill-multiple">Doses</v-tab>
        <v-tab value="vitals"    prepend-icon="mdi-heart-pulse">Vitals</v-tab>
        <v-tab value="notes"     prepend-icon="mdi-note-edit">Notes</v-tab>
        <v-tab value="consents"  prepend-icon="mdi-file-document-check">Consents</v-tab>
        <v-tab value="insurance" prepend-icon="mdi-shield-account">Insurance</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4">
        <v-window-item value="overview">
          <v-row>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-2 font-weight-bold mb-2">
                <v-icon icon="mdi-alert-octagram" color="error" class="mr-1" />
                Open escalations
              </h4>
              <v-list density="compact">
                <v-list-item v-for="e in overview?.open_escalations" :key="e.id"
                             :title="e.reason" :subtitle="e.detail">
                  <template #append><StatusChip :status="e.severity" /></template>
                </v-list-item>
                <EmptyState v-if="!overview?.open_escalations?.length"
                  icon="mdi-shield-check" title="No open escalations" />
              </v-list>
            </v-col>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-2 font-weight-bold mb-2">
                <v-icon icon="mdi-chart-donut" color="teal" class="mr-1" />
                Adherence breakdown
              </h4>
              <DonutRing :segments="adherenceSegments" :size="180" :thickness="18">
                <div class="text-h5 font-weight-bold">{{ adherencePct }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ overview?.adherence?.taken || 0 }} / {{ overview?.adherence?.total || 0 }} doses
                </div>
              </DonutRing>
            </v-col>
          </v-row>
        </v-window-item>

        <v-window-item value="careteam">
          <div class="d-flex align-center flex-wrap ga-2 mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-account-tie" color="purple" class="mr-1" />
              Care team
              <v-chip v-if="careTeamCount" size="x-small" variant="tonal" color="purple" class="ml-2">
                {{ careTeamCount }}
              </v-chip>
            </h4>
            <v-btn size="small" variant="tonal" color="purple" rounded="lg"
                   class="text-none" prepend-icon="mdi-account-multiple-plus"
                   @click="openCaregiverDialog">
              Manage caregivers
            </v-btn>
          </div>

          <v-row v-if="careTeamCount" dense>
            <v-col v-if="patient.assigned_caregiver_name" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar color="teal" variant="tonal" size="44" class="mr-3">
                    <v-icon icon="mdi-account-star" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">
                        {{ patient.assigned_caregiver_name }}
                      </div>
                      <v-chip size="x-small" color="teal" variant="tonal">Primary</v-chip>
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="teal" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('caregiver', { ...(primaryCaregiverDetail || {}), full_name: patient.assigned_caregiver_name, role: 'primary' })">View</v-btn>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      Primary caregiver
                    </div>
                    <div v-if="primaryCaregiverDetail?.user?.email"
                         class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-email" size="13" class="mr-1" />
                      <a :href="`mailto:${primaryCaregiverDetail.user.email}`" class="hc-link">
                        {{ primaryCaregiverDetail.user.email }}
                      </a>
                    </div>
                    <div v-if="primaryCaregiverDetail?.user?.phone"
                         class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-phone" size="13" class="mr-1" />
                      <a :href="`tel:${primaryCaregiverDetail.user.phone}`" class="hc-link">
                        {{ primaryCaregiverDetail.user.phone }}
                      </a>
                    </div>
                    <div v-if="primaryCaregiverDetail?.category"
                         class="mt-2">
                      <v-chip size="x-small" variant="outlined" color="teal">
                        <v-icon icon="mdi-stethoscope" size="12" class="mr-1" />
                        {{ String(primaryCaregiverDetail.category).toUpperCase() }}
                      </v-chip>
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>

            <v-col v-for="c in patient.additional_caregivers_detail || []"
                   :key="c.id" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar color="purple" variant="tonal" size="44" class="mr-3">
                    <v-icon icon="mdi-account" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">
                        {{ c.full_name || c.user?.full_name || 'Caregiver' }}
                      </div>
                      <v-chip v-if="c.category" size="x-small" variant="tonal" color="purple">
                        {{ String(c.category).toUpperCase() }}
                      </v-chip>
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="purple" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('caregiver', { ...c, role: 'additional' })">View</v-btn>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      Additional caregiver
                    </div>
                    <div v-if="c.email || c.user?.email"
                         class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-email" size="13" class="mr-1" />
                      <a :href="`mailto:${c.email || c.user?.email}`" class="hc-link">
                        {{ c.email || c.user?.email }}
                      </a>
                    </div>
                    <div v-if="c.phone || c.user?.phone"
                         class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-phone" size="13" class="mr-1" />
                      <a :href="`tel:${c.phone || c.user?.phone}`" class="hc-link">
                        {{ c.phone || c.user?.phone }}
                      </a>
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>

          <EmptyState v-else icon="mdi-account-off" title="No caregivers assigned"
            message="Assign a primary caregiver and add support staff to coordinate visits and tasks.">
            <v-btn class="mt-4 text-none" color="purple" rounded="lg"
                   prepend-icon="mdi-account-multiple-plus" @click="openCaregiverDialog">
              Assign caregivers
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="plans">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-clipboard-text" color="teal" class="mr-1" />
              Treatment plans
              <v-chip v-if="plans.length" size="x-small" variant="tonal" color="teal" class="ml-2">
                {{ plans.length }}
              </v-chip>
            </h4>
            <v-btn v-if="plans.length" size="small" variant="tonal" color="teal" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="newPlanRoute">
              New plan
            </v-btn>
          </div>
          <v-row v-if="plans.length" dense>
            <v-col v-for="p in plans" :key="p.id" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar color="teal" variant="tonal" size="40" class="mr-3">
                    <v-icon icon="mdi-clipboard-text" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ p.title || 'Care plan' }}</div>
                      <StatusChip :status="p.status" />
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="teal" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('plan', p)">View</v-btn>
                    </div>
                    <div v-if="p.diagnosis" class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-stethoscope" size="13" class="mr-1" />{{ p.diagnosis }}
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-calendar-start" size="13" class="mr-1" />
                      {{ p.start_date || '—' }}
                      <span v-if="p.end_date"> · ends {{ p.end_date }}</span>
                    </div>
                    <div v-if="p.goals" class="text-body-2 mt-2" style="white-space:pre-line;">
                      {{ p.goals }}
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-clipboard-outline" title="No treatment plans yet"
            message="Outline diagnoses, goals and review schedules to coordinate care.">
            <v-btn class="mt-4 text-none" color="teal" rounded="lg"
                   prepend-icon="mdi-plus" :to="newPlanRoute">
              Create treatment plan
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="meds">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-pill" color="indigo" class="mr-1" />
              Medication schedules
              <v-chip v-if="meds.length" size="x-small" variant="tonal" color="indigo" class="ml-2">
                {{ meds.length }}
              </v-chip>
            </h4>
            <v-btn v-if="meds.length" size="small" variant="tonal" color="indigo" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="newMedRoute">
              Add medication
            </v-btn>
          </div>
          <v-row v-if="meds.length" dense>
            <v-col v-for="m in meds" :key="m.id" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar color="indigo" variant="tonal" size="40" class="mr-3">
                    <v-icon icon="mdi-pill" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ m.medication_name }}</div>
                      <v-chip size="x-small" color="indigo" variant="tonal">{{ m.dose }}</v-chip>
                      <StatusChip :status="m.is_active ? 'active' : 'closed'" />
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="indigo" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('med', m)">View</v-btn>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-needle" size="13" class="mr-1" />{{ m.route || '—' }}
                      <span v-if="m.frequency" class="ml-2">
                        <v-icon icon="mdi-repeat" size="13" class="mr-1" />{{ m.frequency }}
                      </span>
                    </div>
                    <div v-if="(m.times_of_day || []).length" class="mt-2 d-flex flex-wrap ga-1">
                      <v-chip v-for="t in m.times_of_day" :key="t" size="x-small" variant="outlined" color="indigo">
                        <v-icon icon="mdi-clock-outline" size="12" class="mr-1" />{{ t }}
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-2">
                      <v-icon icon="mdi-calendar" size="13" class="mr-1" />
                      {{ m.start_date || '—' }}
                      <span v-if="m.end_date"> – {{ m.end_date }}</span>
                    </div>
                    <div v-if="m.instructions" class="text-body-2 mt-2 text-medium-emphasis">
                      {{ m.instructions }}
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-pill-off" title="No medication schedules yet"
            message="Schedule recurring doses and the system will track adherence automatically.">
            <v-btn class="mt-4 text-none" color="indigo" rounded="lg"
                   prepend-icon="mdi-plus" :to="newMedRoute">
              Add medication schedule
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="doses">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-pill-multiple" color="deep-purple" class="mr-1" />
              Doses
              <v-chip v-if="doses.length" size="x-small" variant="tonal" color="deep-purple" class="ml-2">
                {{ doses.length }}
              </v-chip>
            </h4>
            <v-btn v-if="doses.length" size="small" variant="tonal" color="deep-purple" rounded="lg"
                   class="text-none" prepend-icon="mdi-open-in-new" :to="dosesRoute">
              Open dose log
            </v-btn>
          </div>
          <v-list v-if="doses.length" lines="two" class="pa-0">
            <template v-for="(d, i) in doses" :key="d.id">
              <v-list-item rounded="lg" class="mb-1 hc-tab-card">
                <template #prepend>
                  <v-avatar :color="doseColor(d.status)" variant="tonal" size="36">
                    <v-icon :icon="doseIcon(d.status)" />
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">
                  {{ d.medication_name }} · <span class="text-medium-emphasis">{{ d.dose }}</span>
                </v-list-item-title>
                <v-list-item-subtitle>
                  <v-icon icon="mdi-clock-outline" size="12" class="mr-1" />
                  {{ formatDateTime(d.scheduled_at) }}
                  <span v-if="d.administered_at" class="ml-2">
                    · taken {{ formatDateTime(d.administered_at) }}
                  </span>
                </v-list-item-subtitle>
                <template #append>
                  <StatusChip :status="d.status" />
                  <v-btn size="x-small" variant="text" color="deep-purple" rounded="lg"
                         class="text-none ml-2" icon="mdi-eye-outline"
                         @click="viewItem('dose', d)" />
                </template>
              </v-list-item>
              <v-divider v-if="i < doses.length - 1" class="my-1" />
            </template>
          </v-list>
          <EmptyState v-else icon="mdi-pill-off" title="No doses yet"
            message="Doses appear automatically once a medication schedule is active.">
            <div class="d-flex justify-center ga-2 mt-4 flex-wrap">
              <v-btn class="text-none" color="indigo" rounded="lg"
                     prepend-icon="mdi-plus" :to="newMedRoute">
                Add medication schedule
              </v-btn>
              <v-btn class="text-none" color="deep-purple" variant="tonal" rounded="lg"
                     prepend-icon="mdi-open-in-new" :to="dosesRoute">
                Open dose log
              </v-btn>
            </div>
          </EmptyState>
        </v-window-item>

        <v-window-item value="vitals">
          <div class="d-flex align-center flex-wrap ga-2 mb-3">
            <h4 class="text-subtitle-2 font-weight-bold">
              <v-icon icon="mdi-chart-line" color="teal" class="mr-1" />
              Vital trends
            </h4>
            <v-spacer />
            <v-btn-toggle v-model="trendDays" mandatory density="comfortable" color="teal"
                          variant="outlined" rounded="lg" @update:model-value="loadVitals">
              <v-btn :value="7" size="small" class="text-none">7d</v-btn>
              <v-btn :value="14" size="small" class="text-none">14d</v-btn>
              <v-btn :value="30" size="small" class="text-none">30d</v-btn>
              <v-btn :value="90" size="small" class="text-none">90d</v-btn>
            </v-btn-toggle>
            <v-btn size="small" variant="tonal" color="teal" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="vitalsRoute">
              Record vitals
            </v-btn>
          </div>
          <v-row v-if="vitalCards.length" dense>
            <v-col v-for="c in vitalCards" :key="c.key" cols="12" sm="6" md="4">
              <v-card rounded="xl" class="pa-3 hc-spark" elevation="0">
                <div class="d-flex align-center mb-1">
                  <v-icon :icon="c.icon" :color="c.color" class="mr-1" />
                  <div class="text-caption text-medium-emphasis flex-grow-1">{{ c.display }}</div>
                  <v-chip size="x-small" variant="tonal" color="grey">LOINC {{ c.loinc }}</v-chip>
                </div>
                <div class="d-flex align-baseline ga-1">
                  <div class="text-h5 font-weight-bold">{{ c.last }}</div>
                  <div class="text-caption text-medium-emphasis">{{ c.unit }}</div>
                  <v-spacer />
                  <div class="text-caption" :class="c.deltaClass">{{ c.delta }}</div>
                </div>
                <v-sparkline :model-value="c.values" :gradient="c.gradient" auto-draw smooth
                             stroke-linecap="round" line-width="2" padding="6" height="56" />
                <div class="text-caption text-medium-emphasis mt-1">
                  {{ c.values.length }} reading{{ c.values.length === 1 ? '' : 's' }}
                  <span v-if="c.lastAt"> · {{ formatDateTime(c.lastAt) }}</span>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-heart-off" title="No vital readings in this window"
            message="Capture blood pressure, heart rate, SpO₂ and more to see trends here.">
            <v-btn class="mt-4 text-none" color="teal" rounded="lg"
                   prepend-icon="mdi-plus" :to="vitalsRoute">
              Record vitals
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="notes">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-note-edit" color="amber-darken-2" class="mr-1" />
              Care notes
              <v-chip v-if="notes.length" size="x-small" variant="tonal" color="amber-darken-2" class="ml-2">
                {{ notes.length }}
              </v-chip>
            </h4>
            <v-btn v-if="notes.length" size="small" variant="tonal" color="amber-darken-2" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="newNoteRoute">
              New note
            </v-btn>
          </div>
          <div v-if="notes.length" class="d-flex flex-column ga-2">
            <v-card v-for="n in notes" :key="n.id" rounded="xl" elevation="0" class="hc-tab-card pa-3">
              <div class="d-flex align-start">
                <v-avatar color="amber-darken-2" variant="tonal" size="36" class="mr-3">
                  <v-icon :icon="noteIcon(n.category)" />
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="d-flex align-center ga-2 flex-wrap">
                    <div class="text-subtitle-2 font-weight-bold">{{ n.caregiver_name || 'Caregiver' }}</div>
                    <v-chip v-if="n.category" size="x-small" variant="tonal" color="amber-darken-2">
                      {{ n.category }}
                    </v-chip>
                    <v-spacer />
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-clock-outline" size="12" class="mr-1" />
                      {{ formatDateTime(n.recorded_at) }}
                    </div>
                  </div>
                  <div class="text-body-2 mt-1" style="white-space:pre-line;">{{ n.content }}</div>
                </div>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-note-off" title="No notes yet"
            message="Document observations, incidents and follow-ups for the care team.">
            <v-btn class="mt-4 text-none" color="amber-darken-2" rounded="lg"
                   prepend-icon="mdi-plus" :to="newNoteRoute">
              Add care note
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="consents">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-file-document-check" color="green" class="mr-1" />
              Consents
              <v-chip v-if="consents.length" size="x-small" variant="tonal" color="green" class="ml-2">
                {{ consents.length }}
              </v-chip>
            </h4>
            <v-btn v-if="consents.length" size="small" variant="tonal" color="green" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="consentsRoute">
              Manage consents
            </v-btn>
          </div>
          <v-row v-if="consents.length" dense>
            <v-col v-for="c in consents" :key="c.id" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar :color="c.is_active ? 'green' : 'grey'" variant="tonal" size="40" class="mr-3">
                    <v-icon icon="mdi-file-document-check" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ c.scope || 'Consent' }}</div>
                      <StatusChip :status="c.is_active ? 'active' : 'revoked'" />
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="green" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('consent', c)">View</v-btn>
                    </div>
                    <div v-if="c.granted_to" class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-account-arrow-right" size="13" class="mr-1" />
                      Granted to {{ c.granted_to }}
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-calendar-check" size="13" class="mr-1" />
                      {{ c.granted_at || '—' }}
                      <span v-if="c.revoked_at" class="ml-2 text-error">
                        · revoked {{ c.revoked_at }}
                      </span>
                    </div>
                    <div v-if="c.notes" class="text-body-2 mt-2 text-medium-emphasis">
                      {{ c.notes }}
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-file-document-outline" title="No consents on file"
            message="Capture written consents for treatment, data sharing and home visits.">
            <v-btn class="mt-4 text-none" color="green" rounded="lg"
                   prepend-icon="mdi-plus" :to="consentsRoute">
              Record a consent
            </v-btn>
          </EmptyState>
        </v-window-item>

        <v-window-item value="insurance">
          <div class="d-flex align-center mb-3">
            <h4 class="text-subtitle-2 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-shield-account" color="blue" class="mr-1" />
              Insurance policies
              <v-chip v-if="policies.length" size="x-small" variant="tonal" color="blue" class="ml-2">
                {{ policies.length }}
              </v-chip>
            </h4>
            <v-btn v-if="policies.length" size="small" variant="tonal" color="blue" rounded="lg"
                   class="text-none" prepend-icon="mdi-plus" :to="insuranceRoute">
              Manage policies
            </v-btn>
          </div>
          <v-row v-if="policies.length" dense>
            <v-col v-for="p in policies" :key="p.id" cols="12" md="6">
              <v-card rounded="xl" elevation="0" class="hc-tab-card pa-4 h-100">
                <div class="d-flex align-start">
                  <v-avatar :color="p.is_active ? 'blue' : 'grey'" variant="tonal" size="40" class="mr-3">
                    <v-icon icon="mdi-shield-account" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ p.provider_name }}</div>
                      <StatusChip :status="p.is_active ? 'active' : 'expired'" />
                      <v-spacer />
                      <v-btn size="x-small" variant="tonal" color="blue" rounded="lg"
                             class="text-none" prepend-icon="mdi-eye-outline"
                             @click="viewItem('policy', p)">View</v-btn>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-pound" size="13" class="mr-1" />
                      Policy {{ p.policy_number || '—' }}
                      <span v-if="p.member_id" class="ml-2">
                        · Member {{ p.member_id }}
                      </span>
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">
                      <v-icon icon="mdi-calendar-range" size="13" class="mr-1" />
                      {{ p.valid_from || '—' }} – {{ p.valid_to || '∞' }}
                    </div>
                    <div v-if="p.coverage_notes" class="text-body-2 mt-2 text-medium-emphasis">
                      {{ p.coverage_notes }}
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-shield-off" title="No insurance policies"
            message="Add cover details to enable claims, pre-auth and billing.">
            <v-btn class="mt-4 text-none" color="blue" rounded="lg"
                   prepend-icon="mdi-plus" :to="insuranceRoute">
              Add insurance policy
            </v-btn>
          </EmptyState>
        </v-window-item>
      </v-window>
    </v-card>

    <!-- ───────────────────────── Profile row: location, care team, next of kin, allergies ───────────────────────── -->
    <v-row v-if="patient">
      <v-col cols="12">
        <!-- Location -->
        <v-card rounded="xl" class="pa-4">
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-map-marker" color="teal" class="mr-1" />
            Location
          </h3>
          <div class="text-body-2 mb-1">
            {{ patient.address || 'No address recorded' }}
          </div>
          <div v-if="hasCoords" class="text-caption text-medium-emphasis mb-3">
            <v-icon icon="mdi-crosshairs-gps" size="12" color="teal" class="mr-1" />
            {{ Number(patient.address_lat).toFixed(5) }}, {{ Number(patient.address_lng).toFixed(5) }}
            <a :href="osmUrl" target="_blank" class="hc-link ml-2">
              <v-icon icon="mdi-open-in-new" size="12" /> Open in OSM
            </a>
          </div>

          <LocationMap
            v-if="hasCoords"
            :center="{ lat: +patient.address_lat, lng: +patient.address_lng }"
            :markers="mapMarkers"
            :height="220"
          />
          <div v-else class="hc-map-empty d-flex flex-column align-center justify-center pa-4 rounded-lg text-medium-emphasis">
            <v-icon icon="mdi-map-marker-off" size="36" class="mb-1" />
            <div class="text-caption">No GPS coordinates recorded for this patient.</div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12">
        <!-- Care team -->
        <v-card rounded="xl" class="pa-4">
          <div class="d-flex align-center mb-2">
            <h3 class="text-subtitle-1 font-weight-bold flex-grow-1">
              <v-icon icon="mdi-account-tie" color="purple" class="mr-1" />
              Care team
            </h3>
            <v-btn size="small" variant="tonal" color="purple" rounded="lg"
                   class="text-none" prepend-icon="mdi-account-multiple-plus"
                   @click="openCaregiverDialog">
              Manage caregivers
            </v-btn>
          </div>
          <v-list density="comfortable" class="pa-0">
            <v-list-item v-if="patient.assigned_caregiver_name"
                         :title="patient.assigned_caregiver_name"
                         subtitle="Primary caregiver">
              <template #prepend>
                <v-avatar color="teal" size="36" variant="tonal">
                  <v-icon icon="mdi-account-star" />
                </v-avatar>
              </template>
              <template #append>
                <v-chip size="x-small" color="teal" variant="tonal">Primary</v-chip>
              </template>
            </v-list-item>
            <v-list-item v-for="c in patient.additional_caregivers_detail || []" :key="c.id"
                         :title="c.full_name" :subtitle="c.email">
              <template #prepend>
                <v-avatar color="purple" size="36" variant="tonal">
                  <v-icon icon="mdi-account" />
                </v-avatar>
              </template>
            </v-list-item>
            <EmptyState v-if="!patient.assigned_caregiver_name && !patient.additional_caregivers_detail?.length"
                        icon="mdi-account-off" title="No caregivers assigned" />
          </v-list>
        </v-card>
      </v-col>

      <v-col cols="12">
        <!-- Next of kin -->
        <v-card rounded="xl" class="pa-4">
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-account-heart" color="red" class="mr-1" />
            Next of kin
          </h3>
          <div v-if="patient.emergency_contacts?.length">
            <div v-for="(c, idx) in patient.emergency_contacts" :key="idx"
                 class="hc-kin pa-3 rounded-lg mb-2">
              <div class="d-flex align-center">
                <v-avatar size="34" color="red" variant="tonal" class="mr-2">
                  <v-icon icon="mdi-account-heart" size="18" />
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="font-weight-bold">{{ c.name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ c.relationship || '—' }}</div>
                </div>
                <v-chip v-if="c.is_primary" size="x-small" color="success" variant="tonal">Primary</v-chip>
              </div>
              <div class="d-flex flex-wrap ga-2 mt-2 text-caption">
                <a v-if="c.phone" :href="`tel:${c.phone}`" class="hc-link">
                  <v-icon icon="mdi-phone" size="13" class="mr-1" />{{ c.phone }}
                </a>
                <a v-if="c.email" :href="`mailto:${c.email}`" class="hc-link">
                  <v-icon icon="mdi-email" size="13" class="mr-1" />{{ c.email }}
                </a>
                <span v-if="c.address" class="text-medium-emphasis">
                  <v-icon icon="mdi-map-marker" size="13" class="mr-1" />{{ c.address }}
                </span>
              </div>
            </div>
          </div>
          <EmptyState v-else icon="mdi-account-heart" title="No next of kin recorded" />
        </v-card>
      </v-col>

      <v-col cols="12">
        <!-- Allergies & history -->
        <v-card rounded="xl" class="pa-4">
          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-alert-octagon" color="error" class="mr-1" />
            Allergies
          </h3>
          <div v-if="allergyList.length" class="mb-2">
            <v-chip v-for="a in allergyList" :key="a"
                    size="small" color="error" variant="tonal" class="mr-1 mb-1">
              <v-icon icon="mdi-alert" size="14" class="mr-1" />{{ a }}
            </v-chip>
          </div>
          <div v-else class="text-caption text-medium-emphasis">None recorded.</div>

          <v-divider class="my-3" />

          <h3 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-history" class="mr-1" />
            Medical history
          </h3>
          <div class="text-body-2" style="white-space:pre-line;">
            {{ patient.medical_history || '—' }}
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Manage caregivers dialog -->
    <v-dialog v-model="cgDialog.show" max-width="640" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple" variant="tonal" size="36" class="mr-3">
            <v-icon icon="mdi-account-multiple-plus" />
          </v-avatar>
          <div class="flex-grow-1">
            <div class="text-subtitle-1 font-weight-bold">Manage caregivers</div>
            <div class="text-caption text-medium-emphasis">
              Assign one primary and any number of additional caregivers.
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" @click="cgDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-autocomplete
            v-model="cgDialog.primary"
            :items="caregiverOptions"
            item-title="label"
            item-value="id"
            label="Primary caregiver"
            prepend-inner-icon="mdi-account-star"
            variant="outlined"
            rounded="lg"
            density="comfortable"
            clearable
            hide-details
            class="mb-3"
          />
          <v-autocomplete
            v-model="cgDialog.additional"
            :items="additionalOptions"
            item-title="label"
            item-value="id"
            label="Additional caregivers"
            prepend-inner-icon="mdi-account-multiple"
            variant="outlined"
            rounded="lg"
            density="comfortable"
            multiple
            chips
            closable-chips
            hide-details
          />
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mt-3">
            Every selected caregiver will have access to this patient's records,
            schedules, doses and notes.
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="cgDialog.saving" @click="cgDialog.show = false">Cancel</v-btn>
          <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                 prepend-icon="mdi-content-save"
                 :loading="cgDialog.saving" @click="saveCaregivers">
            Save changes
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────────────────── Detail dialog (View) ───────────────────────── -->
    <v-dialog v-model="detail.show" max-width="640" scrollable>
      <v-card v-if="detail.item" rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="detailMeta.color" variant="tonal" size="40" class="mr-3">
            <v-icon :icon="detailMeta.icon" />
          </v-avatar>
          <div class="flex-grow-1">
            <div class="text-subtitle-1 font-weight-bold">{{ detailMeta.title }}</div>
            <div class="text-caption text-medium-emphasis">{{ detailMeta.subtitle }}</div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" @click="detail.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-0">
          <v-list density="comfortable" class="pa-0">
            <template v-for="(row, idx) in detailRows" :key="idx">
              <v-list-item v-if="row.value !== null && row.value !== '' && row.value !== undefined">
                <template #prepend>
                  <v-icon :icon="row.icon" :color="row.color || detailMeta.color" size="20" class="mr-3" />
                </template>
                <v-list-item-title class="text-caption text-medium-emphasis">
                  {{ row.label }}
                </v-list-item-title>
                <v-list-item-subtitle class="text-body-2 text-high-emphasis"
                                      style="white-space:pre-line; opacity:1;">
                  <template v-if="row.kind === 'chips' && Array.isArray(row.value)">
                    <v-chip v-for="v in row.value" :key="v" size="x-small"
                            variant="tonal" :color="detailMeta.color" class="mr-1 mt-1">
                      {{ v }}
                    </v-chip>
                  </template>
                  <template v-else-if="row.kind === 'status'">
                    <StatusChip :status="row.value" />
                  </template>
                  <template v-else-if="row.kind === 'link'">
                    <a :href="row.href" :target="row.external ? '_blank' : undefined" class="hc-link">
                      {{ row.value }}
                    </a>
                  </template>
                  <template v-else>{{ row.value }}</template>
                </v-list-item-subtitle>
              </v-list-item>
            </template>
          </v-list>
        </v-card-text>
        <v-divider v-if="detailMeta.editRoute || detailMeta.openRoute" />
        <v-card-actions v-if="detailMeta.editRoute || detailMeta.openRoute" class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="detail.show = false">
            Close
          </v-btn>
          <v-btn v-if="detailMeta.openRoute" color="indigo" variant="tonal" rounded="lg"
                 class="text-none" prepend-icon="mdi-open-in-new" :to="detailMeta.openRoute">
            Open page
          </v-btn>
          <v-btn v-if="detailMeta.editRoute" :color="detailMeta.color" rounded="lg"
                 class="text-none" prepend-icon="mdi-pencil" :to="detailMeta.editRoute">
            Edit
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)

const tab = ref('overview')
const patient = ref(null)
const overview = ref(null)
const plans = ref([])
const meds = ref([])
const doses = ref([])
const notes = ref([])
const consents = ref([])
const policies = ref([])
const trend = ref({ metrics: {}, series: {} })
const trendDays = ref(14)
const fhirBusy = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

// ─── Detail (View) dialog ───
const detail = reactive({ show: false, kind: '', item: null })
function viewItem(kind, item) {
  detail.kind = kind
  detail.item = item || null
  detail.show = !!item
}

const caregivers = ref([])
const cgDialog = reactive({
  show: false,
  saving: false,
  primary: null,
  additional: [],
})

const caregiverOptions = computed(() =>
  (caregivers.value || []).map(c => ({
    id: c.id,
    label: `${c.user?.full_name || c.user?.email || 'Caregiver'}`
      + (c.category ? ` (${c.category.toUpperCase()})` : ''),
  }))
)
const additionalOptions = computed(() =>
  caregiverOptions.value.filter(o => o.id !== cgDialog.primary)
)

const primaryCaregiverDetail = computed(() =>
  (caregivers.value || []).find(c => c.id === patient.value?.assigned_caregiver) || null
)

async function ensureCaregivers() {
  if (caregivers.value.length) return
  try {
    const { data } = await $api.get('/homecare/caregivers/', { params: { page_size: 500 } })
    caregivers.value = data?.results || data || []
  } catch {
    Object.assign(snack, { show: true, color: 'error', text: 'Failed to load caregivers' })
  }
}

async function openCaregiverDialog() {
  await ensureCaregivers()
  cgDialog.primary = patient.value?.assigned_caregiver || null
  cgDialog.additional = (patient.value?.additional_caregivers_detail || [])
    .map(c => c.id)
    .filter(cid => cid !== cgDialog.primary)
  cgDialog.show = true
}

async function saveCaregivers() {
  cgDialog.saving = true
  try {
    const payload = {
      assigned_caregiver: cgDialog.primary || null,
      additional_caregivers: cgDialog.additional.filter(cid => cid !== cgDialog.primary),
    }
    const { data } = await $api.patch(`/homecare/patients/${id.value}/`, payload)
    patient.value = { ...(patient.value || {}), ...data }
    Object.assign(snack, { show: true, color: 'success', text: 'Care team updated' })
    cgDialog.show = false
  } catch (e) {
    Object.assign(snack, {
      show: true, color: 'error',
      text: e?.response?.data?.detail || 'Failed to update care team',
    })
  } finally {
    cgDialog.saving = false
  }
}

const VITAL_META = {
  systolic: { icon: 'mdi-arrow-up-bold', color: 'red',     gradient: ['#ef4444', '#fca5a5'] },
  diastolic:{ icon: 'mdi-arrow-down-bold', color: 'orange',gradient: ['#f97316', '#fdba74'] },
  hr:       { icon: 'mdi-heart-pulse',   color: 'pink',    gradient: ['#ec4899', '#f9a8d4'] },
  pulse:    { icon: 'mdi-heart-pulse',   color: 'pink',    gradient: ['#ec4899', '#f9a8d4'] },
  rr:       { icon: 'mdi-lungs',         color: 'cyan',    gradient: ['#06b6d4', '#67e8f9'] },
  temp:     { icon: 'mdi-thermometer',   color: 'deep-orange', gradient: ['#ea580c', '#fdba74'] },
  spo2:     { icon: 'mdi-water-percent', color: 'indigo',  gradient: ['#6366f1', '#a5b4fc'] },
  glucose:  { icon: 'mdi-water',         color: 'purple',  gradient: ['#8b5cf6', '#c4b5fd'] },
  weight:   { icon: 'mdi-scale-bathroom',color: 'teal',    gradient: ['#0d9488', '#5eead4'] },
  height:   { icon: 'mdi-human-male-height', color: 'blue',gradient: ['#2563eb', '#93c5fd'] },
  bmi:      { icon: 'mdi-human',         color: 'green',   gradient: ['#16a34a', '#86efac'] },
  pain:     { icon: 'mdi-emoticon-sad',  color: 'amber',   gradient: ['#f59e0b', '#fcd34d'] },
}

const vitalCards = computed(() => {
  const out = []
  const series = trend.value?.series || {}
  const metrics = trend.value?.metrics || {}
  for (const key of Object.keys(series)) {
    const points = series[key] || []
    if (!points.length) continue
    const values = points.map(p => Number(p.v)).filter(v => Number.isFinite(v))
    if (!values.length) continue
    const meta = VITAL_META[key] || { icon: 'mdi-chart-line', color: 'grey', gradient: ['#64748b', '#cbd5e1'] }
    const last = values[values.length - 1]
    const prev = values.length > 1 ? values[values.length - 2] : null
    const diff = prev != null ? (last - prev) : null
    out.push({
      key,
      display: metrics[key]?.display || key,
      unit: metrics[key]?.unit || '',
      loinc: metrics[key]?.loinc || '—',
      values,
      last: Number.isInteger(last) ? last : Number(last.toFixed(1)),
      lastAt: points[points.length - 1]?.t,
      delta: diff == null ? '' : (diff === 0 ? '· no change' : (diff > 0 ? `▲ ${diff.toFixed(1)}` : `▼ ${Math.abs(diff).toFixed(1)}`)),
      deltaClass: diff == null || diff === 0 ? 'text-medium-emphasis' : (diff > 0 ? 'text-error' : 'text-success'),
      ...meta,
    })
  }
  return out
})

// ─── Derived ───
const patientName = computed(() =>
  patient.value?.patient_name
  || patient.value?.user?.full_name
  || [patient.value?.user?.first_name, patient.value?.user?.last_name].filter(Boolean).join(' ')
  || 'Patient'
)

const initials = computed(() => {
  const n = (patientName.value || '').trim()
  if (!n) return '?'
  const parts = n.split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || n[0].toUpperCase()
})

const riskColor = computed(() => ({
  low: 'success', medium: 'warning', high: 'orange', critical: 'error'
}[patient.value?.risk_level] || 'teal'))

const careTeamCount = computed(() =>
  (patient.value?.additional_caregivers_detail?.length || 0)
  + (patient.value?.assigned_caregiver ? 1 : 0)
)

const primaryPhone = computed(() => {
  const ec = (patient.value?.emergency_contacts || []).find(c => c.is_primary)
            || (patient.value?.emergency_contacts || [])[0]
  return ec?.phone || patient.value?.user?.phone || ''
})

const hasCoords = computed(() =>
  patient.value?.address_lat != null && patient.value?.address_lng != null
)

const mapMarkers = computed(() => {
  const out = []
  if (hasCoords.value) {
    out.push({
      lat: +patient.value.address_lat,
      lng: +patient.value.address_lng,
      color: ({ low: '#16a34a', medium: '#f59e0b', high: '#f97316', critical: '#dc2626' })[patient.value.risk_level] || '#0d9488',
      title: patientName.value,
      popup: `<strong>${patientName.value}</strong><br>${patient.value.address || ''}`,
    })
  }
  for (const c of patient.value?.emergency_contacts || []) {
    if (c.address_lat != null && c.address_lng != null) {
      out.push({
        lat: +c.address_lat, lng: +c.address_lng,
        color: '#7c3aed',
        title: c.name,
        popup: `<strong>${c.name}</strong><br>${c.relationship || ''}<br>${c.address || ''}`,
      })
    }
  }
  return out
})

const directionsUrl = computed(() => {
  if (hasCoords.value) {
    return `https://www.google.com/maps/dir/?api=1&destination=${patient.value.address_lat},${patient.value.address_lng}`
  }
  if (patient.value?.address) {
    return `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(patient.value.address)}`
  }
  return '#'
})

const osmUrl = computed(() =>
  hasCoords.value
    ? `https://www.openstreetmap.org/?mlat=${patient.value.address_lat}&mlon=${patient.value.address_lng}#map=17/${patient.value.address_lat}/${patient.value.address_lng}`
    : '#'
)

const adherencePct = computed(() => {
  const a = overview.value?.adherence
  if (!a?.total) return patient.value?.adherence_rate != null ? patient.value.adherence_rate + '%' : '—'
  return Math.round((a.taken / a.total) * 100) + '%'
})
const adherenceColor = computed(() => {
  const r = parseInt(adherencePct.value, 10)
  if (Number.isNaN(r)) return 'grey'
  if (r >= 85) return 'success'
  if (r >= 60) return 'warning'
  return 'error'
})
const adherenceSegments = computed(() => {
  const a = overview.value?.adherence || {}
  return [
    { label: 'Taken',  value: a.taken || 0,  color: 'success' },
    { label: 'Missed', value: a.missed || 0, color: 'error' },
    { label: 'Other',  value: Math.max(0, (a.total || 0) - (a.taken || 0) - (a.missed || 0)), color: 'grey' }
  ]
})

const allergyList = computed(() =>
  (patient.value?.allergies || '').split(/[,;\n]/).map(s => s.trim()).filter(Boolean))

function formatDateTime(iso) {
  return iso ? new Date(iso).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : ''
}

async function copy(text) {
  try {
    await navigator.clipboard?.writeText(text)
    Object.assign(snack, { show: true, text: 'Copied to clipboard', color: 'success' })
  } catch {}
}

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  const ovw = await $api.get(`/homecare/patients/${id.value}/overview/`).catch(() => null)
  if (ovw) {
    overview.value = ovw.data
    patient.value = ovw.data.patient
    plans.value = ovw.data.active_plan ? [ovw.data.active_plan] : []
    meds.value = ovw.data.medication_schedules || []
    notes.value = ovw.data.recent_notes || []
  }
  try {
    const { data } = await $api.get(`/homecare/patients/${id.value}/`)
    patient.value = { ...(patient.value || {}), ...data }
  } catch { /* ignore */ }
  doses.value = await safe(`/homecare/doses/?schedule__patient=${id.value}`)
  consents.value = await safe(`/homecare/consents/?patient=${id.value}`)
  policies.value = await safe(`/homecare/insurance-policies/?patient=${id.value}`)
  loadVitals()
  ensureCaregivers()
}

async function loadVitals() {
  try {
    const { data } = await $api.get(`/homecare/patients/${id.value}/vital-trend/?days=${trendDays.value}`)
    trend.value = data || { metrics: {}, series: {} }
  } catch {
    trend.value = { metrics: {}, series: {} }
  }
}

async function exportFhir() {
  fhirBusy.value = true
  try {
    const { data } = await $api.get(`/homecare/patients/${id.value}/fhir/`)
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/fhir+json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `patient-${patient.value?.medical_record_number || id.value}-fhir.json`
    a.click()
    URL.revokeObjectURL(url)
    Object.assign(snack, { show: true, text: 'FHIR bundle downloaded', color: 'success' })
  } catch (e) {
    Object.assign(snack, { show: true, text: 'Failed to export FHIR bundle', color: 'error' })
  } finally {
    fhirBusy.value = false
  }
}

onMounted(load)

// ─── Quick-add routes (deep-linked to patient) ───
const newPlanRoute   = computed(() => `/homecare/treatment-plans?patient=${id.value}`)
const newMedRoute    = computed(() => `/homecare/medications/new?patient=${id.value}`)
const dosesRoute     = computed(() => `/homecare/doses?patient=${id.value}`)
const vitalsRoute    = computed(() => `/homecare/vitals?patient=${id.value}`)
const newNoteRoute   = computed(() => `/homecare/notes/new?patient=${id.value}`)
const consentsRoute  = computed(() => `/homecare/consents?patient=${id.value}`)
const insuranceRoute = computed(() => `/homecare/insurance?patient=${id.value}`)

// ─── Detail dialog meta + rows ───
const detailMeta = computed(() => {
  const it = detail.item || {}
  switch (detail.kind) {
    case 'plan': return {
      icon: 'mdi-clipboard-text', color: 'teal',
      title: it.title || 'Care plan',
      subtitle: it.diagnosis || 'Treatment plan',
      openRoute: '/homecare/treatment-plans',
    }
    case 'med': return {
      icon: 'mdi-pill', color: 'indigo',
      title: it.medication_name || 'Medication',
      subtitle: it.dose ? `Dose ${it.dose}` : 'Medication schedule',
      editRoute: it.id ? `/homecare/medications/new?id=${it.id}` : null,
      openRoute: it.id ? `/homecare/medications/${it.id}` : null,
    }
    case 'dose': return {
      icon: doseIcon(it.status), color: doseColor(it.status),
      title: `${it.medication_name || 'Dose'} · ${it.dose || ''}`.trim(),
      subtitle: `Scheduled ${formatDateTime(it.scheduled_at) || '—'}`,
      openRoute: `/homecare/doses?patient=${id.value}`,
    }
    case 'note': return {
      icon: noteIcon(it.category), color: 'amber-darken-2',
      title: it.category ? `${String(it.category).charAt(0).toUpperCase()}${String(it.category).slice(1)} note` : 'Care note',
      subtitle: `${it.caregiver_name || 'Caregiver'} · ${formatDateTime(it.recorded_at) || ''}`,
      editRoute: it.id ? `/homecare/notes/${it.id}/edit` : null,
      openRoute: it.id ? `/homecare/notes/${it.id}` : null,
    }
    case 'consent': return {
      icon: 'mdi-file-document-check', color: 'green',
      title: it.scope || 'Consent',
      subtitle: it.granted_to ? `Granted to ${it.granted_to}` : 'Consent record',
      openRoute: `/homecare/consents?patient=${id.value}`,
    }
    case 'policy': return {
      icon: 'mdi-shield-account', color: 'blue',
      title: it.provider_name || 'Insurance policy',
      subtitle: it.policy_number ? `Policy ${it.policy_number}` : 'Coverage',
      openRoute: `/homecare/insurance?patient=${id.value}`,
    }
    case 'caregiver': return {
      icon: it.role === 'primary' ? 'mdi-account-star' : 'mdi-account',
      color: it.role === 'primary' ? 'teal' : 'purple',
      title: it.full_name || it.user?.full_name || 'Caregiver',
      subtitle: it.role === 'primary' ? 'Primary caregiver' : 'Additional caregiver',
    }
    default: return { icon: 'mdi-information', color: 'grey', title: '', subtitle: '' }
  }
})

const detailRows = computed(() => {
  const it = detail.item || {}
  const fmtDate = v => v || ''
  switch (detail.kind) {
    case 'plan': return [
      { icon: 'mdi-tag', label: 'Status', value: it.status, kind: 'status' },
      { icon: 'mdi-stethoscope', label: 'Diagnosis', value: it.diagnosis },
      { icon: 'mdi-calendar-start', label: 'Start date', value: fmtDate(it.start_date) },
      { icon: 'mdi-calendar-end', label: 'End date', value: fmtDate(it.end_date) },
      { icon: 'mdi-bullseye-arrow', label: 'Goals', value: it.goals },
      { icon: 'mdi-clipboard-list', label: 'Interventions', value: it.interventions },
      { icon: 'mdi-note-text', label: 'Notes', value: it.notes },
    ]
    case 'med': return [
      { icon: 'mdi-tag', label: 'Status', value: it.is_active ? 'active' : 'closed', kind: 'status' },
      { icon: 'mdi-pill', label: 'Dose', value: it.dose },
      { icon: 'mdi-needle', label: 'Route', value: it.route },
      { icon: 'mdi-repeat', label: 'Frequency', value: it.frequency },
      { icon: 'mdi-clock-outline', label: 'Times of day', value: it.times_of_day, kind: 'chips' },
      { icon: 'mdi-calendar-start', label: 'Start date', value: fmtDate(it.start_date) },
      { icon: 'mdi-calendar-end', label: 'End date', value: fmtDate(it.end_date) },
      { icon: 'mdi-doctor', label: 'Prescriber', value: it.prescriber_name },
      { icon: 'mdi-text-box-outline', label: 'Instructions', value: it.instructions },
      { icon: 'mdi-alert-circle-outline', label: 'Notes', value: it.notes },
    ]
    case 'dose': return [
      { icon: 'mdi-tag', label: 'Status', value: it.status, kind: 'status' },
      { icon: 'mdi-pill', label: 'Medication', value: it.medication_name },
      { icon: 'mdi-beaker', label: 'Dose', value: it.dose },
      { icon: 'mdi-calendar-clock', label: 'Scheduled', value: formatDateTime(it.scheduled_at) },
      { icon: 'mdi-check-circle-outline', label: 'Administered', value: formatDateTime(it.administered_at) },
      { icon: 'mdi-account', label: 'Administered by', value: it.administered_by_name },
      { icon: 'mdi-text-box-outline', label: 'Notes', value: it.notes },
    ]
    case 'note': return [
      { icon: 'mdi-shape', label: 'Category', value: it.category },
      { icon: 'mdi-account', label: 'Caregiver', value: it.caregiver_name },
      { icon: 'mdi-calendar-clock', label: 'Recorded at', value: formatDateTime(it.recorded_at) },
      { icon: 'mdi-text', label: 'Content', value: it.content },
      { icon: 'mdi-paperclip', label: 'Attachments',
        value: Array.isArray(it.attachments) && it.attachments.length
          ? it.attachments.map(a => a.name || a).filter(Boolean) : null,
        kind: 'chips' },
    ]
    case 'consent': return [
      { icon: 'mdi-tag', label: 'Status', value: it.is_active ? 'active' : 'revoked', kind: 'status' },
      { icon: 'mdi-shape', label: 'Scope', value: it.scope },
      { icon: 'mdi-account-arrow-right', label: 'Granted to', value: it.granted_to },
      { icon: 'mdi-calendar-check', label: 'Granted at', value: fmtDate(it.granted_at) },
      { icon: 'mdi-calendar-remove', label: 'Revoked at', value: fmtDate(it.revoked_at) },
      { icon: 'mdi-pen', label: 'Signed by', value: it.signed_by_name || it.granted_by_name },
      { icon: 'mdi-text-box-outline', label: 'Notes', value: it.notes },
    ]
    case 'policy': return [
      { icon: 'mdi-tag', label: 'Status', value: it.is_active ? 'active' : 'expired', kind: 'status' },
      { icon: 'mdi-domain', label: 'Provider', value: it.provider_name },
      { icon: 'mdi-pound', label: 'Policy number', value: it.policy_number },
      { icon: 'mdi-card-account-details', label: 'Member ID', value: it.member_id },
      { icon: 'mdi-calendar-start', label: 'Valid from', value: fmtDate(it.valid_from) },
      { icon: 'mdi-calendar-end', label: 'Valid to', value: fmtDate(it.valid_to) },
      { icon: 'mdi-cash', label: 'Coverage limit', value: it.coverage_limit },
      { icon: 'mdi-text-box-outline', label: 'Coverage notes', value: it.coverage_notes },
    ]
    case 'caregiver': {
      const email = it.email || it.user?.email
      const phone = it.phone || it.user?.phone
      return [
        { icon: 'mdi-stethoscope', label: 'Role', value: it.category ? String(it.category).toUpperCase() : (it.role === 'primary' ? 'PRIMARY' : 'ADDITIONAL') },
        { icon: 'mdi-email', label: 'Email', value: email,
          kind: email ? 'link' : 'text', href: email ? `mailto:${email}` : '' },
        { icon: 'mdi-phone', label: 'Phone', value: phone,
          kind: phone ? 'link' : 'text', href: phone ? `tel:${phone}` : '' },
        { icon: 'mdi-account-card', label: 'Employee ID', value: it.employee_id },
        { icon: 'mdi-text-box-outline', label: 'Notes', value: it.notes },
      ]
    }
    default: return []
  }
})

// ─── Dose helpers ───
function doseColor(status) {
  return ({
    taken: 'success', given: 'success', administered: 'success',
    missed: 'error', refused: 'error',
    pending: 'warning', scheduled: 'warning', upcoming: 'warning',
    skipped: 'grey',
  })[String(status || '').toLowerCase()] || 'teal'
}
function doseIcon(status) {
  return ({
    taken: 'mdi-check-circle', given: 'mdi-check-circle', administered: 'mdi-check-circle',
    missed: 'mdi-close-circle', refused: 'mdi-cancel',
    pending: 'mdi-clock-outline', scheduled: 'mdi-clock-outline', upcoming: 'mdi-clock-outline',
    skipped: 'mdi-debug-step-over',
  })[String(status || '').toLowerCase()] || 'mdi-pill'
}

// ─── Note category icon ───
function noteIcon(category) {
  return ({
    diet: 'mdi-food-apple',
    activity: 'mdi-run',
    observation: 'mdi-eye',
    vitals: 'mdi-heart-pulse',
    incident: 'mdi-alert-octagon',
    medication: 'mdi-pill',
  })[String(category || '').toLowerCase()] || 'mdi-note-edit'
}
</script>

<style scoped>
.hc-hero {
  background: linear-gradient(135deg, rgba(13,148,136,0.10) 0%, rgba(99,102,241,0.10) 100%);
  border: 1px solid rgba(13,148,136,0.18);
}
:global(.v-theme--dark) .hc-hero {
  background: linear-gradient(135deg, rgba(13,148,136,0.18) 0%, rgba(99,102,241,0.18) 100%);
  border-color: rgba(13,148,136,0.3);
}
.hc-avatar { box-shadow: 0 6px 20px rgba(0,0,0,0.18); }
.hc-kin {
  background: rgba(239,68,68,0.06);
  border: 1px solid rgba(239,68,68,0.18);
}
:global(.v-theme--dark) .hc-kin {
  background: rgba(239,68,68,0.12);
  border-color: rgba(239,68,68,0.3);
}
.hc-link { color: rgb(var(--v-theme-primary)); text-decoration: none; }
.hc-link:hover { text-decoration: underline; }
.hc-map-empty {
  height: 180px;
  background: rgba(0,0,0,0.03);
  border: 1px dashed rgba(0,0,0,0.12);
}
:global(.v-theme--dark) .hc-map-empty {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.12);
}
.hc-metric {
  background: rgba(255,255,255,0.6);
  border: 1px solid rgba(0,0,0,0.05);
}
:global(.v-theme--dark) .hc-metric {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.08);
}
.hc-spark {
  background: rgba(255,255,255,0.7);
  border: 1px solid rgba(0,0,0,0.06);
}
:global(.v-theme--dark) .hc-spark {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.08);
}
.hc-tab-card {
  background: rgba(255,255,255,0.7);
  border: 1px solid rgba(0,0,0,0.06);
  transition: box-shadow .15s ease, transform .15s ease;
}
.hc-tab-card:hover {
  box-shadow: 0 6px 18px rgba(15,23,42,0.08);
  transform: translateY(-1px);
}
:global(.v-theme--dark) .hc-tab-card {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.08);
}
</style>
