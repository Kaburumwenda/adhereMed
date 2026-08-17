<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Patient Care" subtitle="Comprehensive patient care & monitoring"
      icon="mdi-hand-heart" color="teal">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="loadingAny" @click="reload">Refresh</v-btn>
        <v-btn v-if="tab === 'notes'" color="purple" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNoteDialog()">New Note</v-btn>
        <v-btn v-if="tab === 'vitals'" color="red" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openVitalsDialog()">Record Vitals</v-btn>
        <v-btn v-if="tab === 'escalations'" color="error" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openEscalationDialog()">New Escalation</v-btn>
      </template>
    </PageHeader>

    <!-- ── KPI Cards ─────────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold" :class="`text-${k.color}`">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color + '-lighten-5'" variant="tonal" size="48">
              <v-icon :color="k.color" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Stat Cards ────────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <!-- Escalation Severity -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">ESCALATION SEVERITY</span>
            <v-icon size="16" color="medium-emphasis">mdi-alert-circle</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="s in severityDist" :key="s.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="s.color">{{ s.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0" style="width: 90px">{{ s.label }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`severity-bar-${s.key}`" :style="{ width: `${s.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="width: 28px; text-align: right">{{ s.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ openEscalations }} open escalations</div>
        </v-card>
      </v-col>

      <!-- Escalation Status -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">ESCALATION STATUS</span>
            <v-icon size="16" color="medium-emphasis">mdi-clipboard-list</v-icon>
          </div>
          <div class="d-flex flex-column ga-2 mb-2">
            <div v-for="s in escStatusDist" :key="s.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="s.color">{{ s.icon }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0 text-capitalize" style="width: 110px">{{ s.key.replace(/_/g, ' ') }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :class="`esc-status-bar-${s.key}`" :style="{ width: `${s.pct}%` }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${s.color}`" style="width: 28px; text-align: right">{{ s.count }}</span>
            </div>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ escR.items.value.length }} total escalations</div>
        </v-card>
      </v-col>

      <!-- Care Notes by Category -->
      <v-col cols="12" md="4">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">NOTES BY CATEGORY</span>
            <v-icon size="16" color="medium-emphasis">mdi-notebook-edit</v-icon>
          </div>
          <div class="d-flex flex-wrap ga-2">
            <v-chip v-for="c in noteCategoryDist" :key="c.key" size="small" variant="tonal"
              color="purple" class="text-capitalize">
              <v-icon start size="14">{{ noteCategoryIcon(c.key) }}</v-icon>
              {{ c.key.replace(/_/g, ' ') }} <span class="font-weight-bold ml-1">{{ c.count }}</span>
            </v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ noteR.items.value.length }} total notes</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Tabs ──────────────────────────────────────────────────── -->
    <v-tabs v-model="tab" color="teal" density="compact" class="mb-3">
      <v-tab value="overview" class="text-none">
        <v-icon start size="18">mdi-view-dashboard</v-icon>Overview
      </v-tab>
      <v-tab value="notes" class="text-none">
        <v-icon start size="18">mdi-notebook-edit</v-icon>Care Notes
        <v-chip v-if="noteR.items.value.length" size="x-small" variant="flat" color="purple" class="ml-2">{{ noteR.items.value.length }}</v-chip>
      </v-tab>
      <v-tab value="vitals" class="text-none">
        <v-icon start size="18">mdi-heart-pulse</v-icon>Vitals
        <v-chip v-if="vitalR.items.value.length" size="x-small" variant="flat" color="red" class="ml-2">{{ vitalR.items.value.length }}</v-chip>
      </v-tab>
      <v-tab value="escalations" class="text-none">
        <v-icon start size="18">mdi-bell-alert</v-icon>Escalations
        <v-chip v-if="openEscalations" size="x-small" variant="flat" color="error" class="ml-2">{{ openEscalations }}</v-chip>
      </v-tab>
    </v-tabs>

    <!-- ═══ OVERVIEW TAB ════════════════════════════════════════════ -->
    <v-window v-model="tab">
      <v-window-item value="overview">
        <!-- Filter bar -->
        <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
          <v-text-field v-model="patientSearch" prepend-inner-icon="mdi-magnify"
            placeholder="Search patients by name, ID, phone…"
            variant="outlined" density="compact" hide-details clearable />
        </v-card>

        <div v-if="loadingAny" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="teal" size="48" />
        </div>

        <div v-else-if="!filteredPatients.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-hand-heart</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No patients found</div>
          <div class="text-body-2 text-medium-emphasis mb-4">
            {{ patientSearch ? 'Try adjusting your search.' : 'There are no registered patients yet.' }}
          </div>
        </div>

        <v-card v-else flat rounded="lg" class="results-card">
          <v-data-table :headers="patientHeaders" :items="enhancedPatients"
            :items-per-page="15" item-value="id" hover
            @click:row="(_, { item }) => goToPatient(item.id)"
            class="patient-care-table">
            <template #item.patient="{ item }">
              <div class="d-flex align-center">
                <v-avatar color="teal-lighten-5" variant="tonal" size="36" class="mr-3">
                  <v-icon color="teal" size="20">mdi-account</v-icon>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.user_name || item.patient_number || '—' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.patient_number || '—' }}</div>
                </div>
              </div>
            </template>
            <template #item.vitals_summary="{ item }">
              <span v-if="item.vitalsSummary" class="text-caption">{{ item.vitalsSummary }}</span>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.notes_count="{ item }">
              <v-chip size="small" variant="tonal" :color="item.notesCount ? 'purple' : 'grey'">
                {{ item.notesCount || 0 }}
              </v-chip>
            </template>
            <template #item.alerts="{ item }">
              <v-chip v-if="item.openEscalations" size="small" variant="tonal" color="error">
                <v-icon start size="14">mdi-bell-alert</v-icon>{{ item.openEscalations }} open
              </v-chip>
              <v-chip v-else size="small" variant="tonal" color="success">
                <v-icon start size="14">mdi-check-circle</v-icon>No alerts
              </v-chip>
            </template>
            <template #item.last_visit="{ item }">
              <span v-if="item.lastVisit" class="text-caption">{{ formatDate(item.lastVisit) }}</span>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- ═══ CARE NOTES TAB ═════════════════════════════════════════ -->
      <v-window-item value="notes">
        <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
          <v-row dense align="center">
            <v-col cols="12" md="5">
              <v-text-field v-model="noteSearch" prepend-inner-icon="mdi-magnify"
                placeholder="Search notes by content, patient…"
                variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="noteCategoryFilter" :items="noteCategoryOptions"
                label="Category" variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="6" md="4">
              <v-select v-model="notePatientFilter" :items="patientSelectOptions"
                label="Patient" variant="outlined" density="compact" hide-details clearable />
            </v-col>
          </v-row>
        </v-card>

        <div v-if="noteR.loading.value" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="purple" size="48" />
        </div>

        <div v-else-if="!filteredNotes.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-notebook-edit</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No care notes found</div>
        </div>

        <v-card v-else flat rounded="lg" class="results-card">
          <v-data-table :headers="noteHeaders" :items="filteredNotes"
            :items-per-page="15" item-value="id" hover
            class="notes-table">
            <template #item.patient_name="{ value }">
              <span class="font-weight-medium">{{ value || '—' }}</span>
            </template>
            <template #item.category="{ value }">
              <v-chip size="small" variant="tonal" color="purple" class="text-capitalize">
                <v-icon start size="14">{{ noteCategoryIcon(value) }}</v-icon>
                {{ value ? value.replace(/_/g, ' ') : '—' }}
              </v-chip>
            </template>
            <template #item.caregiver_name="{ value }">
              <span>{{ value || '—' }}</span>
            </template>
            <template #item.content="{ value }">
              <span class="text-truncate d-inline-block" style="max-width: 280px">{{ value || '—' }}</span>
            </template>
            <template #item.recorded_at="{ value }">{{ formatDateTime(value) }}</template>
            <template #item.actions="{ item }">
              <div class="d-flex justify-end" @click.stop>
                <v-btn icon="mdi-eye" variant="text" size="small" color="purple" @click="viewNote(item)" />
                <v-btn icon="mdi-pencil" variant="text" size="small" color="purple" @click="openNoteDialog(item)" />
                <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDeleteNote(item)" />
              </div>
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- ═══ VITALS TAB ═══════════════════════════════════════════ -->
      <v-window-item value="vitals">
        <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
          <v-row dense align="center">
            <v-col cols="12" md="6">
              <v-text-field v-model="vitalSearch" prepend-inner-icon="mdi-magnify"
                placeholder="Search vitals by patient name…"
                variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="vitalPatientFilter" :items="patientSelectOptions"
                label="Patient" variant="outlined" density="compact" hide-details clearable />
            </v-col>
          </v-row>
        </v-card>

        <div v-if="vitalR.loading.value" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="red" size="48" />
        </div>

        <div v-else-if="!filteredVitals.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-heart-pulse</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No vitals recorded</div>
        </div>

        <v-card v-else flat rounded="lg" class="results-card">
          <v-data-table :headers="vitalHeaders" :items="filteredVitals"
            :items-per-page="15" item-value="id" hover
            class="vitals-table">
            <template #item.patient_name="{ value }">
              <span class="font-weight-medium">{{ value || '—' }}</span>
            </template>
            <template #item.temperature="{ item }">
              <v-chip v-if="tempValue(item)" size="small" variant="tonal" :color="tempColor(tempValue(item))">
                {{ tempValue(item) }}°C
              </v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.bp="{ item }">
              <span v-if="bpLabel(item)">{{ bpLabel(item) }}</span>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.heart_rate="{ item }">
              <v-chip v-if="hrValue(item)" size="small" variant="tonal"
                :color="hrAbnormal(hrValue(item)) ? 'warning' : 'success'">
                {{ hrValue(item) }}
              </v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.oxygen_saturation="{ item }">
              <v-chip v-if="spo2Value(item)" size="small" variant="tonal"
                :color="spo2Value(item) < 92 ? 'error' : 'success'">
                {{ spo2Value(item) }}%
              </v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.created_at="{ value }">{{ formatDateTime(value) }}</template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-pencil" variant="text" size="small" color="red" @click="openVitalsDialog(item)" />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- ═══ ESCALATIONS TAB ═══════════════════════════════════════ -->
      <v-window-item value="escalations">
        <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
          <v-row dense align="center">
            <v-col cols="12" md="4">
              <v-text-field v-model="escSearch" prepend-inner-icon="mdi-magnify"
                placeholder="Search by patient, reason…"
                variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="escSeverityFilter" :items="severityOptions"
                label="Severity" variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="escStatusFilter" :items="escStatusOptions"
                label="Status" variant="outlined" density="compact" hide-details clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="escPatientFilter" :items="patientSelectOptions"
                label="Patient" variant="outlined" density="compact" hide-details clearable />
            </v-col>
          </v-row>
        </v-card>

        <div v-if="escR.loading.value" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="error" size="48" />
        </div>

        <div v-else-if="!filteredEscalations.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-bell-alert</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No escalations found</div>
        </div>

        <v-row v-else dense>
          <v-col v-for="esc in filteredEscalations" :key="esc.id" cols="12" md="6" lg="4">
            <v-card rounded="lg" variant="outlined" class="esc-card h-100" :class="`esc-card-${esc.severity}`">
              <div class="d-flex align-center justify-space-between pa-3 esc-card-header" :class="`esc-header-${esc.severity}`">
                <div class="d-flex align-center ga-2">
                  <v-avatar :color="severityColor(esc.severity)" variant="tonal" size="32">
                    <v-icon :color="severityColor(esc.severity)" size="16">{{ severityIcon(esc.severity) }}</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium text-body-2">{{ esc.patient_name || 'Unknown' }}</div>
                    <div class="text-caption text-medium-emphasis">{{ formatDateTime(esc.triggered_at) }}</div>
                  </div>
                </div>
                <v-chip size="small" variant="flat" :color="severityColor(esc.severity)" class="text-capitalize">
                  {{ esc.severity }}
                </v-chip>
              </div>
              <v-card-text class="pa-3 pt-2">
                <div class="text-body-2 font-weight-medium mb-1">{{ esc.reason }}</div>
                <div v-if="esc.detail" class="text-caption text-medium-emphasis mb-2">{{ esc.detail }}</div>
                <div class="d-flex align-center ga-2">
                  <v-chip size="x-small" variant="tonal" :color="escStatusColor(esc.status)" class="text-capitalize">
                    <v-icon start size="12">{{ escStatusIcon(esc.status) }}</v-icon>{{ esc.status }}
                  </v-chip>
                  <span v-if="esc.acknowledged_by_name" class="text-caption text-medium-emphasis">
                    by {{ esc.acknowledged_by_name }}
                  </span>
                </div>
              </v-card-text>
              <v-card-actions class="px-3 pb-3 pt-0">
                <v-btn v-if="esc.status === 'open'" size="small" variant="outlined" color="warning"
                  prepend-icon="mdi-check" @click="acknowledge(esc)">Acknowledge</v-btn>
                <v-btn v-if="esc.status !== 'resolved'" size="small" variant="outlined" color="success"
                  prepend-icon="mdi-check-all" @click="resolveEsc(esc)">Resolve</v-btn>
                <v-spacer />
                <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDeleteEsc(esc)" />
              </v-card-actions>
            </v-card>
          </v-col>
        </v-row>
      </v-window-item>
    </v-window>

    <!-- ═══ Care Note Dialog ════════════════════════════════════════ -->
    <v-dialog v-model="noteDialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar :color="noteEditing ? 'purple-lighten-5' : 'purple'" variant="tonal" size="36" class="mr-3">
            <v-icon :color="noteEditing ? 'purple' : 'white'">{{ noteEditing ? 'mdi-note-edit' : 'mdi-note-plus' }}</v-icon>
          </v-avatar>
          {{ noteEditing ? 'Edit Care Note' : 'New Care Note' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-form ref="noteFormRef" @submit.prevent="saveNote">
            <v-select v-model="noteForm.patient" :items="patientSelectOptions"
              label="Patient" variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-account" :rules="req" />
            <v-select v-model="noteForm.category" :items="noteCategoryOptions"
              label="Category" variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-tag" />
            <v-textarea v-model="noteForm.content" label="Content" required
              variant="outlined" density="compact" rows="3" auto-grow
              prepend-inner-icon="mdi-text" :rules="req" />
            <v-alert v-if="noteR.error.value" type="error" variant="tonal" density="compact" class="mt-3">
              {{ noteR.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="noteDialog = false">Cancel</v-btn>
          <v-btn color="purple" rounded="lg" class="text-none" :loading="noteR.saving.value"
            prepend-icon="mdi-content-save" @click="saveNote">
            {{ noteEditing ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Note View Dialog ════════════════════════════════════════ -->
    <v-dialog v-model="noteViewDialog" max-width="600" scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar color="purple-lighten-5" variant="tonal" size="36" class="mr-3">
            <v-icon color="purple">mdi-notebook-edit</v-icon>
          </v-avatar>
          {{ viewNoteItem?.patient_name || 'Care Note' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4" v-if="viewNoteItem">
          <v-chip size="small" variant="tonal" color="purple" class="text-capitalize mb-2">
            <v-icon start size="14">{{ noteCategoryIcon(viewNoteItem.category) }}</v-icon>
            {{ viewNoteItem.category?.replace(/_/g, ' ') }}
          </v-chip>
          <div class="text-body-1 mt-2">{{ viewNoteItem.content }}</div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            <v-icon size="14" class="mr-1">mdi-account-tie</v-icon>
            Caregiver: {{ viewNoteItem.caregiver_name || '—' }}
          </div>
          <div class="text-caption text-medium-emphasis">
            <v-icon size="14" class="mr-1">mdi-clock</v-icon>
            Recorded: {{ formatDateTime(viewNoteItem.recorded_at) }}
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="noteViewDialog = false">Close</v-btn>
          <v-btn color="purple" rounded="lg" prepend-icon="mdi-pencil" @click="noteViewDialog = false; openNoteDialog(viewNoteItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Vitals Dialog ══════════════════════════════════════════ -->
    <v-dialog v-model="vitalsDialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar color="red-lighten-5" variant="tonal" size="36" class="mr-3">
            <v-icon color="red">mdi-heart-pulse</v-icon>
          </v-avatar>
          {{ vitalsEditing ? 'Edit Vitals' : 'Record Vitals' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-form ref="vitalsFormRef" @submit.prevent="saveVitals">
            <v-select v-model="vitalsForm.patient" :items="patientSelectOptions"
              label="Patient" variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-account" :rules="req" />
            <v-row dense>
              <v-col cols="6"><v-text-field v-model="vitalsForm.temperature" label="Temperature (°C)" type="number" step="0.1" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.weight" label="Weight (kg)" type="number" step="0.1" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.bp_systolic" label="BP Systolic" type="number" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.bp_diastolic" label="BP Diastolic" type="number" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.heart_rate" label="Heart Rate (bpm)" type="number" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.respiratory_rate" label="Resp Rate (/min)" type="number" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.oxygen_saturation" label="SpO₂ (%)" type="number" variant="outlined" density="compact" /></v-col>
              <v-col cols="6"><v-text-field v-model="vitalsForm.height" label="Height (cm)" type="number" variant="outlined" density="compact" /></v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="vitalsDialog = false">Cancel</v-btn>
          <v-btn color="red" rounded="lg" class="text-none" :loading="vitalR.saving.value"
            prepend-icon="mdi-content-save" @click="saveVitals">
            {{ vitalsEditing ? 'Update' : 'Record' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Escalation Dialog ══════════════════════════════════════ -->
    <v-dialog v-model="escDialog" max-width="600" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar color="error-lighten-5" variant="tonal" size="36" class="mr-3">
            <v-icon color="error">mdi-bell-alert</v-icon>
          </v-avatar>
          New Escalation
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-form ref="escFormRef" @submit.prevent="saveEscalation">
            <v-select v-model="escForm.patient" :items="patientSelectOptions"
              label="Patient" variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-account" :rules="req" />
            <v-text-field v-model="escForm.reason" label="Reason" required
              variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-alert" :rules="req" />
            <v-select v-model="escForm.severity" :items="severityOptions"
              label="Severity" variant="outlined" density="compact" class="mb-3"
              prepend-inner-icon="mdi-chart-bell-curve" />
            <v-textarea v-model="escForm.detail" label="Detail"
              variant="outlined" density="compact" rows="2" auto-grow
              prepend-inner-icon="mdi-text" />
            <v-alert v-if="escR.error.value" type="error" variant="tonal" density="compact" class="mt-3">
              {{ escR.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="escDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="escR.saving.value"
            prepend-icon="mdi-content-save" @click="saveEscalation">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete Confirmations ════════════════════════════════════ -->
    <v-dialog v-model="deleteNoteDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Note?</v-card-title>
        <v-card-text>Are you sure you want to delete this care note?</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteNoteDialog = false">Cancel</v-btn>
          <v-btn color="error" @click="performDeleteNote">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="deleteEscDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Escalation?</v-card-title>
        <v-card-text>Are you sure you want to delete this escalation?</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteEscDialog = false">Cancel</v-btn>
          <v-btn color="error" :loading="escR.saving.value" @click="performDeleteEsc">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime } from '~/utils/format'

const ns = '/clinics'
const req = [v => !!v || 'Required']

const r = useResource('/patients/')
const noteR = useResource('/homecare/notes/')
const vitalR = useResource('/triage/')
const escR = useResource('/homecare/escalations/')

const tab = ref('overview')
const patientSearch = ref('')
const loadingAny = computed(() =>
  r.loading.value || noteR.loading.value || vitalR.loading.value || escR.loading.value,
)

// ── Patient select options ──────────────────────────────────────
const patientSelectOptions = computed(() =>
  r.items.value.map(p => ({
    title: p.user_name || p.patient_number || '—',
    value: p.id,
  })),
)

// ── KPIs ────────────────────────────────────────────────────────
const openEscalations = computed(() =>
  escR.items.value.filter(e => e.status === 'open').length,
)

const kpis = computed(() => {
  const notes = noteR.items.value
  const vitals = vitalR.items.value
  const escalations = escR.items.value
  return [
    { label: 'Care Notes', value: notes.length, icon: 'mdi-notebook-edit', color: 'purple' },
    { label: 'Vitals Records', value: vitals.length, icon: 'mdi-heart-pulse', color: 'red' },
    { label: 'Open Escalations', value: escalations.filter(e => e.status === 'open').length, icon: 'mdi-bell-alert', color: 'error' },
    { label: 'Critical Alerts', value: escalations.filter(e => e.severity === 'critical' && e.status !== 'resolved').length, icon: 'mdi-alert-octagon', color: 'deep-orange' },
  ]
})

// ── Severity distribution ──────────────────────────────────────
const severityOptions = [
  { title: 'Low', value: 'low' },
  { title: 'Medium', value: 'medium' },
  { title: 'High', value: 'high' },
  { title: 'Critical', value: 'critical' },
]
const escStatusOptions = [
  { title: 'Open', value: 'open' },
  { title: 'Acknowledged', value: 'acknowledged' },
  { title: 'Resolved', value: 'resolved' },
]

const severityDist = computed(() => {
  const list = escR.items.value
  const total = list.length || 1
  const counts = {
    low: list.filter(e => e.severity === 'low').length,
    medium: list.filter(e => e.severity === 'medium').length,
    high: list.filter(e => e.severity === 'high').length,
    critical: list.filter(e => e.severity === 'critical').length,
  }
  const icons = { low: 'mdi-information', medium: 'mdi-alert', high: 'mdi-alert-circle', critical: 'mdi-alert-octagon' }
  const colors = { low: 'info', medium: 'warning', high: 'error', critical: 'deep-orange' }
  return Object.entries(counts).map(([key, count]) => ({
    key, count, pct: (count / total) * 100,
    icon: icons[key], color: colors[key],
  }))
})

const escStatusDist = computed(() => {
  const list = escR.items.value
  const total = list.length || 1
  const counts = {
    open: list.filter(e => e.status === 'open').length,
    acknowledged: list.filter(e => e.status === 'acknowledged').length,
    resolved: list.filter(e => e.status === 'resolved').length,
  }
  const icons = { open: 'mdi-bell-alert', acknowledged: 'mdi-check', resolved: 'mdi-check-all' }
  const colors = { open: 'error', acknowledged: 'warning', resolved: 'success' }
  return Object.entries(counts).map(([key, count]) => ({
    key, count, pct: (count / total) * 100,
    icon: icons[key], color: colors[key],
  }))
})

const noteCategoryDist = computed(() => {
  const list = noteR.items.value
  const map = new Map()
  list.forEach(n => {
    const cat = n.category || 'other'
    map.set(cat, (map.get(cat) || 0) + 1)
  })
  return [...map.entries()].map(([key, count]) => ({ key, count })).sort((a, b) => b.count - a.count)
})

// ── Overview tab: enhanced patients ─────────────────────────────
const patientHeaders = [
  { title: 'Patient', key: 'patient', sortable: false },
  { title: 'Vitals Summary', key: 'vitals_summary', sortable: false },
  { title: 'Notes', key: 'notes_count', width: 80, sortable: false },
  { title: 'Alerts', key: 'alerts', width: 130, sortable: false },
  { title: 'Last Visit', key: 'last_visit', width: 130, sortable: false },
]

const filteredPatients = computed(() => {
  const q = (patientSearch.value || '').toLowerCase()
  if (!q) return r.items.value
  return r.items.value.filter(p =>
    (p.user_name || '').toLowerCase().includes(q) ||
    (p.patient_number || '').toLowerCase().includes(q) ||
    (p.user_phone || '').toLowerCase().includes(q),
  )
})

const notesByPatient = computed(() => {
  const map = new Map()
  noteR.items.value.forEach(n => map.set(n.patient, (map.get(n.patient) || 0) + 1))
  return map
})

const vitalsByPatient = computed(() => {
  const map = new Map()
  vitalR.items.value.forEach(v => {
    const pid = v.patient
    if (!pid) return
    const ts = v.recorded_at || v.triage_time || v.created_at
    const existing = map.get(pid)
    if (!existing || (ts && new Date(ts) > new Date(existing._ts))) {
      const vs = v.vital_signs || {}
      const parts = []
      if (vs.temperature != null) parts.push(`T ${vs.temperature}°C`)
      else if (v.temperature != null) parts.push(`T ${v.temperature}°C`)
      const sys = vs.bp_systolic || vs.blood_pressure_systolic || v.bp_systolic
      const dia = vs.bp_diastolic || vs.blood_pressure_diastolic || v.bp_diastolic
      if (sys && dia) parts.push(`BP ${sys}/${dia}`)
      if (vs.heart_rate != null) parts.push(`HR ${vs.heart_rate}`)
      else if (v.heart_rate != null) parts.push(`HR ${v.heart_rate}`)
      if (vs.oxygen_saturation != null) parts.push(`SpO₂ ${vs.oxygen_saturation}%`)
      else if (v.oxygen_saturation != null) parts.push(`SpO₂ ${v.oxygen_saturation}%`)
      map.set(pid, { summary: parts.join(' · ') || 'Recorded', _ts: ts })
    }
  })
  return map
})

const escalationsByPatient = computed(() => {
  const map = new Map()
  escR.items.value.forEach(e => {
    if (e.status === 'open') {
      map.set(e.patient, (map.get(e.patient) || 0) + 1)
    }
  })
  return map
})

const enhancedPatients = computed(() => {
  return filteredPatients.value.map(p => ({
    ...p,
    vitalsSummary: vitalsByPatient.value.get(p.id)?.summary || '',
    notesCount: notesByPatient.value.get(p.id) || 0,
    openEscalations: escalationsByPatient.value.get(p.id) || 0,
    lastVisit: p.updated_at || p.created_at || '',
  }))
})

function goToPatient(id) { navigateTo(`${ns}/patients/${id}`) }

// ── Care Notes tab ──────────────────────────────────────────────
const noteCategoryOptions = [
  { title: 'Diet', value: 'diet' },
  { title: 'Activity', value: 'activity' },
  { title: 'Observation', value: 'observation' },
  { title: 'Vitals', value: 'vitals' },
  { title: 'Incident', value: 'incident' },
  { title: 'Medication', value: 'medication' },
  { title: 'Doctor Note', value: 'doctor' },
  { title: 'Nurse / HCA Note', value: 'nurse_hca' },
]

const noteHeaders = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Category', key: 'category', width: 140, sortable: false },
  { title: 'Caregiver', key: 'caregiver_name', width: 140, sortable: false },
  { title: 'Content', key: 'content', sortable: false },
  { title: 'Recorded At', key: 'recorded_at', width: 160 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const noteSearch = ref('')
const noteCategoryFilter = ref(null)
const notePatientFilter = ref(null)

const filteredNotes = computed(() => {
  let list = noteR.items.value
  const q = (noteSearch.value || '').toLowerCase()
  if (q) list = list.filter(n =>
    (n.content || '').toLowerCase().includes(q) ||
    (n.patient_name || '').toLowerCase().includes(q),
  )
  if (noteCategoryFilter.value) list = list.filter(n => n.category === noteCategoryFilter.value)
  if (notePatientFilter.value) list = list.filter(n => n.patient === notePatientFilter.value)
  return list
})

function noteCategoryIcon(cat) {
  const map = {
    diet: 'mdi-food-apple',
    activity: 'mdi-walk',
    observation: 'mdi-eye',
    vitals: 'mdi-heart-pulse',
    incident: 'mdi-alert',
    medication: 'mdi-pill',
    doctor: 'mdi-stethoscope',
    nurse_hca: 'mdi-account-nurse',
    other: 'mdi-note',
  }
  return map[cat] || 'mdi-note'
}

// ── Note dialog ──────────────────────────────────────────────
const noteDialog = ref(false)
const noteEditing = ref(null)
const noteFormRef = ref(null)
const blankNoteForm = () => ({ patient: null, category: 'observation', content: '' })
const noteForm = reactive(blankNoteForm())

function openNoteDialog(item) {
  if (item) {
    noteEditing.value = item.id
    Object.assign(noteForm, {
      patient: item.patient,
      category: item.category || 'observation',
      content: item.content || '',
    })
  } else {
    noteEditing.value = null
    Object.assign(noteForm, blankNoteForm())
  }
  noteDialog.value = true
}

async function saveNote() {
  const v = await noteFormRef.value?.validate()
  if (v?.valid === false) return
  try {
    if (noteEditing.value) {
      await noteR.update(noteEditing.value, { ...noteForm })
      snack.text = 'Care note updated'
    } else {
      await noteR.create({ ...noteForm })
      snack.text = 'Care note created'
    }
    snack.color = 'success'
    snack.show = true
    noteDialog.value = false
    await noteR.list({ page_size: 1000 })
  } catch {
    snack.text = noteR.error.value || 'Failed to save note'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Note view ───────────────────────────────────────────────
const noteViewDialog = ref(false)
const viewNoteItem = ref(null)
function viewNote(item) {
  viewNoteItem.value = item
  noteViewDialog.value = true
}

// ── Note delete ─────────────────────────────────────────────
const deleteNoteDialog = ref(false)
const deleteNoteTarget = ref(null)
function confirmDeleteNote(item) { deleteNoteTarget.value = item; deleteNoteDialog.value = true }
async function performDeleteNote() {
  try {
    await noteR.remove(deleteNoteTarget.value.id)
    snack.text = 'Care note deleted'
    snack.color = 'success'
    snack.show = true
    deleteNoteDialog.value = false
    await noteR.list({ page_size: 1000 })
  } catch {
    snack.text = 'Failed to delete note'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Vitals tab ──────────────────────────────────────────────
const vitalHeaders = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Temp', key: 'temperature', width: 100, sortable: false },
  { title: 'BP', key: 'bp', width: 110, sortable: false },
  { title: 'HR', key: 'heart_rate', width: 90, sortable: false },
  { title: 'SpO₂', key: 'oxygen_saturation', width: 90, sortable: false },
  { title: 'Recorded', key: 'created_at', width: 160, sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 70 },
]

const vitalSearch = ref('')
const vitalPatientFilter = ref(null)

const filteredVitals = computed(() => {
  let list = vitalR.items.value
  const q = (vitalSearch.value || '').toLowerCase()
  if (q) list = list.filter(v =>
    (v.patient_name || '').toLowerCase().includes(q) ||
    String(v.patient || '').includes(q),
  )
  if (vitalPatientFilter.value) list = list.filter(v => v.patient === vitalPatientFilter.value)
  return list
})

function tempValue(v) {
  return v.vital_signs?.temperature ?? v.temperature ?? null
}
function bpLabel(v) {
  const vs = v.vital_signs || {}
  const sys = vs.bp_systolic || vs.blood_pressure_systolic || v.bp_systolic
  const dia = vs.bp_diastolic || vs.blood_pressure_diastolic || v.bp_diastolic
  return sys && dia ? `${sys}/${dia}` : null
}
function hrValue(v) {
  return v.vital_signs?.heart_rate ?? v.heart_rate ?? null
}
function spo2Value(v) {
  return v.vital_signs?.oxygen_saturation ?? v.oxygen_saturation ?? null
}
function tempColor(t) {
  if (t >= 38 || t < 35) return 'error'
  if (t >= 37.5) return 'warning'
  return 'success'
}
function hrAbnormal(hr) {
  return hr < 60 || hr > 100
}

// ── Vitals dialog ──────────────────────────────────────────
const vitalsDialog = ref(false)
const vitalsEditing = ref(null)
const vitalsFormRef = ref(null)
const blankVitalsForm = () => ({
  patient: null, temperature: null, bp_systolic: null, bp_diastolic: null,
  heart_rate: null, respiratory_rate: null, oxygen_saturation: null, weight: null, height: null,
})
const vitalsForm = reactive(blankVitalsForm())

function openVitalsDialog(item) {
  if (item) {
    vitalsEditing.value = item.id
    const vs = item.vital_signs || {}
    Object.assign(vitalsForm, {
      patient: item.patient,
      temperature: vs.temperature ?? item.temperature ?? null,
      bp_systolic: vs.bp_systolic ?? vs.blood_pressure_systolic ?? item.bp_systolic ?? null,
      bp_diastolic: vs.bp_diastolic ?? vs.blood_pressure_diastolic ?? item.bp_diastolic ?? null,
      heart_rate: vs.heart_rate ?? item.heart_rate ?? null,
      respiratory_rate: vs.respiratory_rate ?? item.respiratory_rate ?? null,
      oxygen_saturation: vs.oxygen_saturation ?? item.oxygen_saturation ?? null,
      weight: vs.weight ?? item.weight ?? null,
      height: vs.height ?? item.height ?? null,
    })
  } else {
    vitalsEditing.value = null
    Object.assign(vitalsForm, blankVitalsForm())
  }
  vitalsDialog.value = true
}

async function saveVitals() {
  const v = await vitalsFormRef.value?.validate()
  if (v?.valid === false) return
  const payload = { patient: vitalsForm.patient, vital_signs: {} }
  if (vitalsForm.temperature != null) payload.vital_signs.temperature = vitalsForm.temperature
  if (vitalsForm.bp_systolic != null) payload.vital_signs.bp_systolic = vitalsForm.bp_systolic
  if (vitalsForm.bp_diastolic != null) payload.vital_signs.bp_diastolic = vitalsForm.bp_diastolic
  if (vitalsForm.heart_rate != null) payload.vital_signs.heart_rate = vitalsForm.heart_rate
  if (vitalsForm.respiratory_rate != null) payload.vital_signs.respiratory_rate = vitalsForm.respiratory_rate
  if (vitalsForm.oxygen_saturation != null) payload.vital_signs.oxygen_saturation = vitalsForm.oxygen_saturation
  if (vitalsForm.weight != null) payload.vital_signs.weight = vitalsForm.weight
  if (vitalsForm.height != null) payload.vital_signs.height = vitalsForm.height
  try {
    if (vitalsEditing.value) {
      await vitalR.update(vitalsEditing.value, payload)
      snack.text = 'Vitals updated'
    } else {
      await vitalR.create(payload)
      snack.text = 'Vitals recorded'
    }
    snack.color = 'success'
    snack.show = true
    vitalsDialog.value = false
    await vitalR.list({ page_size: 1000 })
  } catch {
    snack.text = vitalR.error.value || 'Failed to save vitals'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Escalations tab ──────────────────────────────────────────
const escSearch = ref('')
const escSeverityFilter = ref(null)
const escStatusFilter = ref(null)
const escPatientFilter = ref(null)

const filteredEscalations = computed(() => {
  let list = escR.items.value
  const q = (escSearch.value || '').toLowerCase()
  if (q) list = list.filter(e =>
    (e.patient_name || '').toLowerCase().includes(q) ||
    (e.reason || '').toLowerCase().includes(q),
  )
  if (escSeverityFilter.value) list = list.filter(e => e.severity === escSeverityFilter.value)
  if (escStatusFilter.value) list = list.filter(e => e.status === escStatusFilter.value)
  if (escPatientFilter.value) list = list.filter(e => e.patient === escPatientFilter.value)
  return list
})

function severityColor(s) {
  return { low: 'info', medium: 'warning', high: 'error', critical: 'deep-orange' }[s] || 'grey'
}
function severityIcon(s) {
  return { low: 'mdi-information', medium: 'mdi-alert', high: 'mdi-alert-circle', critical: 'mdi-alert-octagon' }[s] || 'mdi-bell-alert'
}
function escStatusColor(s) {
  return { open: 'error', acknowledged: 'warning', resolved: 'success' }[s] || 'grey'
}
function escStatusIcon(s) {
  return { open: 'mdi-bell-alert', acknowledged: 'mdi-check', resolved: 'mdi-check-all' }[s] || 'mdi-circle-medium'
}

// ── Escalation actions ─────────────────────────────────────
const { $api } = useNuxtApp()

async function acknowledge(esc) {
  try {
    await $api.post(`/homecare/escalations/${esc.id}/acknowledge/`)
    snack.text = 'Escalation acknowledged'
    snack.color = 'success'
    snack.show = true
    await escR.list({ page_size: 1000 })
  } catch {
    snack.text = 'Failed to acknowledge'
    snack.color = 'error'
    snack.show = true
  }
}

async function resolveEsc(esc) {
  try {
    await $api.post(`/homecare/escalations/${esc.id}/resolve/`, { notes: 'Resolved via Patient Care' })
    snack.text = 'Escalation resolved'
    snack.color = 'success'
    snack.show = true
    await escR.list({ page_size: 1000 })
  } catch {
    snack.text = 'Failed to resolve'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Escalation dialog ──────────────────────────────────────
const escDialog = ref(false)
const escFormRef = ref(null)
const blankEscForm = () => ({ patient: null, reason: '', severity: 'medium', detail: '' })
const escForm = reactive(blankEscForm())

function openEscalationDialog() {
  Object.assign(escForm, blankEscForm())
  escDialog.value = true
}

async function saveEscalation() {
  const v = await escFormRef.value?.validate()
  if (v?.valid === false) return
  try {
    await escR.create({ ...escForm })
    snack.text = 'Escalation created'
    snack.color = 'success'
    snack.show = true
    escDialog.value = false
    await escR.list({ page_size: 1000 })
  } catch {
    snack.text = escR.error.value || 'Failed to create escalation'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Escalation delete ──────────────────────────────────────
const deleteEscDialog = ref(false)
const deleteEscTarget = ref(null)
function confirmDeleteEsc(item) { deleteEscTarget.value = item; deleteEscDialog.value = true }
async function performDeleteEsc() {
  try {
    await escR.remove(deleteEscTarget.value.id)
    snack.text = 'Escalation deleted'
    snack.color = 'success'
    snack.show = true
    deleteEscDialog.value = false
    await escR.list({ page_size: 1000 })
  } catch {
    snack.text = 'Failed to delete escalation'
    snack.color = 'error'
    snack.show = true
  }
}

const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(reload)

async function reload() {
  await Promise.all([
    r.list({ page_size: 1000 }),
    noteR.list({ page_size: 1000 }),
    vitalR.list({ page_size: 1000 }),
    escR.list({ page_size: 1000 }),
  ])
}
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.patient-care-table :deep(tbody tr) { cursor: pointer; }
.notes-table :deep(tbody tr) { cursor: default; }
.vitals-table :deep(tbody tr) { cursor: default; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

/* Status bars */
.status-bar-track { height: 10px; background: rgba(var(--v-theme-on-surface), 0.06); }
.status-bar-fill { height: 100%; min-width: 4px; transition: width 0.3s ease; }

/* Severity bars */
.severity-bar-low { background: rgb(var(--v-theme-info)); }
.severity-bar-medium { background: rgb(var(--v-theme-warning)); }
.severity-bar-high { background: rgb(var(--v-theme-error)); }
.severity-bar-critical { background: rgb(var(--v-theme-deep-orange)); }

/* Escalation status bars */
.esc-status-bar-open { background: rgb(var(--v-theme-error)); }
.esc-status-bar-acknowledged { background: rgb(var(--v-theme-warning)); }
.esc-status-bar-resolved { background: rgb(var(--v-theme-success)); }

/* ── Escalation Cards ── */
.esc-card {
  transition: box-shadow 0.2s, transform 0.15s;
  overflow: hidden;
}
.esc-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}
.esc-card-header {
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.esc-header-low { background: rgba(3, 155, 229, 0.05); }
.esc-header-medium { background: rgba(255, 152, 0, 0.05); }
.esc-header-high { background: rgba(244, 67, 54, 0.05); }
.esc-header-critical { background: rgba(213, 0, 0, 0.08); }
.esc-card-low { border-left: 3px solid rgb(var(--v-theme-info)); }
.esc-card-medium { border-left: 3px solid rgb(var(--v-theme-warning)); }
.esc-card-high { border-left: 3px solid rgb(var(--v-theme-error)); }
.esc-card-critical { border-left: 3px solid rgb(var(--v-theme-deep-orange)); }
</style>
