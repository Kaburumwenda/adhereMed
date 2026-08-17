<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- ═══ Header ════════════════════════════════════════════════ -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="purple-lighten-5" size="48">
        <v-icon color="purple-darken-2" size="28">mdi-pill-multiple</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Prescriptions</div>
        <div class="text-body-2 text-medium-emphasis">Manage patient medication prescriptions, drug interactions and dispatch</div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openCreate">New Prescription</v-btn>
    </div>

    <!-- ═══ Tabs ══════════════════════════════════════════════════ -->
    <v-tabs v-model="mainTab" color="purple" density="compact" class="mb-4">
      <v-tab value="rx" prepend-icon="mdi-clipboard-text-clock">Prescriptions ({{ prescriptions.length }})</v-tab>
      <v-tab value="pharmacy" prepend-icon="mdi-store">Pharmacy Walk-in ({{ pharmacyRx.length }})</v-tab>
    </v-tabs>

    <!-- ═══════════════════════════════════════════════════════════════
         PRESCRIPTIONS TAB
         ═════════════════════════════════════════════════════════════ -->
    <template v-if="mainTab === 'rx'">
      <!-- ── KPI cards ── -->
      <v-row dense class="mb-4">
        <v-col v-for="k in kpis" :key="k.label" cols="6" sm="4" md="2">
          <v-card flat rounded="lg" class="kpi-card pa-4 text-center cursor-pointer"
            :class="{ 'kpi-card--active': statusFilter === k.filter }" @click="statusFilter = statusFilter === k.filter ? '' : k.filter">
            <v-avatar :color="k.color" size="40" class="mb-2" variant="tonal">
              <v-icon size="22">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="text-h5 font-weight-bold">{{ k.value }}</div>
            <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- ── Stats Analysis row ── -->
      <v-row dense class="mb-4">
        <v-col v-if="!prescriptions.length" cols="12">
          <v-card flat rounded="xl" class="stat-card pa-4 text-center">
            <v-icon color="purple" size="32" class="mb-2">mdi-chart-box</v-icon>
            <div class="text-subtitle-2 font-weight-bold mb-1">Prescription Analytics</div>
            <div class="text-caption text-medium-emphasis">
              Status, top medications, and daily distribution will appear here once prescriptions are created.
            </div>
          </v-card>
        </v-col>
        <template v-else>
          <v-col cols="12" md="3">
            <v-card flat rounded="lg" class="stat-card pa-3 h-100">
              <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="purple">mdi-chart-donut</v-icon>Status Distribution</div>
              <div v-for="s in statusStats" :key="s.label" class="d-flex align-center ga-2 mb-1">
                <v-chip :color="s.color" variant="tonal" size="x-small" class="font-weight-bold" style="min-width: 96px">{{ s.label }}</v-chip>
                <v-progress-linear :model-value="s.pct" height="8" rounded color="purple" class="flex-grow-1" />
                <span class="text-caption text-medium-emphasis" style="min-width: 24px; text-align: right">{{ s.count }}</span>
              </div>
            </v-card>
          </v-col>
          <v-col cols="12" md="3">
            <v-card flat rounded="lg" class="stat-card pa-3 h-100">
              <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="indigo">mdi-pill</v-icon>Top Medications ({{ topMeds.length }})</div>
              <div v-for="m in topMeds" :key="m.name" class="d-flex align-center ga-2 mb-1">
                <v-chip color="indigo" variant="tonal" size="x-small" class="font-weight-medium text-truncate" style="max-width: 110px">{{ m.name }}</v-chip>
                <v-progress-linear :model-value="m.pct" height="8" rounded color="indigo" class="flex-grow-1" />
                <span class="text-caption text-medium-emphasis" style="min-width: 24px; text-align: right">{{ m.count }}</span>
              </div>
              <div v-if="!topMeds.length" class="text-center text-caption text-medium-emphasis py-2">No medications yet</div>
            </v-card>
          </v-col>
          <v-col cols="12" md="3">
            <v-card flat rounded="lg" class="stat-card pa-3 h-100">
              <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="teal">mdi-calendar-month</v-icon>Daily Distribution</div>
              <div class="d-flex align-end ga-1" style="height: 80px">
                <div v-for="d in weekdayStats" :key="d.label" class="flex-grow-1 d-flex flex-column align-center">
                  <div class="weekday-bar" :style="{ height: (weekdayMax ? (d.count / weekdayMax * 64) : 0) + 'px' }" :title="`${d.label}: ${d.count}`" />
                  <span class="text-caption text-medium-emphasis mt-1" style="font-size: 9px">{{ d.short }}</span>
                </div>
              </div>
            </v-card>
          </v-col>
          <v-col cols="12" md="3">
            <v-card flat rounded="lg" class="stat-card pa-3 h-100">
              <div class="text-caption font-weight-bold mb-2 d-flex align-center"><v-icon size="14" class="mr-1" color="orange">mdi-account-multiple</v-icon>Top Prescribers ({{ topPrescribers.length }})</div>
              <div v-for="p in topPrescribers" :key="p.name" class="d-flex align-center ga-2 mb-1">
                <v-chip color="orange" variant="tonal" size="x-small" class="font-weight-medium text-truncate" style="max-width: 110px">{{ p.name }}</v-chip>
                <v-progress-linear :model-value="p.pct" height="8" rounded color="orange" class="flex-grow-1" />
                <span class="text-caption text-medium-emphasis" style="min-width: 24px; text-align: right">{{ p.count }}</span>
              </div>
              <div v-if="!topPrescribers.length" class="text-center text-caption text-medium-emphasis py-2">No prescribers yet</div>
            </v-card>
          </v-col>
        </template>
      </v-row>

      <!-- ── Filters ── -->
      <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="searchText" prepend-inner-icon="mdi-magnify" placeholder="Search patient, doctor, notes, medication…" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="statusFilter" :items="statusOptions" label="Status" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="6" md="2">
            <v-menu v-model="dateMenu" :close-on-content-click="false" location="bottom">
              <template #activator="{ props }">
                <v-text-field v-bind="props" :model-value="dateRangeLabel" prepend-inner-icon="mdi-calendar" placeholder="Date range" variant="outlined" density="compact" hide-details readonly />
              </template>
              <v-card min-width="280" rounded="lg">
                <div class="pa-3">
                  <v-text-field v-model="dateFrom" type="date" label="From" variant="outlined" density="compact" hide-details class="mb-2" />
                  <v-text-field v-model="dateTo" type="date" label="To" variant="outlined" density="compact" hide-details />
                </div>
                <v-divider />
                <v-card-actions>
                  <v-btn variant="text" size="small" @click="dateFrom = ''; dateTo = ''">Clear</v-btn>
                  <v-spacer />
                  <v-btn color="primary" size="small" @click="dateMenu = false">Done</v-btn>
                </v-card-actions>
              </v-card>
            </v-menu>
          </v-col>
          <v-col cols="12" md="2" class="d-flex align-center justify-end">
            <v-btn v-if="statusFilter || searchText || dateFrom || dateTo" size="small" variant="text" class="text-none" prepend-icon="mdi-filter-remove" @click="clearFilters">Clear</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <!-- ── Results ── -->
      <v-card flat rounded="lg" class="results-card">
        <div v-if="loading" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="purple" size="48" />
        </div>
        <div v-else-if="!filteredPrescriptions.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-pill</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No prescriptions found</div>
          <div class="text-body-2 text-medium-emphasis mb-4">
            {{ statusFilter || searchText || dateFrom || dateTo ? 'Try adjusting your filters.' : 'Create your first prescription to get started.' }}
          </div>
          <v-btn v-if="!statusFilter && !searchText && !dateFrom && !dateTo" color="purple" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openCreate">Create your first prescription</v-btn>
          <v-btn v-else variant="text" rounded="lg" class="text-none" prepend-icon="mdi-filter-remove" @click="clearFilters">Clear filters</v-btn>
        </div>
        <v-data-table v-else :headers="headers" :items="filteredPrescriptions" :items-per-page="20" item-value="id" hover @click:row="(_, { item }) => goTo(item.id)" class="prescriptions-table">
          <template #item.patient_name="{ item }">
            <div class="d-flex align-center ga-2">
              <v-avatar :color="avatarColor(item.patient_name)" size="32" variant="tonal">
                <span class="text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
              </v-avatar>
              <div>
                <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ item.patient_insurance_provider || 'No insurance' }}</div>
              </div>
            </div>
          </template>
          <template #item.meds="{ item }">
            <div class="d-flex ga-1 flex-wrap">
              <v-chip v-for="(m, idx) in (item.items || []).slice(0, 3)" :key="idx" size="x-small" variant="outlined" color="purple" class="font-weight-medium">
                {{ medShortName(m) }}
              </v-chip>
              <v-chip v-if="(item.items || []).length > 3" size="x-small" variant="tonal" color="purple">+{{ item.items.length - 3 }}</v-chip>
              <span v-if="!(item.items || []).length" class="text-caption text-medium-emphasis">—</span>
            </div>
          </template>
          <template #item.doctor_name="{ item }">
            <div class="d-flex align-center ga-1">
              <v-icon size="14" color="teal">mdi-doctor</v-icon>
              <span class="text-body-2">{{ item.doctor_name || '—' }}</span>
            </div>
          </template>
          <template #item.allergy_warn="{ item }">
            <v-chip v-if="(item.patient_allergies || []).length" size="x-small" color="error" variant="tonal" prepend-icon="mdi-alert">
              {{ item.patient_allergies.length }} allergy
            </v-chip>
            <span v-else class="text-caption text-medium-emphasis">NKA</span>
          </template>
          <template #item.created_at="{ value }">{{ formatDate(value) }}</template>
          <template #item.status="{ value }">
            <v-chip size="small" variant="tonal" :color="statusColor(value)" class="text-capitalize font-weight-medium">
              <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>{{ value || 'pending' }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <div class="d-flex justify-end" @click.stop>
              <v-btn icon="mdi-eye" variant="text" size="small" @click="goTo(item.id)" />
              <v-btn icon="mdi-pencil" variant="text" size="small" @click="navigateTo(`${ns}/prescriptions/${item.id}/edit`)" />
              <v-menu location="bottom left">
                <template #activator="{ props }">
                  <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
                </template>
                <v-list density="compact">
                  <v-list-item prepend-icon="mdi-printer" title="Print" @click="printRx(item.id)" />
                  <v-list-item v-if="(item.status || 'active') === 'active'" prepend-icon="mdi-send" title="Send to Exchange" @click="sendToExchange(item)" />
                  <v-list-item v-if="(item.status || 'active') === 'active'" prepend-icon="mdi-check-circle" title="Mark Dispensed" @click="markDispensed(item)" />
                  <v-list-item v-if="(item.status || 'active') !== 'cancelled'" prepend-icon="mdi-close-circle" title="Cancel" @click="cancelRx(item)" />
                  <v-divider />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error" @click="confirmDelete(item)" />
                </v-list>
              </v-menu>
            </div>
          </template>
          <template #expanded-row="{ item }">
            <td colspan="7" class="pa-4 bg-purple-lighten-5">
              <div class="d-flex ga-2 flex-wrap">
                <v-card v-for="(m, idx) in (item.items || [])" :key="idx" variant="outlined" class="pa-3 mr-2 mb-2" min-width="240" rounded="lg">
                  <div class="font-weight-medium text-body-2 mb-1">{{ medDisplayName(m) }}</div>
                  <div class="text-caption text-medium-emphasis">
                    {{ m.dosage }} · {{ m.frequency }} · {{ m.duration || '—' }} · Qty {{ m.quantity }}
                  </div>
                  <div v-if="m.instructions" class="text-caption mt-1"><v-icon size="10">mdi-information</v-icon> {{ m.instructions }}</div>
                  <v-chip v-if="m.refills" size="x-small" variant="tonal" color="info" class="mt-1">Refills: {{ m.refills }}</v-chip>
                </v-card>
              </div>
            </td>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ═══════════════════════════════════════════════════════════════
         PHARMACY WALK-IN TAB
         ═════════════════════════════════════════════════════════════ -->
    <template v-if="mainTab === 'pharmacy'">
      <v-card flat rounded="lg" class="mb-3 pa-3 filter-bar">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="pharmacySearch" prepend-inner-icon="mdi-magnify" placeholder="Search patient name, phone…" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="pharmacyStatusFilter" :items="['active','dispensed','cancelled']" label="Status" variant="outlined" density="compact" hide-details clearable />
          </v-col>
          <v-col cols="6" md="3" class="d-flex justify-end">
            <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-plus" size="small" @click="openPharmacyDialog">New Walk-in Rx</v-btn>
          </v-col>
        </v-row>
      </v-card>
      <v-card flat rounded="lg" class="results-card">
        <div v-if="pharmacyLoading" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="purple" size="48" />
        </div>
        <div v-else-if="!filteredPharmacyRx.length" class="pa-10 text-center">
          <v-icon size="64" color="grey-lighten-1">mdi-store</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-3">No pharmacy walk-in prescriptions</div>
          <div class="text-body-2 text-medium-emphasis mb-4">Issue a walk-in prescription for patients not in the system.</div>
          <v-btn color="purple" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openPharmacyDialog">New Walk-in Rx</v-btn>
        </div>
        <v-data-table v-else :headers="pharmacyHeaders" :items="filteredPharmacyRx" :items-per-page="20" item-value="id" hover>
          <template #item.patient_name="{ item }">
            <div class="font-weight-medium">{{ item.patient_name }}</div>
            <div v-if="item.patient_phone" class="text-caption text-medium-emphasis">{{ item.patient_phone }}</div>
          </template>
          <template #item.meds="{ item }">
            <div class="d-flex ga-1 flex-wrap">
              <v-chip v-for="(m, idx) in (item.items || []).slice(0, 3)" :key="idx" size="x-small" variant="outlined" color="purple">
                {{ m.medication_name }}
              </v-chip>
              <v-chip v-if="(item.items || []).length > 3" size="x-small" variant="tonal" color="purple">+{{ item.items.length - 3 }}</v-chip>
            </div>
          </template>
          <template #item.created_at="{ value }">{{ formatDate(value) }}</template>
          <template #item.status="{ value }">
            <v-chip size="small" variant="tonal" :color="statusColor(value)" class="text-capitalize">{{ value }}</v-chip>
          </template>
          <template #item.actions="{ item }">
            <div class="d-flex justify-end" @click.stop>
              <v-btn v-if="item.status === 'active'" icon="mdi-check-circle" variant="text" size="small" color="success" @click="markPharmacyDispensed(item)" />
              <v-btn v-if="item.status === 'active'" icon="mdi-close-circle" variant="text" size="small" color="error" @click="cancelPharmacyRx(item)" />
              <v-btn icon="mdi-printer" variant="text" size="small" @click="printPharmacyRx(item)" />
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ═══════════════════════════════════════════════════════════════
         CREATE PRESCRIPTION DIALOG
         ═════════════════════════════════════════════════════════════ -->
    <v-dialog v-model="createDialog" max-width="900" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple-lighten-5" size="36" class="mr-3"><v-icon color="purple-darken-2">mdi-pill-plus</v-icon></v-avatar>
          <span class="text-h6 font-weight-bold">New Prescription</span>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="closeCreate" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <!-- Patient selection -->
          <div class="d-flex align-center mb-3">
            <v-icon color="indigo" class="mr-2">mdi-account-group</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Patient</span>
          </div>
          <v-row dense class="mb-2">
            <v-col cols="12" md="6">
              <v-select v-model="createForm.patient" :items="patientOptions" item-title="title" item-value="value" label="Patient *" variant="outlined" density="compact" :rules="[v => !!v || 'Required']" prepend-inner-icon="mdi-account" :loading="patientLoading" @update:model-value="onPatientChange" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="createForm.consultation" :items="consultationOptions" item-title="label" item-value="value" :label="createForm.patient ? 'Consultation *' : 'Select patient first'" variant="outlined" density="compact" prepend-inner-icon="mdi-stethoscope" :loading="consultationLoading" :disabled="!createForm.patient" :rules="[v => !!v || 'Required']" :hint="consultationHint" persistent-hint />
            </v-col>
          </v-row>
          <!-- Allergy banner -->
          <v-alert v-if="selectedPatientAllergies.length" type="warning" variant="tonal" density="compact" class="mb-3" prepend-icon="mdi-alert">
            <strong>Allergies:</strong> {{ selectedPatientAllergies.join(', ') }}
          </v-alert>
          <!-- Meds -->
          <div class="d-flex align-center mb-3 mt-2">
            <v-icon color="indigo" class="mr-2">mdi-pill-multiple</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Medication Items ({{ createMeds.length }})</span>
            <v-spacer />
            <v-btn color="indigo" variant="tonal" rounded="lg" size="small" prepend-icon="mdi-plus" @click="addCreateMed">Add</v-btn>
          </div>
          <div v-for="(m, i) in createMeds" :key="i" class="med-row pa-3 mb-3 rounded-lg">
            <div class="d-flex align-center justify-space-between mb-2">
              <div class="text-caption font-weight-bold text-medium-emphasis">Drug #{{ i + 1 }}</div>
              <div class="d-flex align-center ga-1">
                <v-btn v-if="!m.isCustom" size="x-small" variant="text" color="indigo" prepend-icon="mdi-keyboard" @click="switchToCustom(i)">Enter manually</v-btn>
                <v-btn v-else size="x-small" variant="text" color="indigo" prepend-icon="mdi-magnify" @click="switchToSearch(i)">Search catalog</v-btn>
                <v-btn v-if="createMeds.length > 1" icon="mdi-close" variant="text" size="small" color="error" @click="createMeds.splice(i, 1)" />
              </div>
            </div>
            <v-row dense>
              <v-col cols="12" md="6">
                <template v-if="!m.isCustom">
                  <v-autocomplete
                    v-model="m.selectedMed" :items="medSearchResults" :loading="medSearching" :search="m.search" @update:search="onMedSearch"
                    @update:model-value="onMedSelect($event, i)" item-title="label" item-value="id" return-object
                    label="Medication *" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-pill" placeholder="Search medication…" clearable />
                  <div v-if="m.selectedMed" class="text-caption text-medium-emphasis mt-1">
                    <span v-if="m.selectedMed.category">{{ m.selectedMed.category }}</span>
                    <span v-if="m.selectedMed.requires_prescription" class="ml-2"><v-chip size="x-small" variant="tonal" color="warning">Rx required</v-chip></span>
                  </div>
                </template>
                <template v-else>
                  <v-text-field v-model="m.customName" label="Medication name *" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-pill" placeholder="e.g. Amoxicillin 500mg tablet" />
                </template>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="m.dosage" label="Dosage" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-scale" placeholder="Select or type dosage" />
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="d in dosageOptions" :key="d" size="x-small" :variant="m.dosage === d ? 'flat' : 'outlined'" :color="m.dosage === d ? 'deep-purple' : undefined" @click="m.dosage = m.dosage === d ? '' : d">
                    {{ d }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="m.frequency" label="Frequency *" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-clock-outline" placeholder="Select or type frequency" />
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="f in frequencyOptions" :key="f" size="x-small" :variant="m.frequency === f ? 'flat' : 'outlined'" :color="m.frequency === f ? 'indigo' : undefined" @click="m.frequency = m.frequency === f ? '' : f">
                    {{ f }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="m.duration" label="Duration" variant="outlined" density="compact" hide-details placeholder="e.g. 7 days" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="m.quantity" type="number" min="1" label="Quantity" variant="outlined" density="compact" hide-details />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="m.schedule" label="Schedule" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-calendar-clock" placeholder="Select or type schedule" />
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="s in scheduleOptions" :key="s" size="x-small" :variant="m.schedule === s ? 'flat' : 'outlined'" :color="m.schedule === s ? 'teal' : undefined" @click="m.schedule = m.schedule === s ? '' : s">
                    {{ s }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="m.refills" type="number" min="0" label="Refills" variant="outlined" density="compact" hide-details />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="m.instructions" label="Instructions" variant="outlined" density="compact" hide-details prepend-inner-icon="mdi-information-outline" placeholder="Select chips or type instructions" />
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="ins in instructionOptions" :key="ins" size="x-small" :variant="(m.instructions || '').includes(ins) ? 'flat' : 'outlined'" :color="(m.instructions || '').includes(ins) ? 'purple' : undefined" @click="toggleInstruction(i, ins)">
                    {{ ins }}
                  </v-chip>
                </div>
              </v-col>
            </v-row>
          </div>
          <!-- Interaction check -->
          <v-alert v-if="interactionWarnings.length" type="error" variant="tonal" density="compact" class="mb-3" prepend-icon="mdi-alert-circle">
            <div class="font-weight-bold mb-1">Drug interactions detected ({{ interactionWarnings.length }})</div>
            <div v-for="(w, idx) in interactionWarnings" :key="idx" class="text-caption">• {{ w }}</div>
          </v-alert>
          <!-- Notes -->
          <div class="d-flex align-center mb-2 mt-2"><v-icon color="grey" class="mr-2">mdi-note-text</v-icon><span class="text-subtitle-2 font-weight-bold">Notes</span></div>
          <v-textarea v-model="createForm.notes" label="General notes" rows="2" auto-grow variant="outlined" density="compact" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="closeCreate">Cancel</v-btn>
          <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-content-save" :loading="saving" :disabled="!canSaveCreate" @click="saveCreate">Create Prescription</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Pharmacy walk-in dialog ═══ -->
    <v-dialog v-model="pharmacyDialog" max-width="700" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple-lighten-5" size="36" class="mr-3"><v-icon color="purple-darken-2">mdi-store</v-icon></v-avatar>
          <span class="text-h6 font-weight-bold">New Pharmacy Walk-in Rx</span>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="pharmacyDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6"><v-text-field v-model="pharmacyForm.patient_name" label="Patient name *" variant="outlined" density="compact" :rules="[v => !!v || 'Required']" /></v-col>
            <v-col cols="12" md="6"><v-text-field v-model="pharmacyForm.patient_phone" label="Phone" variant="outlined" density="compact" /></v-col>
          </v-row>
          <div v-for="(m, i) in pharmacyMeds" :key="i" class="med-row pa-3 mb-2 rounded-lg">
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-caption font-weight-bold">Drug #{{ i + 1 }}</span>
              <v-btn v-if="pharmacyMeds.length > 1" icon="mdi-close" variant="text" size="small" color="error" @click="pharmacyMeds.splice(i, 1)" />
            </div>
            <v-row dense>
              <v-col cols="12" md="6"><v-text-field v-model="m.medication_name" label="Medication name *" variant="outlined" density="compact" hide-details /></v-col>
              <v-col cols="6" md="3"><v-text-field v-model="m.dosage" label="Dosage" variant="outlined" density="compact" hide-details /></v-col>
              <v-col cols="6" md="3"><v-select v-model="m.frequency" :items="frequencyOptions" label="Frequency" variant="outlined" density="compact" hide-details /></v-col>
              <v-col cols="6" md="3"><v-text-field v-model="m.duration" label="Duration" variant="outlined" density="compact" hide-details /></v-col>
              <v-col cols="6" md="3"><v-text-field v-model.number="m.quantity" type="number" min="1" label="Qty" variant="outlined" density="compact" hide-details /></v-col>
              <v-col cols="12"><v-text-field v-model="m.instructions" label="Instructions" variant="outlined" density="compact" hide-details /></v-col>
            </v-row>
          </div>
          <v-btn color="indigo" variant="tonal" size="small" class="mt-1" prepend-icon="mdi-plus" @click="pharmacyMeds.push({ medication_name: '', dosage: '', frequency: '', duration: '', quantity: 1, instructions: '' })">Add medication</v-btn>
          <v-textarea v-model="pharmacyForm.notes" label="Notes" rows="2" variant="outlined" density="compact" class="mt-3" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="pharmacyDialog = false">Cancel</v-btn>
          <v-btn color="purple" rounded="lg" class="text-none" prepend-icon="mdi-content-save" :loading="pharmacySaving" :disabled="!pharmacyForm.patient_name" @click="savePharmacy">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete dialog ═══ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Prescription</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3"><v-icon color="error">mdi-delete-alert</v-icon></v-avatar>
            <div>
              Delete prescription <strong>#{{ deleteTarget?.id }}</strong> for <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Snackbar ═══ -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDate, formatDateTime } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const ns = '/clinics'

const mainTab = ref('rx')
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)
const prescriptions = ref([])
const searchText = ref('')
const statusFilter = ref('')
const dateFrom = ref('')
const dateTo = ref('')
const dateMenu = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })
function showToast(t, c = 'success') { snack.text = t; snack.color = c; snack.show = true }

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Medications', key: 'meds', sortable: false },
  { title: 'Doctor', key: 'doctor_name', sortable: false },
  { title: 'Allergy', key: 'allergy_warn', sortable: false, width: 100 },
  { title: 'Date', key: 'created_at', width: 120 },
  { title: 'Status', key: 'status', sortable: false, width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 },
]
const pharmacyHeaders = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Medications', key: 'meds', sortable: false },
  { title: 'Pharmacist', key: 'pharmacist_name', sortable: false },
  { title: 'Date', key: 'created_at', width: 120 },
  { title: 'Status', key: 'status', sortable: false, width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const statusOptions = ['active', 'sent_to_exchange', 'dispensed', 'cancelled']

function statusColor(s) {
  return ({ active: 'info', sent_to_exchange: 'indigo', dispensed: 'success', cancelled: 'error', pending: 'warning', expired: 'grey' })[s] || 'grey'
}
function statusIcon(s) {
  return ({ active: 'mdi-pill', sent_to_exchange: 'mdi-send', dispensed: 'mdi-check-circle', cancelled: 'mdi-close-circle', pending: 'mdi-clock-outline', expired: 'mdi-alert-circle' })[s] || 'mdi-pill'
}
function avatarColor(name) {
  if (!name) return 'grey'
  const colors = ['purple', 'indigo', 'teal', 'blue', 'orange', 'pink', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function initials(name) {
  if (!name) return '?'
  return name.split(' ').filter(s => s).slice(0, 2).map(s => s[0]).join('').toUpperCase()
}
function medDisplayName(m) {
  if (m.is_custom) return m.custom_medication_name || m.medication_name || '—'
  return m.medication_name || '—'
}
function medShortName(m) {
  const name = medDisplayName(m)
  return name.length > 20 ? name.slice(0, 18) + '…' : name
}

function clearFilters() { statusFilter.value = ''; searchText.value = ''; dateFrom.value = ''; dateTo.value = '' }
const dateRangeLabel = computed(() => {
  if (dateFrom.value && dateTo.value) return `${dateFrom.value} → ${dateTo.value}`
  if (dateFrom.value) return `From ${dateFrom.value}`
  if (dateTo.value) return `Until ${dateTo.value}`
  return ''
})
const filteredPrescriptions = computed(() => {
  let list = prescriptions.value
  if (statusFilter.value) list = list.filter(p => (p.status || 'active') === statusFilter.value)
  if (searchText.value) {
    const q = searchText.value.toLowerCase()
    list = list.filter(p =>
      (p.patient_name || '').toLowerCase().includes(q) ||
      (p.doctor_name || '').toLowerCase().includes(q) ||
      (p.notes || '').toLowerCase().includes(q) ||
      (p.items || []).some(m => (m.medication_name || '').toLowerCase().includes(q) || (m.custom_medication_name || '').toLowerCase().includes(q)),
    )
  }
  if (dateFrom.value) list = list.filter(p => p.created_at && p.created_at.slice(0, 10) >= dateFrom.value)
  if (dateTo.value) list = list.filter(p => p.created_at && p.created_at.slice(0, 10) <= dateTo.value)
  return list
})

const kpis = computed(() => {
  const list = prescriptions.value
  const todayStr = new Date().toISOString().slice(0, 10)
  return [
    { label: 'Total', value: list.length, icon: 'mdi-pill-multiple', color: 'purple', filter: '' },
    { label: 'Active', value: list.filter(p => (p.status || 'active') === 'active').length, icon: 'mdi-pill', color: 'info', filter: 'active' },
    { label: 'Exchange', value: list.filter(p => p.status === 'sent_to_exchange').length, icon: 'mdi-send', color: 'indigo', filter: 'sent_to_exchange' },
    { label: 'Dispensed', value: list.filter(p => p.status === 'dispensed').length, icon: 'mdi-check-circle', color: 'success', filter: 'dispensed' },
    { label: 'Cancelled', value: list.filter(p => p.status === 'cancelled').length, icon: 'mdi-close-circle', color: 'error', filter: 'cancelled' },
    { label: 'Today', value: list.filter(p => p.created_at && p.created_at.slice(0, 10) === todayStr).length, icon: 'mdi-calendar-today', color: 'warning', filter: '' },
  ]
})

// Stats
const statusStats = computed(() => {
  const list = prescriptions.value
  const total = list.length || 1
  return statusOptions.map(s => {
    const count = list.filter(p => (p.status || 'active') === s).length
    return { label: s.replace(/_/g, ' '), count, pct: Math.round(count / total * 100), color: statusColor(s) }
  })
})
const topMeds = computed(() => {
  const map = {}
  prescriptions.value.forEach(p => {
    (p.items || []).forEach(m => {
      const name = medDisplayName(m)
      if (name && name !== '—') map[name] = (map[name] || 0) + 1
    })
  })
  const entries = Object.entries(map).map(([name, count]) => ({ name, count: count, pct: 0 }))
    .sort((a, b) => b.count - a.count).slice(0, 5)
  const max = entries.length ? entries[0].count : 1
  entries.forEach(e => { e.pct = Math.round(e.count / max * 100) })
  return entries
})
const weekdayStats = computed(() => {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  const short = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
  const counts = [0, 0, 0, 0, 0, 0, 0]
  prescriptions.value.forEach(p => {
    if (!p.created_at) return
    const d = new Date(p.created_at)
    counts[d.getDay()]++
  })
  return days.map((label, i) => ({ label, short: short[i], count: counts[i] }))
})
const weekdayMax = computed(() => Math.max(1, ...weekdayStats.value.map(d => d.count)))
const topPrescribers = computed(() => {
  const map = {}
  prescriptions.value.forEach(p => {
    if (p.doctor_name) map[p.doctor_name] = (map[p.doctor_name] || 0) + 1
  })
  const entries = Object.entries(map).map(([name, count]) => ({ name, count: count, pct: 0 }))
    .sort((a, b) => b.count - a.count).slice(0, 5)
  const max = entries.length ? entries[0].count : 1
  entries.forEach(e => { e.pct = Math.round(e.count / max * 100) })
  return entries
})

// =========================
// REST actions
// =========================
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/prescriptions/', { params: { page_size: 1000 } })
    prescriptions.value = data.results || data
  } catch (e) { console.error(e); showToast('Failed to load prescriptions', 'error') }
  finally { loading.value = false }
}
function goTo(id) { navigateTo(`${ns}/prescriptions/${id}`) }

async function sendToExchange(item) {
  try {
    await $api.post(`/prescriptions/${item.id}/send_to_exchange/`)
    showToast(`Rx #${item.id} sent to exchange`, 'indigo')
    await load()
  } catch (e) { showToast(e?.response?.data?.detail || 'Failed to send', 'error') }
}
async function markDispensed(item) {
  try {
    await $api.patch(`/prescriptions/${item.id}/`, { status: 'dispensed' })
    showToast(`Rx #${item.id} marked dispensed`, 'success')
    await load()
  } catch (e) { showToast('Failed to update', 'error') }
}
async function cancelRx(item) {
  try {
    await $api.patch(`/prescriptions/${item.id}/`, { status: 'cancelled' })
    showToast(`Rx #${item.id} cancelled`, 'error')
    await load()
  } catch (e) { showToast('Failed to cancel', 'error') }
}
function printRx(id) {
  navigateTo(`${ns}/prescriptions/${id}`)
  setTimeout(() => window.print(), 1000)
}
function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }
async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`/prescriptions/${deleteTarget.value.id}/`)
    showToast('Prescription deleted')
    deleteDialog.value = false; deleteTarget.value = null
    await load()
  } catch (e) { showToast('Failed to delete', 'error') }
  finally { deleting.value = false }
}

// =========================
// Create dialog
// =========================
const createDialog = ref(false)
const createForm = reactive({ patient: null, consultation: null, notes: '' })
const createMeds = reactive([])
const patientOptions = ref([])
const patientLoading = ref(false)
const consultationOptions = ref([])
const consultationLoading = ref(false)
const medSearchResults = ref([])
const medSearching = ref(false)
let medSearchTimer = null

const frequencyOptions = ['OD (once daily)', 'BID (twice daily)', 'TID (3x daily)', 'QID (4x daily)', 'PRN (as needed)', 'Every 4 hours', 'Every 6 hours', 'Every 8 hours', 'Once weekly']
const scheduleOptions = ['Morning', 'Afternoon', 'Night', 'Morning & Night', 'Morning, Afternoon & Night', 'Before meals', 'After meals', 'With food', 'At bedtime']
const instructionOptions = ['Take after meals', 'Take before meals', 'Take with food', 'Take on empty stomach', 'Take at bedtime', 'Take with plenty of water', 'Do not crush', 'Swallow whole', 'Avoid alcohol', 'Take with milk', 'Take in the morning', 'Complete the full course']
const dosageOptions = ['5mg', '10mg', '25mg', '50mg', '100mg', '200mg', '250mg', '500mg', '1g', '2g', '5ml', '10ml', '15ml', '20ml', '1 tablet', '2 tablets', '1 capsule', '1 drop', '1 puff', '1 sachet']

const selectedPatientAllergies = computed(() => {
  if (!createForm.patient) return []
  const p = patientOptions.value.find(x => x.value === createForm.patient)
  return p?.allergies || []
})

const canSaveCreate = computed(() => createForm.patient && createForm.consultation && createMeds.length > 0 && createMeds.every(m => (m.selectedMed || m.customName) && m.dosage && m.frequency))
const consultationHint = computed(() => {
  if (!createForm.patient) return 'Select a patient first'
  if (consultationLoading.value) return 'Loading consultations…'
  if (!consultationOptions.value.length) return 'No consultations found for this patient'
  return `${consultationOptions.value.length} consultation(s) available`
})
const interactionWarnings = computed(() => {
  const names = createMeds.filter(m => m.selectedMed).map(m => m.selectedMed.generic_name)
  if (names.length < 2) return []
  // basic local contraindication check — full check uses API on save
  return []
})

function openCreate() {
  createDialog.value = true
  createForm.patient = null; createForm.consultation = null; createForm.notes = ''
  consultationOptions.value = []
  createMeds.splice(0)
  addCreateMed()
  if (!patientOptions.value.length) loadPatients()
}
function closeCreate() { createDialog.value = false }
function addCreateMed() {
  createMeds.push({ selectedMed: null, search: '', isCustom: false, customName: '', dosage: '', frequency: '', duration: '', quantity: 1, instructions: '', schedule: '', refills: 0 })
}
function switchToCustom(i) {
  const m = createMeds[i]
  m.isCustom = true
  m.selectedMed = null
  m.search = ''
}
function switchToSearch(i) {
  const m = createMeds[i]
  m.isCustom = false
  m.customName = ''
}
function toggleInstruction(i, ins) {
  const m = createMeds[i]
  const parts = (m.instructions || '').split(', ').map(p => p.trim()).filter(Boolean)
  const idx = parts.indexOf(ins)
  if (idx >= 0) {
    parts.splice(idx, 1)
  } else {
    parts.push(ins)
  }
  m.instructions = parts.join(', ')
}
async function loadPatients() {
  patientLoading.value = true
  try {
    const { data } = await $api.get('/patients/', { params: { page_size: 1000 } })
    patientOptions.value = (data.results || data).map(p => ({
      title: `${p.patient_number || ''} — ${p.user_name || 'Unknown'}`.trim(),
      value: p.id,
      allergies: p.allergies || [],
    }))
  } catch (e) { console.error(e) }
  finally { patientLoading.value = false }
}
async function onPatientChange(val) {
  createForm.consultation = null
  consultationOptions.value = []
  if (!val) return
  const pid = val
  if (!pid) return
  consultationLoading.value = true
  try {
    const { data } = await $api.get('/consultations/', { params: { patient: pid, page_size: 100 } })
    const list = data.results || data
    consultationOptions.value = list.map(c => ({
      label: `#${c.id} — ${formatDate(c.created_at)} ${c.chief_complaint ? '(' + (c.chief_complaint.length > 30 ? c.chief_complaint.slice(0, 30) + '…' : c.chief_complaint) + ')' : ''} — ${c.status || 'draft'}`,
      value: c.id,
    }))
  } catch (e) { console.error('Failed to load consultations', e) }
  finally { consultationLoading.value = false }
}
function onMedSearch(q) {
  createMeds.forEach(m => { if (m.search !== q) m.search = q })
  if (medSearchTimer) clearTimeout(medSearchTimer)
  if (!q || q.length < 2) { medSearchResults.value = []; return }
  medSearching.value = true
  medSearchTimer = setTimeout(async () => {
    try {
      const { data } = await $api.get('/medications/search/', { params: { q } })
      medSearchResults.value = data
    } catch (e) { console.error(e) }
    finally { medSearching.value = false }
  }, 300)
}
function onMedSelect(val, idx) {
  if (!val) return
  const m = createMeds[idx]
  m.selectedMed = val
  if (!m.dosage && val.strength) m.dosage = val.strength
}
async function saveCreate() {
  if (!canSaveCreate.value) return
  // Check interactions via API
  const medIds = createMeds.filter(m => m.selectedMed?.id).map(m => m.selectedMed.id)
  const medNames = createMeds.filter(m => !m.selectedMed?.id && m.customName).map(m => m.customName.trim()).filter(Boolean)
  if (medIds.length + medNames.length >= 2) {
    try {
      const { data: inter } = await $api.post('/medications/check-interactions/', { medication_ids: medIds, names: medNames })
      if (inter.count > 0) {
        const severe = inter.interactions.filter(i => i.severity === 'major' || i.severity === 'contraindicated')
        if (severe.length && !confirm(`${severe.length} major drug interaction(s) detected. Continue?`)) return
      }
    } catch (e) { console.error(e) }
  }
  saving.value = true
  try {
    const patientId = createForm.patient
    const payload = {
      patient: patientId,
      consultation: createForm.consultation || null,
      notes: createForm.notes,
      items: createMeds.map(m => ({
        medication_id: m.selectedMed?.id || null,
        medication_name: m.selectedMed?.generic_name || m.customName?.trim() || '',
        custom_medication_name: m.isCustom ? (m.customName || '').trim() : '',
        is_custom: m.isCustom,
        dosage: m.dosage,
        frequency: m.frequency,
        duration: m.duration,
        quantity: m.quantity,
        instructions: m.instructions,
        schedule: m.schedule,
        refills: m.refills,
      })),
    }
    const { data } = await $api.post('/prescriptions/', payload)
    showToast(`Prescription #${data.id} created`, 'success')
    createDialog.value = false
    await load()
    goTo(data.id)
  } catch (e) { showToast(e?.response?.data?.detail || 'Failed to create', 'error') }
  finally { saving.value = false }
}

// =========================
// Pharmacy walk-in
// =========================
const pharmacyRx = ref([])
const pharmacyLoading = ref(false)
const pharmacySearch = ref('')
const pharmacyStatusFilter = ref('')
const pharmacyDialog = ref(false)
const pharmacySaving = ref(false)
const pharmacyForm = reactive({ patient_name: '', patient_phone: '', notes: '' })
const pharmacyMeds = reactive([])
const filteredPharmacyRx = computed(() => {
  let list = pharmacyRx.value
  if (pharmacyStatusFilter.value) list = list.filter(p => p.status === pharmacyStatusFilter.value)
  if (pharmacySearch.value) {
    const q = pharmacySearch.value.toLowerCase()
    list = list.filter(p => (p.patient_name || '').toLowerCase().includes(q) || (p.patient_phone || '').toLowerCase().includes(q))
  }
  return list
})
async function loadPharmacy() {
  pharmacyLoading.value = true
  try {
    const { data } = await $api.get('/prescriptions/pharmacy-rx/', { params: { page_size: 1000 } })
    pharmacyRx.value = data.results || data
  } catch (e) { console.error(e) }
  finally { pharmacyLoading.value = false }
}
function openPharmacyDialog() {
  pharmacyDialog.value = true
  pharmacyForm.patient_name = ''; pharmacyForm.patient_phone = ''; pharmacyForm.notes = ''
  pharmacyMeds.splice(0)
  pharmacyMeds.push({ medication_name: '', dosage: '', frequency: '', duration: '', quantity: 1, instructions: '' })
}
async function savePharmacy() {
  if (!pharmacyForm.patient_name) return
  pharmacySaving.value = true
  try {
    await $api.post('/prescriptions/pharmacy-rx/', { ...pharmacyForm, items: pharmacyMeds })
    showToast('Pharmacy prescription created', 'success')
    pharmacyDialog.value = false
    await loadPharmacy()
  } catch (e) { showToast('Failed to create', 'error') }
  finally { pharmacySaving.value = false }
}
async function markPharmacyDispensed(item) {
  try { await $api.patch(`/prescriptions/pharmacy-rx/${item.id}/`, { status: 'dispensed' }); showToast('Dispensed'); await loadPharmacy() }
  catch (e) { showToast('Failed', 'error') }
}
async function cancelPharmacyRx(item) {
  try { await $api.patch(`/prescriptions/pharmacy-rx/${item.id}/`, { status: 'cancelled' }); showToast('Cancelled', 'error'); await loadPharmacy() }
  catch (e) { showToast('Failed', 'error') }
}
function printPharmacyRx(item) {
  window.open(`/clinics/prescriptions?print=${item.id}`, '_blank')
}

watch(mainTab, (v) => {
  if (v === 'pharmacy' && !pharmacyRx.value.length) loadPharmacy()
})

onMounted(() => {
  load()
  if (useRoute().query.new === '1') openCreate()
})
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s; cursor: pointer; }
.kpi-card--active { border-color: rgb(var(--v-theme-purple)); background: rgba(128, 0, 128, 0.06); }
.kpi-card:hover { background: rgba(var(--v-theme-on-surface), 0.03); }
.stat-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.prescriptions-table :deep(tbody tr) { cursor: pointer; }
.med-row { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); background: rgba(var(--v-theme-on-surface), 0.02); }
.weekday-bar { width: 100%; background: rgb(var(--v-theme-purple)); border-radius: 3px 3px 0 0; min-height: 2px; transition: height 0.3s; }
.cursor-pointer { cursor: pointer; }
</style>
