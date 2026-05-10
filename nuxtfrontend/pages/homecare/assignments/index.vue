<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- ───────────── Hero ───────────── -->
    <div class="hc-asn-hero pa-5 pa-md-6 mb-4">
      <div class="d-flex align-center flex-wrap ga-4">
        <v-avatar size="56" color="white" variant="flat">
          <v-icon icon="mdi-account-switch" color="purple-darken-2" size="28" />
        </v-avatar>
        <div class="flex-grow-1 min-w-0">
          <div class="text-overline text-white" style="opacity:.85;">
            HOMECARE · CARE OPERATIONS
          </div>
          <h1 class="text-h4 font-weight-bold text-white ma-0">
            Assignment sheets
          </h1>
          <p class="text-body-2 text-white mb-0 mt-1" style="opacity:.9;">
            Roster shifts, see who's free now, and assign caregivers to patients.
            Live-in caregivers are reserved for one patient for the duration of their stay.
          </p>
        </div>
        <div class="d-flex flex-wrap ga-2">
          <v-chip variant="flat" color="white" class="text-purple-darken-2 font-weight-bold">
            <v-icon icon="mdi-account-heart" start size="14" />
            {{ caregivers.length }} caregivers
          </v-chip>
          <v-chip variant="flat" color="white" class="text-success font-weight-bold">
            <v-icon icon="mdi-check-circle" start size="14" />
            {{ availableNowCount }} available now
          </v-chip>
          <v-chip variant="flat" color="white" class="text-amber-darken-3 font-weight-bold">
            <v-icon icon="mdi-clock-time-five" start size="14" />
            {{ engagedNowCount }} engaged
          </v-chip>
          <v-chip variant="flat" color="white" class="text-purple-darken-2 font-weight-bold">
            <v-icon icon="mdi-calendar-check" start size="14" />
            {{ todayShiftsCount }} shifts today
          </v-chip>
        </div>
      </div>
    </div>

    <!-- ───────────── Tabs ───────────── -->
    <v-card rounded="xl" elevation="0" class="hc-card mb-3">
      <v-tabs v-model="tab" color="purple-darken-2" grow show-arrows>
        <v-tab value="sheets"   prepend-icon="mdi-clipboard-text-clock">Shift sheets</v-tab>
        <v-tab value="calendar" prepend-icon="mdi-calendar-month">Caregiver calendar</v-tab>
        <v-tab value="patcalendar" prepend-icon="mdi-calendar-account">Patient calendar</v-tab>
        <v-tab value="patients" prepend-icon="mdi-account-multiple">Patient assignments</v-tab>
      </v-tabs>
    </v-card>

    <v-window v-model="tab">
      <!-- ═════════════════════════════════════════════════════════
           TAB 1 · SHIFT SHEETS
      ═════════════════════════════════════════════════════════ -->
      <v-window-item value="sheets">
        <!-- Filters / quick actions -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
          <div class="d-flex flex-wrap align-center ga-2">
            <v-text-field v-model="cgSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search caregivers…" density="comfortable"
                          variant="outlined" rounded="lg" hide-details clearable
                          style="max-width:280px;" />
            <v-select v-model="sheetFilter"
                      :items="[
                        { title: 'All caregivers', value: 'all' },
                        { title: 'Available now',  value: 'available' },
                        { title: 'Engaged now',    value: 'engaged' },
                        { title: 'Live-in',        value: 'livein' },
                        { title: 'Off shift',      value: 'off' },
                      ]"
                      density="comfortable" variant="outlined" rounded="lg"
                      hide-details style="max-width:200px;" />
            <v-select v-model="categoryFilter"
                      :items="[
                        { title: 'All roles', value: 'all' },
                        { title: 'Nurse',     value: 'nurse' },
                        { title: 'HCA',       value: 'hca' },
                      ]"
                      density="comfortable" variant="outlined" rounded="lg"
                      hide-details style="max-width:160px;" />
            <v-divider vertical class="mx-1" />
            <v-btn-toggle v-model="sheetDate" mandatory density="comfortable"
                          color="purple-darken-2" variant="outlined" rounded="lg">
              <v-btn :value="dateOffset(-1)" size="small" class="text-none">Yesterday</v-btn>
              <v-btn :value="dateOffset(0)"  size="small" class="text-none">Today</v-btn>
              <v-btn :value="dateOffset(1)"  size="small" class="text-none">Tomorrow</v-btn>
            </v-btn-toggle>
            <v-text-field v-model="sheetDate" type="date" density="comfortable"
                          variant="outlined" rounded="lg" hide-details
                          style="max-width:170px;" />
            <v-spacer />
            <v-btn variant="text" size="small" rounded="lg" class="text-none"
                   prepend-icon="mdi-refresh" :loading="loadingShifts"
                   @click="loadShifts">Refresh</v-btn>
            <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus-circle" @click="openShiftDialog()">
              New shift
            </v-btn>
          </div>
        </v-card>

        <v-progress-linear v-if="loadingCg || loadingShifts" indeterminate color="purple" />

        <!-- Caregiver sheet grid -->
        <v-row v-if="filteredSheetCaregivers.length" dense>
          <v-col v-for="c in filteredSheetCaregivers" :key="c.id"
                 cols="12" sm="6" lg="4">
            <v-card rounded="xl" elevation="0" class="hc-card hc-sheet pa-4 h-100">
              <!-- Top: avatar + name + status -->
              <div class="d-flex align-center ga-3 mb-3">
                <v-avatar size="46" :color="catColor(c.category)" variant="flat">
                  <span class="text-subtitle-2 font-weight-bold text-white">
                    {{ initials(c.user?.full_name || c.user?.email) }}
                  </span>
                </v-avatar>
                <div class="flex-grow-1 min-w-0">
                  <div class="d-flex align-center ga-1">
                    <div class="text-subtitle-1 font-weight-bold text-truncate">
                      {{ c.user?.full_name || c.user?.email }}
                    </div>
                  </div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    <v-icon :icon="catIcon(c.category)" size="12" />
                    {{ catLabel(c.category) }}
                    <span v-if="c.license_number"> · #{{ c.license_number }}</span>
                  </div>
                </div>
                <div class="text-right">
                  <v-chip size="small" variant="flat"
                          :color="availabilityColor(c)"
                          class="font-weight-bold">
                    <v-icon :icon="availabilityIcon(c)" start size="14" />
                    {{ availabilityLabel(c) }}
                  </v-chip>
                </div>
              </div>

              <!-- Status detail -->
              <div class="hc-status-line pa-2 mb-3 rounded-lg">
                <template v-if="caregiverNowShift(c.id)">
                  <v-icon icon="mdi-clock-outline" size="14" class="mr-1" color="amber-darken-3" />
                  <span class="font-weight-medium">Engaged</span> ·
                  with <strong>{{ caregiverNowShift(c.id).patient_name }}</strong>
                  until <strong>{{ formatTime(caregiverNowShift(c.id).end_at) }}</strong>
                  <span v-if="caregiverNowShift(c.id).shift_type === 'live_in'"
                        class="ml-1 text-purple-darken-2">
                    · LIVE-IN
                  </span>
                </template>
                <template v-else-if="caregiverNextShift(c.id)">
                  <v-icon icon="mdi-calendar-clock" size="14" class="mr-1" color="success" />
                  <span class="font-weight-medium">Available</span> ·
                  next shift {{ formatRelative(caregiverNextShift(c.id).start_at) }}
                  with {{ caregiverNextShift(c.id).patient_name }}
                </template>
                <template v-else>
                  <v-icon icon="mdi-check-circle" size="14" class="mr-1" color="success" />
                  <span class="font-weight-medium">Available</span> · no shifts on this day
                </template>
              </div>

              <!-- Today's shifts list -->
              <div class="text-caption font-weight-bold text-medium-emphasis mb-1">
                <v-icon icon="mdi-calendar-text" size="13" />
                {{ shiftsForCaregiver(c.id).length }} shift(s) on {{ sheetDateLabel }}
              </div>
              <div v-if="shiftsForCaregiver(c.id).length" class="hc-shift-list">
                <div v-for="s in shiftsForCaregiver(c.id)" :key="s.id"
                     class="hc-shift-row pa-2 rounded-lg mb-1"
                     :class="`hc-shift-${shiftBucket(s)}`">
                  <div class="d-flex align-center ga-2">
                    <v-icon :icon="shiftIcon(s.shift_type)" size="16"
                            :color="shiftColor(s.shift_type)" />
                    <div class="flex-grow-1 min-w-0">
                      <div class="text-body-2 font-weight-bold text-truncate">
                        {{ s.patient_name }}
                      </div>
                      <div class="text-caption text-medium-emphasis">
                        {{ formatTime(s.start_at) }} – {{ formatTime(s.end_at) }}
                        · {{ shiftTypeLabel(s.shift_type) }}
                        <span v-if="s.check_in_at"> · in @ {{ formatTime(s.check_in_at) }}</span>
                        <span v-if="s.check_out_at"> · out @ {{ formatTime(s.check_out_at) }}</span>
                      </div>
                    </div>
                    <v-chip size="x-small" :color="shiftStatusColor(s.status)"
                            variant="flat" class="font-weight-bold text-uppercase">
                      {{ shiftStatusLabel(s.status) }}
                    </v-chip>
                    <!-- quick check-in/out buttons -->
                    <v-tooltip v-if="s.status === 'scheduled'" text="Check in">
                      <template #activator="{ props }">
                        <v-btn v-bind="props" icon="mdi-login" size="x-small"
                               color="success" variant="tonal"
                               @click="openCheckDialog(s, 'in')" />
                      </template>
                    </v-tooltip>
                    <v-tooltip v-else-if="s.status === 'checked_in'" text="Check out">
                      <template #activator="{ props }">
                        <v-btn v-bind="props" icon="mdi-logout" size="x-small"
                               color="primary" variant="tonal"
                               @click="openCheckDialog(s, 'out')" />
                      </template>
                    </v-tooltip>
                    <v-tooltip v-else-if="s.status === 'missed' && !s.reassigned_to"
                               text="Request reassignment">
                      <template #activator="{ props }">
                        <v-btn v-bind="props" icon="mdi-account-switch" size="x-small"
                               color="warning" variant="tonal"
                               @click="openReassignDialog(s)" />
                      </template>
                    </v-tooltip>
                    <v-menu>
                      <template #activator="{ props }">
                        <v-btn v-bind="props" icon="mdi-dots-vertical" size="x-small"
                               variant="text" />
                      </template>
                      <v-list density="compact">
                        <v-list-item v-if="s.status === 'scheduled'"
                                     prepend-icon="mdi-login"
                                     @click="openCheckDialog(s, 'in')">
                          <v-list-item-title>Check in</v-list-item-title>
                        </v-list-item>
                        <v-list-item v-if="s.status === 'checked_in'"
                                     prepend-icon="mdi-logout"
                                     @click="openCheckDialog(s, 'out')">
                          <v-list-item-title>Check out</v-list-item-title>
                        </v-list-item>
                        <v-list-item v-if="s.status === 'missed'"
                                     prepend-icon="mdi-account-switch"
                                     @click="openReassignDialog(s)">
                          <v-list-item-title>Reassign…</v-list-item-title>
                        </v-list-item>
                        <v-list-item prepend-icon="mdi-pencil"
                                     @click="openShiftDialog(s)">
                          <v-list-item-title>Edit</v-list-item-title>
                        </v-list-item>
                        <v-list-item v-if="s.status === 'scheduled'"
                                     prepend-icon="mdi-cancel"
                                     @click="cancelShift(s)">
                          <v-list-item-title>Cancel</v-list-item-title>
                        </v-list-item>
                        <v-list-item v-if="s.status === 'scheduled' || s.status === 'checked_in'"
                                     prepend-icon="mdi-account-alert"
                                     @click="markMissed(s)">
                          <v-list-item-title>Mark missed</v-list-item-title>
                        </v-list-item>
                        <v-list-item prepend-icon="mdi-delete" base-color="error"
                                     @click="deleteShift(s)">
                          <v-list-item-title>Delete</v-list-item-title>
                        </v-list-item>
                      </v-list>
                    </v-menu>
                  </div>
                  <div v-if="s.status === 'missed' && s.reassignment_requested && !s.reassigned_to"
                       class="text-caption text-warning mt-1">
                    <v-icon icon="mdi-alert" size="12" /> Awaiting reassignment
                    <span v-if="s.reassignment_reason"> · {{ s.reassignment_reason }}</span>
                  </div>
                  <div v-else-if="s.reassigned_to"
                       class="text-caption text-success mt-1">
                    <v-icon icon="mdi-check" size="12" /> Reassigned (#{{ s.reassigned_to }})
                  </div>
                </div>
              </div>
              <div v-else class="text-caption text-medium-emphasis pa-2">
                No shifts scheduled.
              </div>

              <v-divider class="my-3" />

              <div class="d-flex align-center ga-2">
                <v-btn variant="tonal" color="purple-darken-2" rounded="lg"
                       size="small" class="text-none flex-grow-1"
                       prepend-icon="mdi-plus" @click="openShiftDialog(null, c)">
                  Assign shift
                </v-btn>
                <v-btn variant="text" size="small" rounded="lg" class="text-none"
                       prepend-icon="mdi-account-multiple"
                       @click="goToPatientsTab(c.id)">
                  Patients
                </v-btn>
              </div>
            </v-card>
          </v-col>
        </v-row>
        <v-card v-else-if="!loadingCg" rounded="xl" elevation="0" class="hc-card pa-8 text-center">
          <v-icon icon="mdi-account-search" color="grey" size="48" />
          <h3 class="text-h6 font-weight-bold mt-3">No caregivers match</h3>
          <p class="text-body-2 text-medium-emphasis mb-0">
            Try clearing your filters or search.
          </p>
        </v-card>
      </v-window-item>

      <!-- ═════════════════════════════════════════════════════════
           TAB 2 · CAREGIVER CALENDAR
      ═════════════════════════════════════════════════════════ -->
      <v-window-item value="calendar">
        <!-- Toolbar -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="3">
              <v-autocomplete v-model="calCaregiverId"
                              :items="calCaregiverOptions"
                              item-title="label" item-value="id"
                              label="Caregiver" prepend-inner-icon="mdi-account-search"
                              variant="outlined" rounded="lg" density="comfortable"
                              clearable hide-details
                              placeholder="All caregivers" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="calRange"
                        :items="calRangeOptions"
                        item-title="label" item-value="value"
                        label="Range" prepend-inner-icon="mdi-calendar-range"
                        variant="outlined" rounded="lg" density="comfortable"
                        hide-details>
                <template #selection="{ item }">
                  <v-icon :icon="item.raw.icon" size="16" class="mr-2" />
                  <span>{{ item.raw.label }}</span>
                </template>
                <template #item="{ item, props }">
                  <v-list-item v-bind="props" :prepend-icon="item.raw.icon"
                               :title="item.raw.label" :subtitle="item.raw.hint" />
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" md="6">
              <div class="d-flex align-center ga-2 flex-wrap">
                <v-btn icon="mdi-chevron-left" variant="tonal" size="small"
                       @click="calShiftRange(-1)" />
                <div class="text-body-2 font-weight-medium px-2">
                  {{ calRangeLabel }}
                </div>
                <v-btn icon="mdi-chevron-right" variant="tonal" size="small"
                       @click="calShiftRange(1)" />
                <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                       prepend-icon="mdi-target" @click="calGoToday">Today</v-btn>
                <template v-if="calRange === 'custom'">
                  <v-chip color="purple-darken-2" variant="tonal" size="small"
                          prepend-icon="mdi-calendar-edit"
                          @click="openCalCustomDialog">
                    {{ calCustomStart }} → {{ calCustomEnd }}
                  </v-chip>
                  <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                         prepend-icon="mdi-pencil" @click="openCalCustomDialog">
                    Edit range
                  </v-btn>
                </template>
                <v-spacer />
                <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                       :loading="loadingShifts"
                       prepend-icon="mdi-refresh" @click="loadShifts">Refresh</v-btn>
              </div>
            </v-col>
          </v-row>
        </v-card>

        <!-- Stats summary -->
        <v-row dense class="mb-2">
          <v-col v-for="s in calStats" :key="s.label" cols="6" md="3">
            <v-card rounded="xl" elevation="0" class="hc-card pa-3 d-flex align-center ga-3">
              <v-avatar :color="s.color" variant="tonal" size="40">
                <v-icon :icon="s.icon" />
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
                <div class="text-h6 font-weight-bold">{{ s.value }}</div>
                <div v-if="s.sub" class="text-caption text-medium-emphasis">{{ s.sub }}</div>
              </div>
            </v-card>
          </v-col>
        </v-row>

        <!-- Calendar grid -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-3">
          <div v-if="loadingShifts && !calRowsForDisplay.length"
               class="text-center pa-8 text-medium-emphasis">
            <v-progress-circular indeterminate color="purple-darken-2" />
            <div class="mt-2 text-caption">Loading calendar…</div>
          </div>
          <div v-else-if="!calCaregiversForDisplay.length"
               class="text-center pa-8 text-medium-emphasis">
            <v-icon icon="mdi-calendar-remove" size="48" />
            <div class="text-body-2 mt-2">No caregivers to show.</div>
          </div>
          <div v-else class="hc-cal-scroll">
            <table class="hc-cal" :style="{ minWidth: (200 + calDays.length * 140) + 'px' }">
              <thead>
                <tr>
                  <th class="hc-cal-cg">Caregiver</th>
                  <th v-for="d in calDays" :key="d.iso"
                      class="hc-cal-day"
                      :class="{ 'hc-cal-today': d.isToday, 'hc-cal-weekend': d.isWeekend }">
                    <div class="text-caption text-medium-emphasis">{{ d.dow }}</div>
                    <div class="text-body-2 font-weight-bold">{{ d.dayNum }}</div>
                    <div class="text-caption text-medium-emphasis">{{ d.month }}</div>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in calRowsForDisplay" :key="row.caregiver.id">
                  <td class="hc-cal-cg">
                    <div class="d-flex align-center ga-2">
                      <v-avatar :color="catColor(row.caregiver.category)"
                                variant="tonal" size="36">
                        <span class="text-body-2 font-weight-bold">
                          {{ initials(row.caregiver.user?.full_name) }}
                        </span>
                      </v-avatar>
                      <div class="min-w-0">
                        <div class="text-body-2 font-weight-bold text-truncate">
                          {{ row.caregiver.user?.full_name || row.caregiver.user?.email }}
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          {{ catLabel(row.caregiver.category) }}
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          <v-icon icon="mdi-clock-outline" size="11" />
                          {{ formatHours(row.totalEngagedMin) }} engaged ·
                          {{ row.utilization }}% util
                        </div>
                      </div>
                    </div>
                  </td>
                  <td v-for="d in calDays" :key="d.iso"
                      class="hc-cal-cell"
                      :class="{ 'hc-cal-today': d.isToday,
                                'hc-cal-weekend': d.isWeekend }">
                    <div v-if="row.byDay[d.iso]?.length" class="hc-cell-shifts">
                      <div v-for="s in row.byDay[d.iso]" :key="s.id"
                           class="hc-cell-shift"
                           :class="`hc-cell-${shiftBucket(s)}`"
                           :title="`${s.patient_name} · ${shiftTypeLabel(s.shift_type)}\n${formatTime(s.start_at)} – ${formatTime(s.end_at)}\nstatus: ${shiftStatusLabel(s.status)}`"
                           @click="openCalShift(s)">
                        <div class="d-flex align-center ga-1">
                          <v-icon :icon="shiftIcon(s.shift_type)" size="11"
                                  :color="shiftColor(s.shift_type)" />
                          <span class="text-caption font-weight-bold text-truncate">
                            {{ s.patient_name }}
                          </span>
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          {{ formatTime(s.start_at) }}–{{ formatTime(s.end_at) }}
                        </div>
                        <v-chip size="x-small" :color="shiftStatusColor(s.status)"
                                variant="flat" class="mt-1 text-uppercase font-weight-bold"
                                style="height:14px;font-size:9px">
                          {{ shiftStatusLabel(s.status) }}
                        </v-chip>
                      </div>
                    </div>
                    <div v-else class="hc-cell-empty">
                      <div class="text-caption">Free</div>
                    </div>
                    <!-- per-day availability bar -->
                    <div class="hc-availbar mt-1">
                      <div class="hc-availbar-fill"
                           :style="{ width: (row.byDayPct[d.iso] || 0) + '%',
                                     background: availColor(row.byDayPct[d.iso] || 0) }" />
                    </div>
                    <div class="text-caption text-center text-medium-emphasis"
                         style="font-size:10px">
                      {{ formatHours((row.byDayMin[d.iso] || 0)) }} ·
                      {{ 100 - (row.byDayPct[d.iso] || 0) }}% free
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </v-card>
      </v-window-item>

      <!-- ═════════════════════════════════════════════════════════
           TAB 3 · PATIENT CALENDAR
      ═════════════════════════════════════════════════════════ -->
      <v-window-item value="patcalendar">
        <!-- Toolbar -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="3">
              <v-autocomplete v-model="patCalPatientId"
                              :items="patCalPatientOptions"
                              item-title="label" item-value="id"
                              label="Patient" prepend-inner-icon="mdi-account-search"
                              variant="outlined" rounded="lg" density="comfortable"
                              clearable hide-details
                              placeholder="All patients" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="patCalRange"
                        :items="calRangeOptions"
                        item-title="label" item-value="value"
                        label="Range" prepend-inner-icon="mdi-calendar-range"
                        variant="outlined" rounded="lg" density="comfortable"
                        hide-details>
                <template #selection="{ item }">
                  <v-icon :icon="item.raw.icon" size="16" class="mr-2" />
                  <span>{{ item.raw.label }}</span>
                </template>
                <template #item="{ item, props }">
                  <v-list-item v-bind="props" :prepend-icon="item.raw.icon"
                               :title="item.raw.label" :subtitle="item.raw.hint" />
                </template>
              </v-select>
            </v-col>
            <v-col cols="12" md="6">
              <div class="d-flex align-center ga-2 flex-wrap">
                <v-btn icon="mdi-chevron-left" variant="tonal" size="small"
                       @click="patCalShiftRange(-1)" />
                <div class="text-body-2 font-weight-medium px-2">
                  {{ patCalRangeLabel }}
                </div>
                <v-btn icon="mdi-chevron-right" variant="tonal" size="small"
                       @click="patCalShiftRange(1)" />
                <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                       prepend-icon="mdi-target" @click="patCalGoToday">Today</v-btn>
                <template v-if="patCalRange === 'custom'">
                  <v-chip color="purple-darken-2" variant="tonal" size="small"
                          prepend-icon="mdi-calendar-edit"
                          @click="openPatCalCustomDialog">
                    {{ patCalCustomStart }} → {{ patCalCustomEnd }}
                  </v-chip>
                  <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                         prepend-icon="mdi-pencil" @click="openPatCalCustomDialog">
                    Edit range
                  </v-btn>
                </template>
                <v-spacer />
                <v-btn variant="tonal" size="small" rounded="lg" class="text-none"
                       :loading="loadingShifts"
                       prepend-icon="mdi-refresh" @click="loadShifts">Refresh</v-btn>
              </div>
            </v-col>
          </v-row>
        </v-card>

        <!-- Stats summary -->
        <v-row dense class="mb-2">
          <v-col v-for="s in patCalStats" :key="s.label" cols="6" md="3">
            <v-card rounded="xl" elevation="0" class="hc-card pa-3 d-flex align-center ga-3">
              <v-avatar :color="s.color" variant="tonal" size="40">
                <v-icon :icon="s.icon" />
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
                <div class="text-h6 font-weight-bold">{{ s.value }}</div>
                <div v-if="s.sub" class="text-caption text-medium-emphasis">{{ s.sub }}</div>
              </div>
            </v-card>
          </v-col>
        </v-row>

        <!-- Calendar grid -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-3">
          <div v-if="loadingShifts && !patCalRowsForDisplay.length"
               class="text-center pa-8 text-medium-emphasis">
            <v-progress-circular indeterminate color="purple-darken-2" />
            <div class="mt-2 text-caption">Loading calendar…</div>
          </div>
          <div v-else-if="!patCalPatientsForDisplay.length"
               class="text-center pa-8 text-medium-emphasis">
            <v-icon icon="mdi-calendar-remove" size="48" />
            <div class="text-body-2 mt-2">No patients to show.</div>
          </div>
          <div v-else class="hc-cal-scroll">
            <table class="hc-cal" :style="{ minWidth: (220 + patCalDays.length * 140) + 'px' }">
              <thead>
                <tr>
                  <th class="hc-cal-cg" style="width:220px;min-width:220px">Patient</th>
                  <th v-for="d in patCalDays" :key="d.iso"
                      class="hc-cal-day"
                      :class="{ 'hc-cal-today': d.isToday, 'hc-cal-weekend': d.isWeekend }">
                    <div class="text-caption text-medium-emphasis">{{ d.dow }}</div>
                    <div class="text-body-2 font-weight-bold">{{ d.dayNum }}</div>
                    <div class="text-caption text-medium-emphasis">{{ d.month }}</div>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in patCalRowsForDisplay" :key="row.patient.id">
                  <td class="hc-cal-cg" style="width:220px;min-width:220px">
                    <div class="d-flex align-center ga-2">
                      <v-avatar :color="riskColor(row.patient.risk_level)"
                                variant="tonal" size="36">
                        <span class="text-body-2 font-weight-bold">
                          {{ initials(row.patient.user?.full_name) }}
                        </span>
                      </v-avatar>
                      <div class="min-w-0">
                        <div class="text-body-2 font-weight-bold text-truncate">
                          {{ row.patient.user?.full_name || row.patient.user?.email }}
                        </div>
                        <div class="text-caption text-medium-emphasis text-truncate">
                          MRN {{ row.patient.medical_record_number }}
                          <span v-if="row.patient.risk_level">
                            · {{ row.patient.risk_level }} risk
                          </span>
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          <v-icon icon="mdi-clock-outline" size="11" />
                          {{ formatHours(row.totalCareMin) }} care ·
                          {{ row.coveragePct }}% covered
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          <v-icon icon="mdi-account-heart" size="11" />
                          {{ row.uniqueCaregivers }} caregiver(s)
                        </div>
                      </div>
                    </div>
                  </td>
                  <td v-for="d in patCalDays" :key="d.iso"
                      class="hc-cal-cell"
                      :class="{ 'hc-cal-today': d.isToday,
                                'hc-cal-weekend': d.isWeekend }">
                    <div v-if="row.byDay[d.iso]?.length" class="hc-cell-shifts">
                      <div v-for="s in row.byDay[d.iso]" :key="s.id"
                           class="hc-cell-shift"
                           :class="`hc-cell-${shiftBucket(s)}`"
                           :title="`${s.caregiver_name} · ${shiftTypeLabel(s.shift_type)}\n${formatTime(s.start_at)} – ${formatTime(s.end_at)}\nstatus: ${shiftStatusLabel(s.status)}`"
                           @click="openCalShift(s)">
                        <div class="d-flex align-center ga-1">
                          <v-icon :icon="shiftIcon(s.shift_type)" size="11"
                                  :color="shiftColor(s.shift_type)" />
                          <span class="text-caption font-weight-bold text-truncate">
                            {{ s.caregiver_name }}
                          </span>
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          {{ formatTime(s.start_at) }}–{{ formatTime(s.end_at) }}
                        </div>
                        <v-chip size="x-small" :color="shiftStatusColor(s.status)"
                                variant="flat" class="mt-1 text-uppercase font-weight-bold"
                                style="height:14px;font-size:9px">
                          {{ shiftStatusLabel(s.status) }}
                        </v-chip>
                      </div>
                    </div>
                    <div v-else class="hc-cell-empty">
                      <div class="text-caption">Uncovered</div>
                    </div>
                    <!-- per-day coverage bar -->
                    <div class="hc-availbar mt-1">
                      <div class="hc-availbar-fill"
                           :style="{ width: (row.byDayPct[d.iso] || 0) + '%',
                                     background: coverageColor(row.byDayPct[d.iso] || 0) }" />
                    </div>
                    <div class="text-caption text-center text-medium-emphasis"
                         style="font-size:10px">
                      {{ formatHours(row.byDayMin[d.iso] || 0) }} ·
                      {{ row.byDayPct[d.iso] || 0 }}% covered
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </v-card>
      </v-window-item>

      <!-- ═════════════════════════════════════════════════════════
           TAB 4 · PATIENT ASSIGNMENTS  (legacy picker)
      ═════════════════════════════════════════════════════════ -->
      <v-window-item value="patients">
        <v-row>
          <!-- LEFT: caregiver picker -->
          <v-col cols="12" md="4" lg="3">
            <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
              <v-text-field v-model="cgSearch2" prepend-inner-icon="mdi-magnify"
                            placeholder="Search caregivers…" density="comfortable"
                            variant="outlined" rounded="lg" hide-details clearable />
            </v-card>
            <v-card rounded="xl" elevation="0" class="hc-card pa-2 hc-cg-list">
              <div v-if="loadingCg" class="pa-4 text-center">
                <v-progress-circular indeterminate color="teal" />
              </div>
              <template v-else>
                <div v-for="c in filteredCaregivers2" :key="c.id"
                     class="hc-cg-item"
                     :class="{ 'hc-cg-item--active': selectedId === c.id }"
                     @click="selectCaregiver(c.id)">
                  <v-avatar size="38" :color="catColor(c.category)" variant="flat">
                    <span class="text-caption font-weight-bold text-white">
                      {{ initials(c.user?.full_name || c.user?.email) }}
                    </span>
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="text-body-2 font-weight-bold text-truncate">
                      {{ c.user?.full_name || c.user?.email }}
                    </div>
                    <div class="text-caption text-medium-emphasis text-truncate">
                      <v-icon :icon="catIcon(c.category)" size="11" />
                      {{ catLabel(c.category) }}
                      · {{ c.active_patients_count || 0 }} patients
                    </div>
                  </div>
                  <v-icon v-if="selectedId === c.id" icon="mdi-chevron-right"
                          color="purple-darken-2" />
                </div>
                <div v-if="!filteredCaregivers2.length" class="pa-6 text-center">
                  <v-icon icon="mdi-account-off" color="grey" size="32" />
                  <div class="text-caption text-medium-emphasis mt-1">
                    No caregivers match.
                  </div>
                </div>
              </template>
            </v-card>
          </v-col>

          <!-- RIGHT: patient toggle list -->
          <v-col cols="12" md="8" lg="9">
            <v-card v-if="!selectedId" rounded="xl" elevation="0" class="hc-card pa-8 text-center">
              <v-icon icon="mdi-arrow-left-bold-circle" color="purple-lighten-1" size="48" />
              <h3 class="text-h6 font-weight-bold mt-3">Select a caregiver</h3>
              <p class="text-body-2 text-medium-emphasis mb-0">
                Choose a caregiver on the left to view and manage their patients.
              </p>
            </v-card>

            <template v-else>
              <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
                <div class="d-flex align-center ga-3 flex-wrap">
                  <v-avatar size="44" :color="catColor(selectedCaregiver?.category)" variant="flat">
                    <span class="text-subtitle-2 font-weight-bold text-white">
                      {{ initials(selectedCaregiver?.user?.full_name) }}
                    </span>
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="text-subtitle-1 font-weight-bold text-truncate">
                      {{ selectedCaregiver?.user?.full_name || selectedCaregiver?.user?.email }}
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon :icon="catIcon(selectedCaregiver?.category)" size="12" />
                      {{ catLabel(selectedCaregiver?.category) }}
                      · {{ selectedCount }} patient(s) selected
                      <span v-if="primaryCount" class="ml-1">
                        · <v-icon icon="mdi-star" color="amber" size="12" />
                        {{ primaryCount }} primary
                      </span>
                    </div>
                  </div>
                  <v-btn variant="text" rounded="lg" class="text-none"
                         prepend-icon="mdi-refresh" :loading="loadingPatients"
                         @click="loadAssignments">Reload</v-btn>
                  <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                         prepend-icon="mdi-content-save" :loading="saving"
                         :disabled="!isDirty" @click="save">
                    Save assignments
                  </v-btn>
                </div>
                <v-alert v-if="isDirty" type="warning" density="compact" variant="tonal"
                         rounded="lg" class="mt-2">
                  Unsaved changes — {{ pendingAdd.length }} to add,
                  {{ pendingRemove.length }} to remove.
                </v-alert>
              </v-card>

              <v-card rounded="xl" elevation="0" class="hc-card pa-3 mb-3">
                <div class="d-flex flex-wrap align-center ga-2">
                  <v-text-field v-model="patientSearch" prepend-inner-icon="mdi-magnify"
                                placeholder="Search patients by name, MRN, diagnosis…"
                                density="comfortable" variant="outlined" rounded="lg"
                                hide-details clearable style="max-width:320px;" />
                  <v-select v-model="patientFilter"
                            :items="[
                              { title: 'All patients', value: 'all' },
                              { title: 'Assigned', value: 'assigned' },
                              { title: 'Unassigned', value: 'unassigned' },
                            ]"
                            density="comfortable" variant="outlined" rounded="lg"
                            hide-details style="max-width:200px;" />
                  <v-spacer />
                  <v-btn variant="text" size="small" class="text-none"
                         prepend-icon="mdi-checkbox-multiple-marked"
                         @click="selectAllVisible">Select visible</v-btn>
                  <v-btn variant="text" size="small" class="text-none"
                         prepend-icon="mdi-checkbox-multiple-blank-outline"
                         @click="clearVisible">Clear visible</v-btn>
                </div>
              </v-card>

              <v-card rounded="xl" elevation="0" class="hc-card pa-2">
                <v-progress-linear v-if="loadingPatients" indeterminate color="purple" />
                <v-row dense class="pa-2">
                  <v-col v-for="p in filteredPatients" :key="p.id" cols="12" sm="6" lg="4">
                    <div class="hc-pa-card pa-3 d-flex align-center ga-3"
                         :class="{ 'hc-pa-card--on': isAssigned(p.id) }"
                         @click="toggle(p.id)">
                      <v-checkbox-btn :model-value="isAssigned(p.id)" color="purple"
                                      density="compact" hide-details
                                      @click.stop="toggle(p.id)" />
                      <v-avatar size="40" :color="riskColor(p.risk_level)" variant="tonal">
                        <span class="text-caption font-weight-bold">
                          {{ initials(p.user?.full_name) }}
                        </span>
                      </v-avatar>
                      <div class="flex-grow-1 min-w-0">
                        <div class="d-flex align-center ga-1">
                          <div class="text-body-2 font-weight-bold text-truncate">
                            {{ p.user?.full_name || p.medical_record_number }}
                          </div>
                          <v-tooltip v-if="p.assigned_caregiver === selectedId"
                                     text="Primary caregiver — manage on the patient page">
                            <template #activator="{ props }">
                              <v-icon v-bind="props" icon="mdi-star" color="amber" size="14" />
                            </template>
                          </v-tooltip>
                        </div>
                        <div class="text-caption text-medium-emphasis text-truncate">
                          {{ p.medical_record_number }}
                          <span v-if="p.primary_diagnosis"> · {{ p.primary_diagnosis }}</span>
                        </div>
                      </div>
                      <v-chip size="x-small" :color="riskColor(p.risk_level)" variant="flat"
                              class="text-uppercase font-weight-bold">
                        {{ p.risk_level }}
                      </v-chip>
                    </div>
                  </v-col>
                  <v-col v-if="!filteredPatients.length" cols="12" class="pa-6 text-center">
                    <v-icon icon="mdi-account-search" color="grey" size="40" />
                    <div class="text-caption text-medium-emphasis mt-1">
                      No patients match your filters.
                    </div>
                  </v-col>
                </v-row>
              </v-card>
            </template>
          </v-col>
        </v-row>
      </v-window-item>
    </v-window>

    <!-- ───────────── Shift create / edit dialog ───────────── -->
    <v-dialog v-model="shiftDialog.show" max-width="720" scrollable persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple" variant="tonal" size="40" class="mr-3">
            <v-icon :icon="shiftDialog.editing ? 'mdi-calendar-edit' : 'mdi-calendar-plus'" />
          </v-avatar>
          <div class="flex-grow-1">
            <div class="text-subtitle-1 font-weight-bold">
              {{ shiftDialog.editing ? 'Edit shift' : 'New shift assignment' }}
            </div>
            <div class="text-caption text-medium-emphasis">
              Build a shift sheet entry for a caregiver and patient.
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="shiftDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <!-- Caregiver -->
            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="shiftForm.caregiver"
                :items="caregiverOptions"
                item-title="label" item-value="id"
                label="Caregiver *" prepend-inner-icon="mdi-account-heart"
                variant="outlined" rounded="lg" density="comfortable"
                hide-details="auto"
                :error-messages="shiftFormErrors.caregiver"
                @update:model-value="onShiftCaregiverChange" />
            </v-col>
            <!-- Patient -->
            <v-col cols="12" md="6">
              <v-autocomplete
                v-model="shiftForm.patient"
                :items="patientOptions"
                item-title="label" item-value="id"
                :label="shiftPatientLockedLabel || 'Patient *'"
                prepend-inner-icon="mdi-account"
                variant="outlined" rounded="lg" density="comfortable"
                hide-details="auto"
                :disabled="!!shiftPatientLockedLabel"
                :hint="shiftPatientLockedLabel
                       ? 'This caregiver is on a live-in shift and is reserved for this patient.'
                       : ''"
                persistent-hint
                :error-messages="shiftFormErrors.patient" />
            </v-col>

            <!-- Shift type tile picker -->
            <v-col cols="12">
              <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                <v-icon icon="mdi-tag" size="13" /> Shift type
              </div>
              <div class="d-flex flex-wrap ga-2">
                <v-btn v-for="t in shiftTypeOptions" :key="t.value"
                       :prepend-icon="t.icon"
                       :color="shiftForm.shift_type === t.value ? 'purple-darken-2' : 'grey'"
                       :variant="shiftForm.shift_type === t.value ? 'flat' : 'tonal'"
                       rounded="lg" size="small" class="text-none"
                       :disabled="shiftDialog.editing && t.value === 'multi_visit'"
                       @click="shiftForm.shift_type = t.value">
                  {{ t.title }}
                </v-btn>
              </div>
            </v-col>
            <!-- Status (edit only) -->
            <v-col v-if="shiftDialog.editing" cols="12" md="6">
              <v-select
                v-model="shiftForm.status"
                :items="statusOptions"
                label="Status" prepend-inner-icon="mdi-flag"
                variant="outlined" rounded="lg" density="comfortable"
                hide-details />
            </v-col>

            <!-- ════════ SINGLE VISIT ════════ -->
            <template v-if="shiftForm.shift_type === 'visit'">
              <v-col cols="12">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                  <v-icon icon="mdi-flash" size="13" /> Quick presets
                </div>
                <div class="d-flex flex-wrap ga-2">
                  <v-btn v-for="p in SINGLE_VISIT_PRESETS" :key="p.label"
                         :prepend-icon="p.icon" variant="tonal"
                         :color="p.color" rounded="lg" size="small"
                         class="text-none" @click="applySingleVisitPreset(p)">
                    {{ p.label }}
                  </v-btn>
                </div>
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.start_date" type="date"
                              label="Start date *" prepend-inner-icon="mdi-calendar-start"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.start" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.start_time" type="time"
                              label="Start time *" prepend-inner-icon="mdi-clock-start"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.start" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.end_date" type="date"
                              label="End date *" prepend-inner-icon="mdi-calendar-end"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.end" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.end_time" type="time"
                              label="End time *" prepend-inner-icon="mdi-clock-end"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.end" />
              </v-col>
            </template>

            <!-- ════════ LIVE-IN ════════ -->
            <template v-else-if="shiftForm.shift_type === 'live_in'">
              <v-col cols="12">
                <v-alert type="info" density="compact" variant="tonal" rounded="lg">
                  <strong>Live-in:</strong> caregiver is reserved exclusively for this patient
                  for the entire stay. Other patient assignments are blocked during the window.
                </v-alert>
              </v-col>
              <v-col cols="12">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                  <v-icon icon="mdi-flash" size="13" /> Duration presets
                </div>
                <div class="d-flex flex-wrap ga-2">
                  <v-btn v-for="p in LIVE_IN_PRESETS" :key="p.label"
                         :prepend-icon="p.icon" variant="tonal"
                         :color="p.color" rounded="lg" size="small"
                         class="text-none" @click="applyLiveInPreset(p)">
                    {{ p.label }}
                  </v-btn>
                </div>
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.start_date" type="date"
                              label="Start date *" prepend-inner-icon="mdi-calendar-start"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.start" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.start_time" type="time"
                              label="Start time *" prepend-inner-icon="mdi-clock-start"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.start" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.end_date" type="date"
                              label="End date *" prepend-inner-icon="mdi-calendar-end"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.end" />
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field v-model="shiftForm.end_time" type="time"
                              label="End time *" prepend-inner-icon="mdi-clock-end"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" :error-messages="shiftFormErrors.end" />
              </v-col>
            </template>

            <!-- ════════ ON CALL ════════ -->
            <template v-else-if="shiftForm.shift_type === 'on_call'">
              <v-col v-if="!shiftDialog.editing" cols="12">
                <v-btn-toggle v-model="shiftForm.on_call_mode" mandatory
                              color="purple-darken-2" variant="outlined" rounded="lg"
                              density="comfortable">
                  <v-btn value="once" size="small" class="text-none">
                    <v-icon icon="mdi-numeric-1-circle" start size="14" /> Once
                  </v-btn>
                  <v-btn value="recurring" size="small" class="text-none">
                    <v-icon icon="mdi-calendar-week" start size="14" /> Recurring (days of week)
                  </v-btn>
                </v-btn-toggle>
              </v-col>

              <v-col cols="12">
                <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                  <v-icon icon="mdi-timer" size="13" /> Duration
                </div>
                <div class="d-flex flex-wrap ga-2">
                  <v-btn v-for="d in ON_CALL_DURATIONS" :key="d.minutes"
                         :color="shiftForm.on_call_duration_min === d.minutes ? 'blue' : 'grey'"
                         :variant="shiftForm.on_call_duration_min === d.minutes ? 'flat' : 'tonal'"
                         rounded="lg" size="small" class="text-none"
                         @click="applyOnCallDuration(d.minutes)">
                    {{ d.label }}
                  </v-btn>
                </div>
              </v-col>

              <!-- Once mode -->
              <template v-if="shiftDialog.editing || shiftForm.on_call_mode === 'once'">
                <v-col cols="12" md="4">
                  <v-text-field v-model="shiftForm.start_date" type="date"
                                label="Date *" prepend-inner-icon="mdi-calendar"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" :error-messages="shiftFormErrors.start" />
                </v-col>
                <v-col cols="12" md="4">
                  <v-text-field v-model="shiftForm.start_time" type="time"
                                label="Start time *" prepend-inner-icon="mdi-clock-start"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" :error-messages="shiftFormErrors.start"
                                @update:model-value="applyOnCallDuration(shiftForm.on_call_duration_min)" />
                </v-col>
                <v-col v-if="shiftDialog.editing" cols="12" md="4">
                  <v-text-field v-model="shiftForm.end_time" type="time"
                                label="End time *" prepend-inner-icon="mdi-clock-end"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" :error-messages="shiftFormErrors.end" />
                </v-col>
              </template>

              <!-- Recurring mode -->
              <template v-else>
                <v-col cols="12" md="6">
                  <v-text-field v-model="shiftForm.range_start" type="date"
                                label="Range start *" prepend-inner-icon="mdi-calendar-start"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="shiftForm.range_end" type="date"
                                label="Range end *" prepend-inner-icon="mdi-calendar-end"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" />
                </v-col>
                <v-col cols="12">
                  <div class="d-flex align-center justify-space-between mb-2">
                    <div class="text-caption font-weight-bold text-medium-emphasis">
                      <v-icon icon="mdi-calendar-week" size="13" /> Days of the week
                    </div>
                    <div class="d-flex ga-1">
                      <v-btn variant="text" size="x-small" class="text-none" @click="selectWeekdays">Weekdays</v-btn>
                      <v-btn variant="text" size="x-small" class="text-none" @click="selectAllDays">All</v-btn>
                    </div>
                  </div>
                  <div class="d-flex flex-wrap ga-1">
                    <v-btn v-for="d in DAYS_OF_WEEK" :key="d.value"
                           :color="shiftForm.days_of_week.includes(d.value) ? 'purple-darken-2' : 'grey'"
                           :variant="shiftForm.days_of_week.includes(d.value) ? 'flat' : 'tonal'"
                           rounded="lg" size="small" class="text-none"
                           @click="toggleDay(d.value)">
                      {{ d.short }}
                    </v-btn>
                  </div>
                  <v-alert v-if="shiftFormErrors.recurrence" type="warning"
                           density="compact" variant="tonal" rounded="lg" class="mt-2">
                    {{ shiftFormErrors.recurrence }}
                  </v-alert>
                </v-col>
                <v-col cols="12">
                  <v-switch v-model="shiftForm.same_time_every_day" color="purple-darken-2"
                            density="compact" hide-details
                            label="Same start time and duration every day" />
                </v-col>
                <v-col v-if="shiftForm.same_time_every_day" cols="12" md="6">
                  <v-text-field v-model="shiftForm.start_time" type="time"
                                label="Start time *" prepend-inner-icon="mdi-clock-start"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" />
                </v-col>
                <v-col v-else cols="12">
                  <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                    Per-day start time &amp; duration
                  </div>
                  <div v-for="d in DAYS_OF_WEEK.filter(x => shiftForm.days_of_week.includes(x.value))"
                       :key="d.value"
                       class="d-flex align-center ga-2 mb-2">
                    <v-chip size="small" color="purple-darken-2" variant="flat" class="font-weight-bold"
                            style="min-width:54px;justify-content:center;">{{ d.short }}</v-chip>
                    <v-text-field type="time"
                                  :model-value="(shiftForm.per_day_times[d.value]?.[0]?.start) || shiftForm.start_time"
                                  @update:model-value="(v) => shiftForm.per_day_times = { ...shiftForm.per_day_times, [d.value]: [{ start: v, end: '' }] }"
                                  label="Start" density="compact" variant="outlined"
                                  rounded="lg" hide-details style="max-width:140px;" />
                    <v-select :model-value="shiftForm.on_call_per_day_durations[d.value] || shiftForm.on_call_duration_min"
                              @update:model-value="(v) => shiftForm.on_call_per_day_durations = { ...shiftForm.on_call_per_day_durations, [d.value]: v }"
                              :items="ON_CALL_DURATIONS" item-title="label" item-value="minutes"
                              label="Duration" density="compact" variant="outlined"
                              rounded="lg" hide-details style="max-width:160px;" />
                  </div>
                </v-col>
              </template>
            </template>

            <!-- ════════ MULTIPLE VISITS ════════ -->
            <template v-else-if="shiftForm.shift_type === 'multi_visit'">
              <v-col cols="12">
                <v-alert type="info" density="compact" variant="tonal" rounded="lg">
                  Schedule visits across multiple days of the week within a date range.
                </v-alert>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="shiftForm.range_start" type="date"
                              label="Range start *" prepend-inner-icon="mdi-calendar-start"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="shiftForm.range_end" type="date"
                              label="Range end *" prepend-inner-icon="mdi-calendar-end"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12">
                <div class="d-flex align-center justify-space-between mb-2">
                  <div class="text-caption font-weight-bold text-medium-emphasis">
                    <v-icon icon="mdi-calendar-week" size="13" /> Days of the week
                  </div>
                  <div class="d-flex ga-1">
                    <v-btn variant="text" size="x-small" class="text-none" @click="selectWeekdays">Weekdays</v-btn>
                    <v-btn variant="text" size="x-small" class="text-none" @click="selectAllDays">All</v-btn>
                  </div>
                </div>
                <div class="d-flex flex-wrap ga-1">
                  <v-btn v-for="d in DAYS_OF_WEEK" :key="d.value"
                         :color="shiftForm.days_of_week.includes(d.value) ? 'purple-darken-2' : 'grey'"
                         :variant="shiftForm.days_of_week.includes(d.value) ? 'flat' : 'tonal'"
                         rounded="lg" size="small" class="text-none"
                         @click="toggleDay(d.value)">
                    {{ d.short }}
                  </v-btn>
                </div>
                <v-alert v-if="shiftFormErrors.recurrence" type="warning"
                         density="compact" variant="tonal" rounded="lg" class="mt-2">
                  {{ shiftFormErrors.recurrence }}
                </v-alert>
              </v-col>
              <v-col cols="12">
                <v-switch v-model="shiftForm.same_time_every_day" color="purple-darken-2"
                          density="compact" hide-details
                          label="Same time on every selected day" />
              </v-col>

              <!-- Same-time mode -->
              <template v-if="shiftForm.same_time_every_day">
                <v-col cols="12">
                  <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                    Quick presets
                  </div>
                  <div class="d-flex flex-wrap ga-2">
                    <v-btn v-for="p in MULTI_VISIT_PRESETS" :key="p.label"
                           :prepend-icon="p.icon" :color="p.color" variant="tonal"
                           rounded="lg" size="small" class="text-none"
                           @click="shiftForm.start_time = p.start; shiftForm.end_time = p.end">
                      {{ p.label }}
                    </v-btn>
                  </div>
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="shiftForm.start_time" type="time"
                                label="Start time *" prepend-inner-icon="mdi-clock-start"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="shiftForm.end_time" type="time"
                                label="End time *" prepend-inner-icon="mdi-clock-end"
                                variant="outlined" rounded="lg" density="comfortable"
                                hide-details="auto" />
                </v-col>

                <!-- Same-time availability summary -->
                <v-col v-if="shiftForm.caregiver && shiftForm.start_time && shiftForm.end_time"
                       cols="12">
                  <v-alert v-if="multiVisitSameTimeConflicts.length"
                           type="warning" density="compact" variant="tonal" rounded="lg">
                    <div class="font-weight-bold mb-1">
                      Caregiver unavailable on {{ multiVisitSameTimeConflicts.length }} of these dates:
                    </div>
                    <div class="d-flex flex-wrap ga-1">
                      <v-chip v-for="c in multiVisitSameTimeConflicts" :key="c.date + c.shift.id"
                              size="x-small" color="warning" variant="flat"
                              :title="`Engaged with ${c.shift.patient_name} ${formatTime(c.shift.start_at)}–${formatTime(c.shift.end_at)}`">
                        {{ formatDateShort(c.date) }}
                        · {{ c.shift.patient_name }}
                      </v-chip>
                    </div>
                    <div class="text-caption mt-1">
                      These dates will be skipped or fail when saving. Adjust the time or remove the day.
                    </div>
                  </v-alert>
                  <v-alert v-else type="success" density="compact" variant="tonal" rounded="lg">
                    <v-icon icon="mdi-check-circle" size="14" class="mr-1" />
                    Caregiver is available on all selected dates at this time.
                  </v-alert>
                </v-col>
              </template>

              <!-- Per-day shifts editor -->
              <template v-else>
                <v-col cols="12">
                  <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                    Per-day visits — add one or more time slots for each selected day
                  </div>
                  <div v-for="d in DAYS_OF_WEEK.filter(x => shiftForm.days_of_week.includes(x.value))"
                       :key="d.value"
                       class="hc-perday pa-2 mb-2 rounded-lg">
                    <div class="d-flex align-center ga-2 mb-2">
                      <v-chip size="small" color="purple-darken-2" variant="flat" class="font-weight-bold"
                              style="min-width:54px;justify-content:center;">{{ d.short }}</v-chip>
                      <span class="text-caption text-medium-emphasis">
                        {{ (shiftForm.per_day_times[d.value] || []).length }} slot(s)
                        · {{ recurrenceOccurrences(d.value).length }} {{ d.short }}(s) in range
                      </span>
                      <v-spacer />
                      <v-menu :close-on-content-click="false" max-width="360">
                        <template #activator="{ props }">
                          <v-btn v-bind="props" size="x-small" variant="tonal" color="purple-darken-2"
                                 prepend-icon="mdi-plus" rounded="lg" class="text-none">
                            Add slot
                          </v-btn>
                        </template>
                        <v-card rounded="lg" min-width="320">
                          <v-card-text class="pa-2">
                            <div class="text-caption text-medium-emphasis px-2 pb-1">
                              Caregiver availability on each {{ d.label }} in range:
                            </div>
                            <v-list density="compact" class="py-0">
                              <v-list-item v-for="p in MULTI_VISIT_PRESETS" :key="p.label"
                                           :prepend-icon="p.icon"
                                           :disabled="recurrenceConflicts(d.value, p.start, p.end).length
                                              === recurrenceOccurrences(d.value).length
                                              && recurrenceOccurrences(d.value).length > 0"
                                           @click="addMultiVisitSlot(d.value, p)">
                                <v-list-item-title>
                                  {{ p.label }}
                                </v-list-item-title>
                                <template #append>
                                  <v-chip
                                    size="x-small"
                                    :color="recurrenceConflicts(d.value, p.start, p.end).length ? 'warning' : 'success'"
                                    variant="flat">
                                    <v-icon
                                      :icon="recurrenceConflicts(d.value, p.start, p.end).length ? 'mdi-alert' : 'mdi-check'"
                                      start size="12" />
                                    {{
                                      recurrenceConflicts(d.value, p.start, p.end).length
                                        ? `${recurrenceConflicts(d.value, p.start, p.end).length}/${recurrenceOccurrences(d.value).length} busy`
                                        : 'Free'
                                    }}
                                  </v-chip>
                                </template>
                              </v-list-item>
                              <v-divider class="my-1" />
                              <v-list-item prepend-icon="mdi-pencil"
                                           @click="addMultiVisitSlot(d.value, { start: '09:00', end: '10:00' })">
                                <v-list-item-title>Custom slot…</v-list-item-title>
                              </v-list-item>
                            </v-list>
                          </v-card-text>
                        </v-card>
                      </v-menu>
                    </div>
                    <div v-for="(slot, idx) in (shiftForm.per_day_times[d.value] || [])"
                         :key="idx"
                         class="d-flex align-center ga-2 mb-1 flex-wrap">
                      <v-text-field v-model="slot.start" type="time" label="Start"
                                    density="compact" variant="outlined" rounded="lg"
                                    hide-details style="max-width:140px;" />
                      <v-text-field v-model="slot.end" type="time" label="End"
                                    density="compact" variant="outlined" rounded="lg"
                                    hide-details style="max-width:140px;" />
                      <v-chip v-if="slot.start && slot.end"
                              size="x-small"
                              :color="recurrenceConflicts(d.value, slot.start, slot.end).length ? 'warning' : 'success'"
                              variant="flat">
                        <v-icon
                          :icon="recurrenceConflicts(d.value, slot.start, slot.end).length ? 'mdi-alert' : 'mdi-check'"
                          start size="12" />
                        {{
                          recurrenceConflicts(d.value, slot.start, slot.end).length
                            ? `${recurrenceConflicts(d.value, slot.start, slot.end).length} conflict(s)`
                            : 'Available'
                        }}
                      </v-chip>
                      <v-btn icon="mdi-close" size="x-small" variant="text" color="error"
                             @click="removeMultiVisitSlot(d.value, idx)" />
                    </div>
                    <div v-if="!(shiftForm.per_day_times[d.value] || []).length"
                         class="text-caption text-medium-emphasis pl-1">
                      No slots — use “Add slot” above.
                    </div>
                  </div>
                </v-col>
              </template>
            </template>

            <!-- Live-in / conflict / preview chips -->
            <v-col cols="12">
              <div class="d-flex flex-wrap ga-2 align-center">
                <v-chip v-if="shiftDuration && shiftForm.shift_type !== 'multi_visit'"
                        size="small" variant="tonal" color="indigo">
                  <v-icon icon="mdi-timer-sand" start size="14" />
                  Duration {{ shiftDuration }}
                </v-chip>
                <v-chip v-if="expandedCount" size="small" variant="tonal" color="purple-darken-2">
                  <v-icon icon="mdi-calendar-multiple" start size="14" />
                  Will create {{ expandedCount }} shift(s)
                </v-chip>
                <v-chip v-if="shiftForm.shift_type === 'live_in'"
                        size="small" variant="tonal" color="purple-darken-2">
                  <v-icon icon="mdi-home-account" start size="14" />
                  Live-in · caregiver reserved for patient
                </v-chip>
              </div>
              <v-alert v-if="conflictMessage" type="warning" density="compact"
                       variant="tonal" rounded="lg" class="mt-2">
                {{ conflictMessage }}
              </v-alert>
            </v-col>

            <!-- Notes -->
            <v-col cols="12">
              <v-textarea
                v-model="shiftForm.notes"
                label="Notes" prepend-inner-icon="mdi-note-text"
                variant="outlined" rounded="lg" density="comfortable"
                rows="2" auto-grow hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="shiftDialog.editing" color="error" variant="text" rounded="lg"
                 class="text-none" prepend-icon="mdi-delete"
                 @click="deleteShift(shiftDialog.original)">
            Delete
          </v-btn>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="shiftDialog.saving" @click="shiftDialog.show = false">
            Cancel
          </v-btn>
          <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                 :prepend-icon="shiftDialog.editing ? 'mdi-content-save' : 'mdi-plus'"
                 :loading="shiftDialog.saving" @click="saveShift">
            {{ shiftDialog.editing ? 'Save changes' : 'Create shift' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Check-in / Check-out dialog ───────────── -->
    <v-dialog v-model="checkDialog.show" max-width="560" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="checkDialog.action === 'in' ? 'success' : 'primary'"
                    variant="tonal" size="42" class="mr-3">
            <v-icon :icon="checkDialog.action === 'in' ? 'mdi-login' : 'mdi-logout'" />
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-subtitle-1 font-weight-bold">
              {{ checkDialog.action === 'in' ? 'Check in to shift' : 'Check out of shift' }}
            </div>
            <div class="text-caption text-medium-emphasis text-truncate">
              {{ checkDialog.shift?.patient_name }}
              · {{ formatTime(checkDialog.shift?.start_at) }}–{{ formatTime(checkDialog.shift?.end_at) }}
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="checkDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert type="info" density="compact" variant="tonal" rounded="lg" class="mb-3">
            <strong>Visit acknowledgement:</strong> by continuing you confirm you are physically
            with the patient and your live location and identity will be recorded for compliance.
          </v-alert>

          <!-- Acknowledge -->
          <v-checkbox v-model="checkDialog.acknowledged" color="success" hide-details
                      density="compact"
                      :label="checkDialog.action === 'in'
                              ? 'I acknowledge this visit and accept GPS + PIN verification.'
                              : 'I confirm the visit is complete and accept GPS + PIN verification.'" />

          <!-- Live location -->
          <div class="hc-check-section pa-3 rounded-lg mt-3">
            <div class="d-flex align-center ga-2 mb-2">
              <v-icon icon="mdi-map-marker" color="primary" />
              <div class="text-body-2 font-weight-bold">Live location</div>
              <v-spacer />
              <v-btn size="x-small" variant="tonal" color="primary"
                     :loading="checkDialog.locating" rounded="lg" class="text-none"
                     prepend-icon="mdi-crosshairs-gps"
                     @click="captureLocation">
                {{ checkDialog.gps ? 'Refresh' : 'Share location' }}
              </v-btn>
            </div>
            <div v-if="checkDialog.gps" class="text-caption">
              <div class="d-flex align-center ga-1 mb-1">
                <v-chip size="x-small" color="success" variant="flat">
                  <v-icon icon="mdi-check" start size="12" /> Captured
                </v-chip>
                <v-progress-circular v-if="checkDialog.geocoding"
                                     indeterminate size="12" width="2" />
              </div>
              <div v-if="checkDialog.placeName"
                   class="text-body-2 font-weight-medium d-flex align-start ga-1">
                <v-icon icon="mdi-map-marker-radius" size="14" color="primary" />
                <span>{{ checkDialog.placeName }}</span>
              </div>
              <div class="text-medium-emphasis">
                lat {{ checkDialog.gps.lat.toFixed(5) }},
                lng {{ checkDialog.gps.lng.toFixed(5) }}
                <span v-if="checkDialog.gps.accuracy">
                  · ±{{ Math.round(checkDialog.gps.accuracy) }} m
                </span>
              </div>
            </div>
            <div v-else-if="checkDialog.locationError"
                 class="text-caption text-error">
              {{ checkDialog.locationError }}
            </div>
            <div v-else class="text-caption text-medium-emphasis">
              Tap “Share location” to capture your current GPS coordinates.
            </div>
          </div>

          <!-- PIN -->
          <div class="hc-check-section pa-3 rounded-lg mt-3">
            <div class="d-flex align-center ga-2 mb-2">
              <v-icon icon="mdi-lock" color="purple-darken-2" />
              <div class="text-body-2 font-weight-bold">Verify identity</div>
            </div>
            <v-text-field v-model="checkDialog.pin" label="Your 6-digit staff PIN"
                          type="password" inputmode="numeric" maxlength="6"
                          density="comfortable" variant="outlined" rounded="lg"
                          prepend-inner-icon="mdi-key" autofocus
                          :error-messages="checkDialog.pinError"
                          @keyup.enter="submitCheck" hide-details="auto" />
            <div class="text-caption text-medium-emphasis mt-1">
              <a href="#" @click.prevent="checkDialog.showMyPin = !checkDialog.showMyPin">
                {{ checkDialog.showMyPin ? 'Hide my PIN' : "Don't know your PIN? Reveal mine" }}
              </a>
              <span v-if="checkDialog.showMyPin && auth.user?.pin" class="ml-1">
                — <code>{{ auth.user.pin }}</code>
              </span>
            </div>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="checkDialog.saving" @click="checkDialog.show = false">
            Cancel
          </v-btn>
          <v-btn :color="checkDialog.action === 'in' ? 'success' : 'primary'"
                 rounded="lg" class="text-none"
                 :prepend-icon="checkDialog.action === 'in' ? 'mdi-login' : 'mdi-logout'"
                 :loading="checkDialog.saving"
                 :disabled="!canSubmitCheck"
                 @click="submitCheck">
            {{ checkDialog.action === 'in' ? 'Confirm check-in' : 'Confirm check-out' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Calendar custom range dialog ───────────── -->
    <v-dialog v-model="calCustomDialog.show" max-width="560" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple-darken-2" variant="tonal" size="42" class="mr-3">
            <v-icon icon="mdi-calendar-edit" />
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-subtitle-1 font-weight-bold">Custom date range</div>
            <div class="text-caption text-medium-emphasis">
              Pick the start and end dates to display on the calendar.
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="cancelCalCustom" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="calCustomDialog.start" type="date"
                            label="Start date"
                            prepend-inner-icon="mdi-calendar-start"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="calCustomDialog.end" type="date"
                            label="End date" :min="calCustomDialog.start"
                            prepend-inner-icon="mdi-calendar-end"
                            variant="outlined" rounded="lg" density="comfortable"
                            :error-messages="calCustomDialog.error"
                            hide-details="auto" />
            </v-col>
          </v-row>

          <div class="text-overline text-medium-emphasis mt-4 mb-2">QUICK PRESETS</div>
          <div class="d-flex flex-wrap ga-2">
            <v-chip v-for="p in calCustomPresets" :key="p.label"
                    color="purple-darken-2" variant="tonal" size="small"
                    :prepend-icon="p.icon"
                    @click="applyCalCustomPreset(p)">
              {{ p.label }}
            </v-chip>
          </div>

          <v-alert v-if="calCustomDialog.start && calCustomDialog.end
                       && calCustomDialog.end >= calCustomDialog.start"
                   type="info" density="compact" variant="tonal"
                   rounded="lg" class="mt-3">
            <div class="text-body-2">
              <strong>{{ calCustomDialogDays }}</strong> day(s) selected
              · {{ formatDateShort(calCustomDialog.start) }}
              → {{ formatDateShort(calCustomDialog.end) }}
            </div>
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="cancelCalCustom">Cancel</v-btn>
          <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                 prepend-icon="mdi-check"
                 :disabled="!calCustomDialogValid"
                 @click="applyCalCustom">
            Apply range
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Patient calendar custom range dialog ───────────── -->
    <v-dialog v-model="patCalCustomDialog.show" max-width="560" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="purple-darken-2" variant="tonal" size="42" class="mr-3">
            <v-icon icon="mdi-calendar-edit" />
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-subtitle-1 font-weight-bold">Custom date range</div>
            <div class="text-caption text-medium-emphasis">
              Pick the start and end dates for the patient calendar.
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="cancelPatCalCustom" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="patCalCustomDialog.start" type="date"
                            label="Start date"
                            prepend-inner-icon="mdi-calendar-start"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="patCalCustomDialog.end" type="date"
                            label="End date" :min="patCalCustomDialog.start"
                            prepend-inner-icon="mdi-calendar-end"
                            variant="outlined" rounded="lg" density="comfortable"
                            :error-messages="patCalCustomDialog.error"
                            hide-details="auto" />
            </v-col>
          </v-row>

          <div class="text-overline text-medium-emphasis mt-4 mb-2">QUICK PRESETS</div>
          <div class="d-flex flex-wrap ga-2">
            <v-chip v-for="p in calCustomPresets" :key="p.label"
                    color="purple-darken-2" variant="tonal" size="small"
                    :prepend-icon="p.icon"
                    @click="applyPatCalCustomPreset(p)">
              {{ p.label }}
            </v-chip>
          </div>

          <v-alert v-if="patCalCustomDialog.start && patCalCustomDialog.end
                       && patCalCustomDialog.end >= patCalCustomDialog.start"
                   type="info" density="compact" variant="tonal"
                   rounded="lg" class="mt-3">
            <div class="text-body-2">
              <strong>{{ patCalCustomDialogDays }}</strong> day(s) selected
              · {{ formatDateShort(patCalCustomDialog.start) }}
              → {{ formatDateShort(patCalCustomDialog.end) }}
            </div>
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="cancelPatCalCustom">Cancel</v-btn>
          <v-btn color="purple-darken-2" rounded="lg" class="text-none"
                 prepend-icon="mdi-check"
                 :disabled="!patCalCustomDialogValid"
                 @click="applyPatCalCustom">
            Apply range
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Mark missed dialog ───────────── -->    <v-dialog v-model="missedDialog.show" max-width="520" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error" variant="tonal" size="42" class="mr-3">
            <v-icon icon="mdi-account-alert" />
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-subtitle-1 font-weight-bold">Mark shift as missed</div>
            <div class="text-caption text-medium-emphasis text-truncate">
              {{ missedDialog.shift?.patient_name }}
              · {{ formatTime(missedDialog.shift?.start_at) }}–{{ formatTime(missedDialog.shift?.end_at) }}
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="missedDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert type="error" density="compact" variant="tonal" rounded="lg" class="mb-3">
            This will mark the shift as <strong>missed</strong> and request a
            replacement caregiver. Provide a reason and verify your identity.
          </v-alert>
          <v-textarea v-model="missedDialog.reason" label="Reason *"
                      prepend-inner-icon="mdi-message-alert"
                      variant="outlined" rounded="lg" density="comfortable"
                      rows="2" auto-grow
                      :error-messages="missedDialog.reasonError"
                      hide-details="auto" />
          <v-checkbox v-model="missedDialog.requestReassign" color="warning"
                      hide-details density="compact" class="mt-2"
                      label="Request reassignment to another caregiver" />

          <v-divider class="my-3" />
          <div class="text-overline text-medium-emphasis mb-1">VERIFY IDENTITY</div>
          <v-text-field v-model="missedDialog.pin" label="Your 6-digit staff PIN"
                        type="password" inputmode="numeric" maxlength="6"
                        density="comfortable" variant="outlined" rounded="lg"
                        prepend-inner-icon="mdi-key"
                        :error-messages="missedDialog.pinError"
                        @keyup.enter="submitMissed" hide-details="auto" />
          <div class="text-caption text-medium-emphasis mt-1">
            <a href="#" @click.prevent="missedDialog.showMyPin = !missedDialog.showMyPin">
              {{ missedDialog.showMyPin ? 'Hide my PIN' : "Don't know your PIN? Reveal mine" }}
            </a>
            <span v-if="missedDialog.showMyPin && auth.user?.pin" class="ml-1">
              — <code>{{ auth.user.pin }}</code>
            </span>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="missedDialog.saving" @click="missedDialog.show = false">
            Cancel
          </v-btn>
          <v-btn color="error" rounded="lg" class="text-none"
                 prepend-icon="mdi-account-alert"
                 :loading="missedDialog.saving"
                 :disabled="!missedDialog.reason?.trim() || (missedDialog.pin || '').length < 4"
                 @click="submitMissed">
            Mark missed
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ───────────── Reassign dialog ───────────── -->
    <v-dialog v-model="reassignDialog.show" max-width="520" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="warning" variant="tonal" size="42" class="mr-3">
            <v-icon icon="mdi-account-switch" />
          </v-avatar>
          <div class="flex-grow-1 min-w-0">
            <div class="text-subtitle-1 font-weight-bold">Reassign missed shift</div>
            <div class="text-caption text-medium-emphasis text-truncate">
              {{ reassignDialog.shift?.patient_name }}
              · {{ formatTime(reassignDialog.shift?.start_at) }}–{{ formatTime(reassignDialog.shift?.end_at) }}
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small"
                 @click="reassignDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-alert type="warning" density="compact" variant="tonal" rounded="lg" class="mb-3">
            This shift was missed and needs a replacement caregiver. Pick someone available
            to cover the same patient and time.
          </v-alert>
          <v-autocomplete v-model="reassignDialog.caregiver"
                          :items="reassignCandidateOptions"
                          item-title="label" item-value="id"
                          label="Replacement caregiver *"
                          prepend-inner-icon="mdi-account-heart"
                          variant="outlined" rounded="lg" density="comfortable"
                          hide-details="auto"
                          :error-messages="reassignDialog.error" />
          <v-textarea v-model="reassignDialog.reason" label="Reason / notes"
                      prepend-inner-icon="mdi-note-text"
                      variant="outlined" rounded="lg" density="comfortable"
                      rows="2" auto-grow hide-details class="mt-3" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 :disabled="reassignDialog.saving" @click="reassignDialog.show = false">
            Cancel
          </v-btn>
          <v-btn color="warning" rounded="lg" class="text-none"
                 prepend-icon="mdi-account-switch"
                 :loading="reassignDialog.saving"
                 @click="submitReassign">
            Reassign shift
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2400">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const auth = useAuthStore()

// ─── Data ───
const caregivers = ref([])
const patients = ref([])
const shifts = ref([])
const loadingCg = ref(false)
const loadingPatients = ref(false)
const loadingShifts = ref(false)
const saving = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

// ─── Tabs ───
const tab = ref('sheets')

// ─── Sheet filters ───
const cgSearch = ref('')
const sheetFilter = ref('all')          // all|available|engaged|livein|off
const categoryFilter = ref('all')       // all|nurse|hca
const sheetDate = ref(dateOffset(0))    // YYYY-MM-DD

// ─── Patient assignment (legacy) state ───
const cgSearch2 = ref('')
const patientSearch = ref('')
const patientFilter = ref('all')
const selectedId = ref(null)
const initialAssigned = ref(new Set())
const currentAssigned = ref(new Set())

// ─── Reference data ───
const CAT = {
  nurse: { label: 'Nurse', icon: 'mdi-medical-bag', color: 'indigo' },
  hca:   { label: 'HCA',   icon: 'mdi-hand-heart',  color: 'pink' },
}
function catLabel(c) { return (CAT[c] || {}).label || 'Caregiver' }
function catIcon(c)  { return (CAT[c] || {}).icon  || 'mdi-account-heart' }
function catColor(c) { return (CAT[c] || {}).color || 'teal' }

const SHIFT_TYPE = {
  visit:   { label: 'Visit',   icon: 'mdi-walk',          color: 'teal' },
  live_in: { label: 'Live-in', icon: 'mdi-home-account',  color: 'purple-darken-2' },
  on_call: { label: 'On call', icon: 'mdi-phone-in-talk', color: 'blue' },
}
function shiftTypeLabel(t) { return (SHIFT_TYPE[t] || {}).label || t }
function shiftIcon(t)      { return (SHIFT_TYPE[t] || {}).icon  || 'mdi-calendar' }
function shiftColor(t)     { return (SHIFT_TYPE[t] || {}).color || 'teal' }

// shift_type values map 1:1 to backend except 'multi_visit' which is
// a UI-only mode that expands into many `visit` records on submit.
const shiftTypeOptions = [
  { value: 'visit',       title: 'Single visit',           icon: 'mdi-walk' },
  { value: 'multi_visit', title: 'Multiple visits',        icon: 'mdi-calendar-week' },
  { value: 'on_call',     title: 'On call',                icon: 'mdi-phone-in-talk' },
  { value: 'live_in',     title: 'Live-in (reserved)',     icon: 'mdi-home-account' },
]
const statusOptions = [
  { value: 'scheduled',  title: 'Scheduled' },
  { value: 'checked_in', title: 'Checked in' },
  { value: 'completed',  title: 'Completed' },
  { value: 'missed',     title: 'Missed' },
  { value: 'cancelled',  title: 'Cancelled' },
]

// Days of week (ISO order: Mon…Sun looks nicer in clinical apps).
const DAYS_OF_WEEK = [
  { value: 1, short: 'Mon', label: 'Monday' },
  { value: 2, short: 'Tue', label: 'Tuesday' },
  { value: 3, short: 'Wed', label: 'Wednesday' },
  { value: 4, short: 'Thu', label: 'Thursday' },
  { value: 5, short: 'Fri', label: 'Friday' },
  { value: 6, short: 'Sat', label: 'Saturday' },
  { value: 0, short: 'Sun', label: 'Sunday' },
]

// Presets per UI shift_type. Each preset describes how to fill the form.
const SINGLE_VISIT_PRESETS = [
  { label: 'Day 8AM–8PM',      icon: 'mdi-weather-sunny',  color: 'amber-darken-2',
    start: '08:00', end: '20:00', overnight: false },
  { label: 'Night 8PM–8AM',    icon: 'mdi-weather-night',  color: 'indigo',
    start: '20:00', end: '08:00', overnight: true },
  { label: 'Morning 6AM–2PM',  icon: 'mdi-coffee',         color: 'orange',
    start: '06:00', end: '14:00', overnight: false },
  { label: 'Evening 2PM–10PM', icon: 'mdi-weather-sunset', color: 'deep-orange',
    start: '14:00', end: '22:00', overnight: false },
]
const LIVE_IN_PRESETS = [
  { label: 'Live-in 24h',  icon: 'mdi-home-account', color: 'purple-darken-2', days: 1 },
  { label: 'Live-in 3 days', icon: 'mdi-home-heart', color: 'purple',          days: 3 },
  { label: 'Live-in 7 days', icon: 'mdi-home-heart', color: 'purple',          days: 7 },
  { label: 'Live-in 14 days',icon: 'mdi-home-heart', color: 'purple',          days: 14 },
  { label: 'Live-in 30 days',icon: 'mdi-home-heart', color: 'purple',          days: 30 },
]
// On-call duration presets (minutes).
const ON_CALL_DURATIONS = [
  { label: '15 min', minutes: 15 },
  { label: '30 min', minutes: 30 },
  { label: '1 hr',   minutes: 60 },
  { label: '2 hrs',  minutes: 120 },
  { label: '4 hrs',  minutes: 240 },
  { label: '8 hrs',  minutes: 480 },
  { label: '12 hrs', minutes: 720 },
  { label: '24 hrs', minutes: 1440 },
]
// Multi-visit per-day time presets.
const MULTI_VISIT_PRESETS = [
  { label: 'Morning 8–12',   start: '08:00', end: '12:00', icon: 'mdi-weather-sunny',  color: 'amber' },
  { label: 'Lunch 12–14',    start: '12:00', end: '14:00', icon: 'mdi-food',           color: 'orange' },
  { label: 'Afternoon 14–18',start: '14:00', end: '18:00', icon: 'mdi-weather-sunset', color: 'deep-orange' },
  { label: 'Evening 18–22',  start: '18:00', end: '22:00', icon: 'mdi-weather-night', color: 'indigo' },
  { label: 'Bedtime 21–22',  start: '21:00', end: '22:00', icon: 'mdi-bed',            color: 'purple' },
]

// ─── Helpers ───
function dateOffset(n) {
  const d = new Date(); d.setDate(d.getDate() + n)
  return d.toISOString().slice(0, 10)
}
function pad(n) { return String(n).padStart(2, '0') }
function toIso(date, time) {
  if (!date || !time) return null
  const dt = new Date(`${date}T${time}`)
  return Number.isNaN(dt.getTime()) ? null : dt.toISOString()
}
function splitDateTime(iso) {
  if (!iso) return { date: '', time: '' }
  const d = new Date(iso)
  return {
    date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
    time: `${pad(d.getHours())}:${pad(d.getMinutes())}`,
  }
}
function initials(name) {
  if (!name) return '?'
  const p = name.trim().split(/\s+/)
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || name[0].toUpperCase()
}
function riskColor(r) {
  return ({ low: 'success', medium: 'warning', high: 'orange', critical: 'error' })[r] || 'grey'
}
function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''
}
function formatRelative(iso) {
  if (!iso) return ''
  const target = new Date(iso); const now = new Date()
  const diffMin = Math.round((target - now) / 60000)
  if (diffMin < 0) return formatTime(iso)
  if (diffMin < 60) return `in ${diffMin} min`
  const hrs = Math.round(diffMin / 60)
  if (hrs < 24) return `in ${hrs} h (${formatTime(iso)})`
  const days = Math.round(hrs / 24)
  return `in ${days} day${days === 1 ? '' : 's'} (${target.toLocaleDateString()})`
}
function shiftStatusColor(s) {
  return ({
    scheduled: 'amber-darken-2',
    checked_in: 'blue',
    completed: 'success',
    missed: 'error',
    cancelled: 'grey',
  })[s] || 'grey'
}
function shiftStatusLabel(s) {
  return ({
    scheduled: 'Scheduled',
    checked_in: 'In progress',
    completed: 'Completed',
    missed: 'Missed',
    cancelled: 'Cancelled',
  })[s] || s
}
function shiftBucket(s) {
  const start = new Date(s.start_at).getHours()
  if (s.shift_type === 'live_in') return 'livein'
  if (s.shift_type === 'on_call') return 'oncall'
  if (start >= 18 || start < 6) return 'night'
  return 'day'
}

const sheetDateLabel = computed(() => {
  if (!sheetDate.value) return ''
  const d = new Date(`${sheetDate.value}T00:00`)
  return d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })
})

// ─── Availability derived from shifts ───
function caregiverNowShift(cgId) {
  const now = Date.now()
  return shifts.value.find(s =>
    s.caregiver === cgId
    && s.status !== 'cancelled' && s.status !== 'missed'
    && new Date(s.start_at).getTime() <= now
    && new Date(s.end_at).getTime() > now
  ) || null
}
function caregiverNextShift(cgId) {
  const now = Date.now()
  return shifts.value
    .filter(s => s.caregiver === cgId
      && s.status !== 'cancelled' && s.status !== 'missed'
      && new Date(s.start_at).getTime() > now)
    .sort((a, b) => new Date(a.start_at) - new Date(b.start_at))[0] || null
}
function caregiverIsLiveIn(cgId) {
  const cur = caregiverNowShift(cgId)
  return cur && cur.shift_type === 'live_in' ? cur : null
}
function availabilityLabel(c) {
  const cur = caregiverNowShift(c.id)
  if (cur) {
    if (cur.shift_type === 'live_in') return 'Live-in'
    return `Engaged · until ${formatTime(cur.end_at)}`
  }
  if (c.is_available === false) return 'Off duty'
  return 'Available'
}
function availabilityColor(c) {
  const cur = caregiverNowShift(c.id)
  if (cur?.shift_type === 'live_in') return 'purple-darken-2'
  if (cur) return 'amber-darken-2'
  if (c.is_available === false) return 'grey'
  return 'success'
}
function availabilityIcon(c) {
  const cur = caregiverNowShift(c.id)
  if (cur?.shift_type === 'live_in') return 'mdi-home-account'
  if (cur) return 'mdi-clock-time-five'
  if (c.is_available === false) return 'mdi-cancel'
  return 'mdi-check-circle'
}

const availableNowCount = computed(() =>
  caregivers.value.filter(c => !caregiverNowShift(c.id) && c.is_available !== false).length
)
const engagedNowCount = computed(() =>
  caregivers.value.filter(c => !!caregiverNowShift(c.id)).length
)
const todayShiftsCount = computed(() => {
  const today = dateOffset(0)
  return shifts.value.filter(s => splitDateTime(s.start_at).date === today
    && s.status !== 'cancelled').length
})

const filteredSheetCaregivers = computed(() => {
  const q = cgSearch.value.trim().toLowerCase()
  return caregivers.value.filter(c => {
    if (categoryFilter.value !== 'all' && c.category !== categoryFilter.value) return false
    if (sheetFilter.value === 'available') {
      if (caregiverNowShift(c.id) || c.is_available === false) return false
    } else if (sheetFilter.value === 'engaged') {
      if (!caregiverNowShift(c.id)) return false
    } else if (sheetFilter.value === 'livein') {
      if (!caregiverIsLiveIn(c.id)) return false
    } else if (sheetFilter.value === 'off') {
      if (c.is_available !== false) return false
    }
    if (q) {
      const blob = `${c.user?.full_name || ''} ${c.user?.email || ''} ${c.license_number || ''}`.toLowerCase()
      if (!blob.includes(q)) return false
    }
    return true
  })
})

function shiftsForCaregiver(cgId) {
  return shifts.value
    .filter(s => s.caregiver === cgId
      && splitDateTime(s.start_at).date === sheetDate.value)
    .sort((a, b) => new Date(a.start_at) - new Date(b.start_at))
}

// ─── Patient assignments (legacy) ───
const filteredCaregivers2 = computed(() => {
  const q = cgSearch2.value.trim().toLowerCase()
  if (!q) return caregivers.value
  return caregivers.value.filter(c => {
    const blob = `${c.user?.full_name || ''} ${c.user?.email || ''} ${c.license_number || ''}`.toLowerCase()
    return blob.includes(q)
  })
})
const selectedCaregiver = computed(() =>
  caregivers.value.find(c => c.id === selectedId.value) || null
)
const filteredPatients = computed(() => {
  const q = patientSearch.value.trim().toLowerCase()
  let out = patients.value
  if (patientFilter.value === 'assigned') {
    out = out.filter(p => currentAssigned.value.has(p.id))
  } else if (patientFilter.value === 'unassigned') {
    out = out.filter(p => !currentAssigned.value.has(p.id))
  }
  if (!q) return out
  return out.filter(p => {
    const blob = `${p.user?.full_name || ''} ${p.medical_record_number || ''} ${p.primary_diagnosis || ''}`.toLowerCase()
    return blob.includes(q)
  })
})
const selectedCount = computed(() => currentAssigned.value.size)
const primaryCount = computed(() =>
  patients.value.filter(p => p.assigned_caregiver === selectedId.value).length
)
const pendingAdd = computed(() =>
  [...currentAssigned.value].filter(id => !initialAssigned.value.has(id))
)
const pendingRemove = computed(() =>
  [...initialAssigned.value].filter(id => !currentAssigned.value.has(id))
)
const isDirty = computed(() => pendingAdd.value.length || pendingRemove.value.length)

function isAssigned(id) { return currentAssigned.value.has(id) }
function toggle(id) {
  const s = new Set(currentAssigned.value)
  s.has(id) ? s.delete(id) : s.add(id)
  currentAssigned.value = s
}
function selectAllVisible() {
  const s = new Set(currentAssigned.value)
  for (const p of filteredPatients.value) s.add(p.id)
  currentAssigned.value = s
}
function clearVisible() {
  const s = new Set(currentAssigned.value)
  for (const p of filteredPatients.value) {
    if (p.assigned_caregiver === selectedId.value) continue
    s.delete(p.id)
  }
  currentAssigned.value = s
}

// ─── Loaders ───
async function loadAll() {
  loadingCg.value = true
  loadingPatients.value = true
  try {
    const [cg, pt] = await Promise.all([
      $api.get('/homecare/caregivers/', { params: { page_size: 500 } }),
      $api.get('/homecare/patients/',   { params: { page_size: 1000 } }),
    ])
    caregivers.value = cg.data?.results || cg.data || []
    patients.value   = pt.data?.results || pt.data || []
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load data', color: 'error' })
  } finally {
    loadingCg.value = false
    loadingPatients.value = false
  }
}

async function loadShifts() {
  loadingShifts.value = true
  try {
    // Pull a wide window so "next available" works even if the sheet date is today,
    // and so the calendar tab can render its full range.
    const baseStart = new Date(`${sheetDate.value}T00:00`)
    baseStart.setDate(baseStart.getDate() - 1)
    const baseEnd = new Date(`${sheetDate.value}T00:00`)
    baseEnd.setDate(baseEnd.getDate() + 14)
    let start = baseStart, end = baseEnd
    // Extend window to also cover the active calendar range.
    const cs = calRangeBounds.value
    if (cs) {
      const cStart = new Date(`${cs.start}T00:00`)
      const cEnd = new Date(`${cs.end}T23:59`)
      if (cStart < start) start = cStart
      if (cEnd > end) end = cEnd
    }
    const ps = patCalRangeBounds.value
    if (ps) {
      const pStart = new Date(`${ps.start}T00:00`)
      const pEnd = new Date(`${ps.end}T23:59`)
      if (pStart < start) start = pStart
      if (pEnd > end) end = pEnd
    }
    const { data } = await $api.get('/homecare/schedules/', {
      params: {
        page_size: 1000,
        start_after: start.toISOString(),
        end_before: end.toISOString(),
      },
    })
    shifts.value = data?.results || data || []
  } catch {
    shifts.value = []
  } finally {
    loadingShifts.value = false
  }
}

async function selectCaregiver(id) {
  if (isDirty.value) {
    if (!confirm('You have unsaved changes. Discard them?')) return
  }
  selectedId.value = id
  await loadAssignments()
}
async function loadAssignments() {
  if (!selectedId.value) return
  loadingPatients.value = true
  try {
    const { data } = await $api.get(
      `/homecare/caregivers/${selectedId.value}/assigned-patients/`
    )
    const ids = new Set((data || []).map(p => p.id))
    initialAssigned.value = new Set(ids)
    currentAssigned.value = new Set(ids)
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load assignments', color: 'error' })
  } finally {
    loadingPatients.value = false
  }
}
async function save() {
  if (!selectedId.value || !isDirty.value) return
  saving.value = true
  try {
    const ids = [...currentAssigned.value].filter(id => {
      const p = patients.value.find(x => x.id === id)
      return !(p && p.assigned_caregiver === selectedId.value)
    })
    const { data } = await $api.post(
      `/homecare/caregivers/${selectedId.value}/set-patients/`,
      { patient_ids: ids }
    )
    Object.assign(snack, {
      show: true, color: 'success',
      text: `Saved · +${data.added.length} added, -${data.removed.length} removed`,
    })
    initialAssigned.value = new Set(currentAssigned.value)
    loadAll()
  } catch (e) {
    Object.assign(snack, {
      show: true, color: 'error',
      text: e?.response?.data?.detail || 'Failed to save assignments',
    })
  } finally {
    saving.value = false
  }
}

function goToPatientsTab(cgId) {
  tab.value = 'patients'
  selectCaregiver(cgId)
}

// ═════════════════════════════════════════════════════════
//  SHIFT DIALOG
// ═════════════════════════════════════════════════════════
const shiftDialog = reactive({
  show: false, saving: false, editing: false, original: null,
})
const shiftForm = reactive(blankShift())
const shiftFormErrors = reactive({ caregiver: '', patient: '', start: '', end: '', recurrence: '' })

function blankShift() {
  return {
    id: null, caregiver: null, patient: null,
    shift_type: 'visit', status: 'scheduled',
    // Single visit / live-in fields
    start_date: dateOffset(0), start_time: '08:00',
    end_date: dateOffset(0),   end_time: '20:00',
    // Recurring fields (multi-visit, on-call recurring)
    range_start: dateOffset(0),
    range_end:   dateOffset(6),
    days_of_week: [1, 2, 3, 4, 5],
    same_time_every_day: true,
    per_day_times: {},                 // { 0..6: [{start,end}, ...] }
    // On-call specific
    on_call_mode: 'once',              // 'once' | 'recurring'
    on_call_duration_min: 60,
    on_call_per_day_durations: {},     // { 0..6: minutes }
    notes: '',
  }
}

const caregiverOptions = computed(() =>
  caregivers.value.map(c => ({
    id: c.id,
    label: `${c.user?.full_name || c.user?.email || 'Caregiver'} · ${catLabel(c.category)}`,
  }))
)
const patientOptions = computed(() => {
  // Restrict to live-in patient if caregiver currently engaged in live-in.
  const lockedPid = liveInLockedPatientId.value
  const pool = lockedPid
    ? patients.value.filter(p => p.id === lockedPid)
    : patients.value
  return pool.map(p => ({
    id: p.id,
    label: `${p.user?.full_name || 'Patient'} · ${p.medical_record_number}`,
  }))
})

const liveInLockedPatientId = computed(() => {
  if (!shiftForm.caregiver) return null
  const liveIn = caregiverIsLiveIn(shiftForm.caregiver)
  // If editing the very same live-in shift, don't lock it.
  if (liveIn && shiftDialog.original?.id === liveIn.id) return null
  return liveIn ? liveIn.patient : null
})
const shiftPatientLockedLabel = computed(() => {
  const pid = liveInLockedPatientId.value
  if (!pid) return ''
  const liveIn = caregiverIsLiveIn(shiftForm.caregiver)
  return liveIn ? `Patient (locked: ${liveIn.patient_name})` : ''
})

const shiftDuration = computed(() => {
  const s = toIso(shiftForm.start_date, shiftForm.start_time)
  const e = toIso(shiftForm.end_date,   shiftForm.end_time)
  if (!s || !e) return ''
  const diff = (new Date(e) - new Date(s)) / 60000
  if (diff <= 0) return ''
  const h = Math.floor(diff / 60), m = Math.round(diff % 60)
  if (h >= 24) {
    const d = Math.floor(h / 24); const rh = h % 24
    return `${d}d ${rh}h`
  }
  return `${h}h${m ? ` ${m}m` : ''}`
})

const conflictMessage = computed(() => {
  if (!shiftForm.caregiver) return ''
  // For recurring modes, expansion does the work; show a single-conflict hint only for simple modes.
  if (shiftForm.shift_type === 'multi_visit') return ''
  if (shiftForm.shift_type === 'on_call' && shiftForm.on_call_mode === 'recurring' && !shiftDialog.editing) return ''
  let s = toIso(shiftForm.start_date, shiftForm.start_time)
  let e
  if (shiftForm.shift_type === 'on_call' && shiftForm.on_call_mode === 'once' && !shiftDialog.editing) {
    e = s ? new Date(new Date(s).getTime() + shiftForm.on_call_duration_min * 60000).toISOString() : null
  } else {
    e = toIso(shiftForm.end_date, shiftForm.end_time)
  }
  if (!s || !e || new Date(e) <= new Date(s)) return ''
  const sMs = new Date(s).getTime(), eMs = new Date(e).getTime()
  const conflict = shifts.value.find(x =>
    x.caregiver === shiftForm.caregiver
    && x.id !== shiftDialog.original?.id
    && x.status !== 'cancelled' && x.status !== 'missed'
    && new Date(x.start_at).getTime() < eMs
    && new Date(x.end_at).getTime() > sMs
  )
  if (!conflict) return ''
  return `Overlaps existing shift with ${conflict.patient_name} `
       + `(${formatTime(conflict.start_at)} – ${formatTime(conflict.end_at)}, `
       + `${shiftTypeLabel(conflict.shift_type)}).`
})

const expandedCount = computed(() => {
  if (shiftDialog.editing) return 0
  if (shiftForm.shift_type === 'multi_visit') return expandMultiVisit().length
  if (shiftForm.shift_type === 'on_call' && shiftForm.on_call_mode === 'recurring')
    return expandOnCallRecurring().length
  return 0
})

// ----- Single-visit preset (start/end time, possibly overnight) -----
function applySingleVisitPreset(p) {
  shiftForm.start_time = p.start
  shiftForm.end_time   = p.end
  if (!shiftForm.start_date) shiftForm.start_date = dateOffset(0)
  // Keep start date as user picked; only adjust end_date for overnight.
  const startD = new Date(`${shiftForm.start_date}T${p.start}`)
  let endD = new Date(`${shiftForm.start_date}T${p.end}`)
  if (p.overnight || endD <= startD) {
    endD = new Date(startD); endD.setDate(endD.getDate() + 1)
    endD.setHours(parseInt(p.end.slice(0, 2), 10), parseInt(p.end.slice(3, 5), 10))
  } else {
    shiftForm.end_date = shiftForm.start_date
    return
  }
  shiftForm.end_date = `${endD.getFullYear()}-${pad(endD.getMonth() + 1)}-${pad(endD.getDate())}`
}

// ----- Live-in preset (N days, default 8AM start) -----
function applyLiveInPreset(p) {
  if (!shiftForm.start_date) shiftForm.start_date = dateOffset(0)
  shiftForm.start_time = shiftForm.start_time || '08:00'
  shiftForm.end_time   = shiftForm.start_time
  const startD = new Date(`${shiftForm.start_date}T${shiftForm.start_time}`)
  const endD = new Date(startD); endD.setDate(endD.getDate() + p.days)
  shiftForm.end_date = `${endD.getFullYear()}-${pad(endD.getMonth() + 1)}-${pad(endD.getDate())}`
}

// ----- On-call duration preset (sets end relative to start) -----
function applyOnCallDuration(minutes) {
  shiftForm.on_call_duration_min = minutes
  if (shiftForm.on_call_mode === 'once') {
    if (!shiftForm.start_date) shiftForm.start_date = dateOffset(0)
    if (!shiftForm.start_time) shiftForm.start_time = '09:00'
    const startD = new Date(`${shiftForm.start_date}T${shiftForm.start_time}`)
    const endD = new Date(startD.getTime() + minutes * 60000)
    shiftForm.end_date = `${endD.getFullYear()}-${pad(endD.getMonth() + 1)}-${pad(endD.getDate())}`
    shiftForm.end_time = `${pad(endD.getHours())}:${pad(endD.getMinutes())}`
  }
}

// ----- Multi-visit per-day preset add/remove -----
function addMultiVisitSlot(dayValue, preset) {
  const list = shiftForm.per_day_times[dayValue] || []
  list.push({ start: preset.start, end: preset.end })
  shiftForm.per_day_times = { ...shiftForm.per_day_times, [dayValue]: list }
}
function removeMultiVisitSlot(dayValue, idx) {
  const list = (shiftForm.per_day_times[dayValue] || []).slice()
  list.splice(idx, 1)
  shiftForm.per_day_times = { ...shiftForm.per_day_times, [dayValue]: list }
}
function toggleDay(value) {
  const idx = shiftForm.days_of_week.indexOf(value)
  if (idx >= 0) shiftForm.days_of_week.splice(idx, 1)
  else shiftForm.days_of_week = [...shiftForm.days_of_week, value].sort()
}
function selectWeekdays() { shiftForm.days_of_week = [1, 2, 3, 4, 5] }
function selectAllDays()  { shiftForm.days_of_week = [0, 1, 2, 3, 4, 5, 6] }

// ----- Expand recurrence into list of {start_at,end_at} pairs -----
function iterDateRange(startStr, endStr) {
  const out = []
  if (!startStr || !endStr) return out
  const start = new Date(`${startStr}T00:00`)
  const end   = new Date(`${endStr}T00:00`)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return out
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    out.push(new Date(d))
  }
  return out
}
function ymd(d) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` }

function expandMultiVisit() {
  const slots = []
  const days = iterDateRange(shiftForm.range_start, shiftForm.range_end)
  for (const d of days) {
    if (!shiftForm.days_of_week.includes(d.getDay())) continue
    const dayStr = ymd(d)
    const list = shiftForm.same_time_every_day
      ? [{ start: shiftForm.start_time, end: shiftForm.end_time }]
      : (shiftForm.per_day_times[d.getDay()] || [])
    for (const slot of list) {
      const s = toIso(dayStr, slot.start)
      let e = toIso(dayStr, slot.end)
      if (s && e && new Date(e) <= new Date(s)) {
        // overnight
        const next = new Date(d); next.setDate(next.getDate() + 1)
        e = toIso(ymd(next), slot.end)
      }
      if (s && e) slots.push({ start_at: s, end_at: e })
    }
  }
  return slots
}
// ───────────── Availability lookups for the multi-visit dialog ─────────────
// Build an ISO datetime, advancing the end date by one day if the time wraps.
function slotIsoPair(dateStr, startTime, endTime) {
  const s = toIso(dateStr, startTime)
  let e = toIso(dateStr, endTime)
  if (s && e && new Date(e) <= new Date(s)) {
    const d = new Date(`${dateStr}T00:00`); d.setDate(d.getDate() + 1)
    e = toIso(ymd(d), endTime)
  }
  return { startIso: s, endIso: e }
}
// Returns the first conflicting shift for the caregiver on a given date+time
// window. If `ignoreSamePatient` is true, shifts already on the SAME patient
// are not treated as conflicts (the user just wants to add another slot).
function slotConflict(caregiverId, dateStr, startTime, endTime, opts = {}) {
  if (!caregiverId || !dateStr || !startTime || !endTime) return null
  const { startIso, endIso } = slotIsoPair(dateStr, startTime, endTime)
  if (!startIso || !endIso) return null
  const sMs = new Date(startIso).getTime(), eMs = new Date(endIso).getTime()
  return shifts.value.find(x =>
    x.caregiver === caregiverId
    && x.id !== shiftDialog.original?.id
    && x.status !== 'cancelled' && x.status !== 'missed'
    && (!opts.ignoreSamePatient || x.patient !== opts.samePatientId)
    && new Date(x.start_at).getTime() < eMs
    && new Date(x.end_at).getTime() > sMs
  ) || null
}
// For a given day-of-week + start/end time, return list of {date, shift}
// conflicts across the current recurrence range.
function recurrenceConflicts(dayValue, startTime, endTime) {
  const out = []
  if (!shiftForm.caregiver) return out
  const days = iterDateRange(shiftForm.range_start, shiftForm.range_end)
  for (const d of days) {
    if (d.getDay() !== dayValue) continue
    const dateStr = ymd(d)
    const conflict = slotConflict(
      shiftForm.caregiver, dateStr, startTime, endTime,
      { ignoreSamePatient: true, samePatientId: shiftForm.patient },
    )
    if (conflict) out.push({ date: dateStr, shift: conflict })
  }
  return out
}
// All occurrences of a weekday within the current range (just dates).
function recurrenceOccurrences(dayValue) {
  const out = []
  const days = iterDateRange(shiftForm.range_start, shiftForm.range_end)
  for (const d of days) if (d.getDay() === dayValue) out.push(ymd(d))
  return out
}
// Same-time mode: list ALL conflicting (date, shift) across all selected days.
const multiVisitSameTimeConflicts = computed(() => {
  if (shiftForm.shift_type !== 'multi_visit'
      || !shiftForm.same_time_every_day
      || !shiftForm.caregiver
      || !shiftForm.start_time
      || !shiftForm.end_time) return []
  const out = []
  for (const dv of shiftForm.days_of_week) {
    for (const c of recurrenceConflicts(dv, shiftForm.start_time, shiftForm.end_time)) {
      out.push(c)
    }
  }
  return out.sort((a, b) => a.date.localeCompare(b.date))
})

function formatDateShort(dateStr) {
  if (!dateStr) return ''
  return new Date(`${dateStr}T00:00`).toLocaleDateString([], {
    weekday: 'short', month: 'short', day: 'numeric',
  })
}

function expandOnCallRecurring() {
  const slots = []
  const days = iterDateRange(shiftForm.range_start, shiftForm.range_end)
  for (const d of days) {
    if (!shiftForm.days_of_week.includes(d.getDay())) continue
    const dayStr = ymd(d)
    const minutes = shiftForm.same_time_every_day
      ? shiftForm.on_call_duration_min
      : (shiftForm.on_call_per_day_durations[d.getDay()] || shiftForm.on_call_duration_min)
    const startTime = shiftForm.same_time_every_day
      ? shiftForm.start_time
      : ((shiftForm.per_day_times[d.getDay()] || [])[0]?.start || shiftForm.start_time)
    const startIso = toIso(dayStr, startTime)
    if (!startIso) continue
    const endDt = new Date(new Date(startIso).getTime() + minutes * 60000)
    slots.push({ start_at: startIso, end_at: endDt.toISOString() })
  }
  return slots
}

function onShiftCaregiverChange() {
  // If caregiver becomes live-in-locked, force patient to that patient.
  const pid = liveInLockedPatientId.value
  if (pid) shiftForm.patient = pid
}

function openShiftDialog(existing = null, caregiver = null) {
  Object.assign(shiftFormErrors, { caregiver: '', patient: '', start: '', end: '', recurrence: '' })
  if (existing) {
    const s = splitDateTime(existing.start_at)
    const e = splitDateTime(existing.end_at)
    Object.assign(shiftForm, blankShift(), {
      id: existing.id,
      caregiver: existing.caregiver,
      patient: existing.patient,
      shift_type: existing.shift_type,
      status: existing.status,
      start_date: s.date, start_time: s.time,
      end_date: e.date,   end_time: e.time,
      notes: existing.notes || '',
    })
    // For on-call, reflect duration so user sees it
    if (existing.shift_type === 'on_call') {
      shiftForm.on_call_mode = 'once'
      shiftForm.on_call_duration_min = Math.max(
        15,
        Math.round((new Date(existing.end_at) - new Date(existing.start_at)) / 60000),
      )
    }
    shiftDialog.editing = true
    shiftDialog.original = existing
  } else {
    Object.assign(shiftForm, blankShift())
    if (caregiver) {
      shiftForm.caregiver = caregiver.id
      onShiftCaregiverChange()
    }
    const today = sheetDate.value || dateOffset(0)
    shiftForm.start_date = today
    shiftForm.end_date   = today
    shiftForm.range_start = today
    // Default recurring range = 7 days from sheet date
    const r = new Date(`${today}T00:00`); r.setDate(r.getDate() + 6)
    shiftForm.range_end = ymd(r)
    shiftDialog.editing = false
    shiftDialog.original = null
  }
  shiftDialog.show = true
}

// Build the list of API payloads to POST/PATCH for the current form state.
function buildShiftPayloads() {
  const base = {
    caregiver: shiftForm.caregiver,
    patient: shiftForm.patient,
    notes: shiftForm.notes || '',
  }
  // Editing always saves a single shift (we don't expand on edit)
  if (shiftDialog.editing) {
    const startIso = toIso(shiftForm.start_date, shiftForm.start_time)
    const endIso   = toIso(shiftForm.end_date,   shiftForm.end_time)
    const apiType = shiftForm.shift_type === 'multi_visit' ? 'visit' : shiftForm.shift_type
    return [{ ...base, shift_type: apiType, start_at: startIso, end_at: endIso, status: shiftForm.status }]
  }

  // Single visit
  if (shiftForm.shift_type === 'visit') {
    const startIso = toIso(shiftForm.start_date, shiftForm.start_time)
    const endIso   = toIso(shiftForm.end_date,   shiftForm.end_time)
    return [{ ...base, shift_type: 'visit', start_at: startIso, end_at: endIso }]
  }
  // Live-in
  if (shiftForm.shift_type === 'live_in') {
    const startIso = toIso(shiftForm.start_date, shiftForm.start_time)
    const endIso   = toIso(shiftForm.end_date,   shiftForm.end_time)
    return [{ ...base, shift_type: 'live_in', start_at: startIso, end_at: endIso }]
  }
  // Multi-visit → expand into many visit records
  if (shiftForm.shift_type === 'multi_visit') {
    return expandMultiVisit().map(s => ({ ...base, shift_type: 'visit', ...s }))
  }
  // On-call
  if (shiftForm.shift_type === 'on_call') {
    if (shiftForm.on_call_mode === 'once') {
      const startIso = toIso(shiftForm.start_date, shiftForm.start_time)
      const endDt = new Date(new Date(startIso).getTime() + shiftForm.on_call_duration_min * 60000)
      return [{ ...base, shift_type: 'on_call', start_at: startIso, end_at: endDt.toISOString() }]
    }
    return expandOnCallRecurring().map(s => ({ ...base, shift_type: 'on_call', ...s }))
  }
  return []
}

async function saveShift() {
  Object.assign(shiftFormErrors, { caregiver: '', patient: '', start: '', end: '', recurrence: '' })
  if (!shiftForm.caregiver) shiftFormErrors.caregiver = 'Required.'
  if (!shiftForm.patient)   shiftFormErrors.patient = 'Required.'

  // Live-in patient lock enforcement (defense in depth)
  const lockedPid = liveInLockedPatientId.value
  if (lockedPid && shiftForm.patient !== lockedPid) {
    Object.assign(snack, {
      show: true, color: 'error',
      text: 'This caregiver is on a live-in shift; assignments are locked to that patient.',
    })
    return
  }

  // Per-mode validation
  const isRecurring = !shiftDialog.editing && (
    shiftForm.shift_type === 'multi_visit'
    || (shiftForm.shift_type === 'on_call' && shiftForm.on_call_mode === 'recurring')
  )
  if (isRecurring) {
    if (!shiftForm.range_start || !shiftForm.range_end) {
      shiftFormErrors.recurrence = 'Pick a date range.'
    } else if (new Date(shiftForm.range_end) < new Date(shiftForm.range_start)) {
      shiftFormErrors.recurrence = 'End date is before start date.'
    } else if (!shiftForm.days_of_week.length) {
      shiftFormErrors.recurrence = 'Pick at least one day of the week.'
    }
  } else {
    const startIso = toIso(shiftForm.start_date, shiftForm.start_time)
    let endIso
    if (shiftForm.shift_type === 'on_call' && shiftForm.on_call_mode === 'once' && !shiftDialog.editing) {
      endIso = startIso ? new Date(new Date(startIso).getTime() + shiftForm.on_call_duration_min * 60000).toISOString() : null
    } else {
      endIso = toIso(shiftForm.end_date, shiftForm.end_time)
    }
    if (!startIso) shiftFormErrors.start = 'Invalid start.'
    if (!endIso)   shiftFormErrors.end   = 'Invalid end.'
    if (startIso && endIso && new Date(endIso) <= new Date(startIso)) {
      shiftFormErrors.end = 'End must be after start.'
    }
  }
  if (Object.values(shiftFormErrors).some(Boolean)) return

  const payloads = buildShiftPayloads()
  if (!payloads.length) {
    Object.assign(snack, { show: true, color: 'warning', text: 'Nothing to schedule — add at least one time slot.' })
    return
  }

  shiftDialog.saving = true
  try {
    if (shiftDialog.editing) {
      await $api.patch(`/homecare/schedules/${shiftForm.id}/`, payloads[0])
      Object.assign(snack, { show: true, color: 'success', text: 'Shift updated' })
    } else {
      const results = await Promise.allSettled(
        payloads.map(p => $api.post('/homecare/schedules/', p)),
      )
      const ok = results.filter(r => r.status === 'fulfilled').length
      const fail = results.length - ok
      Object.assign(snack, {
        show: true,
        color: fail ? (ok ? 'warning' : 'error') : 'success',
        text: fail
          ? `Created ${ok} of ${results.length} shifts — ${fail} failed (likely conflicts).`
          : `Created ${ok} shift${ok === 1 ? '' : 's'}`,
      })
    }
    shiftDialog.show = false
    await loadShifts()
  } catch (e) {
    Object.assign(snack, {
      show: true, color: 'error',
      text: e?.response?.data?.detail
        || JSON.stringify(e?.response?.data || {}).slice(0, 200)
        || 'Failed to save shift',
    })
  } finally {
    shiftDialog.saving = false
  }
}

async function cancelShift(s) {
  if (!confirm(`Cancel ${s.patient_name}'s shift at ${formatTime(s.start_at)}?`)) return
  try {
    await $api.post(`/homecare/schedules/${s.id}/cancel/`, { reason: 'Cancelled from sheet' })
    Object.assign(snack, { show: true, color: 'info', text: 'Shift cancelled' })
    loadShifts()
  } catch {
    Object.assign(snack, { show: true, color: 'error', text: 'Failed to cancel' })
  }
}
async function deleteShift(s) {
  if (!s) return
  if (!confirm(`Delete shift with ${s.patient_name}? This cannot be undone.`)) return
  try {
    await $api.delete(`/homecare/schedules/${s.id}/`)
    Object.assign(snack, { show: true, color: 'info', text: 'Shift deleted' })
    if (shiftDialog.show) shiftDialog.show = false
    loadShifts()
  } catch {
    Object.assign(snack, { show: true, color: 'error', text: 'Failed to delete' })
  }
}

// ═════════════════════════════════════════════════════════
//  CHECK-IN / CHECK-OUT DIALOG
// ═════════════════════════════════════════════════════════
const checkDialog = reactive({
  show: false,
  action: 'in',          // 'in' | 'out'
  shift: null,
  acknowledged: false,
  pin: '',
  pinError: '',
  showMyPin: false,
  gps: null,             // { lat, lng, accuracy, place_name? }
  placeName: '',
  geocoding: false,
  locating: false,
  locationError: '',
  saving: false,
})

const canSubmitCheck = computed(() =>
  checkDialog.acknowledged
  && !!checkDialog.gps
  && (checkDialog.pin || '').length >= 4
)

function openCheckDialog(shift, action) {
  Object.assign(checkDialog, {
    show: true,
    action,
    shift,
    acknowledged: false,
    pin: '',
    pinError: '',
    showMyPin: false,
    gps: null,
    placeName: '',
    geocoding: false,
    locating: false,
    locationError: '',
    saving: false,
  })
  // Try to capture location immediately for convenience.
  captureLocation()
}

async function reverseGeocode(lat, lng) {
  checkDialog.geocoding = true
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`,
      { headers: { 'Accept': 'application/json' } },
    )
    if (res.ok) {
      const data = await res.json()
      const a = data.address || {}
      const parts = [
        a.road || a.pedestrian || a.neighbourhood,
        a.suburb || a.village || a.town || a.city_district,
        a.city || a.county,
        a.country,
      ].filter(Boolean)
      checkDialog.placeName = parts.join(', ') || data.display_name || ''
      if (checkDialog.gps) checkDialog.gps.place_name = checkDialog.placeName
    }
  } catch { /* ignore */ }
  finally { checkDialog.geocoding = false }
}

function captureLocation() {
  checkDialog.locationError = ''
  if (typeof navigator === 'undefined' || !navigator.geolocation) {
    checkDialog.locationError = 'Geolocation is not supported by this browser.'
    return
  }
  checkDialog.locating = true
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      checkDialog.gps = {
        lat: pos.coords.latitude,
        lng: pos.coords.longitude,
        accuracy: pos.coords.accuracy,
        captured_at: new Date().toISOString(),
      }
      checkDialog.placeName = ''
      checkDialog.locating = false
      reverseGeocode(pos.coords.latitude, pos.coords.longitude)
    },
    (err) => {
      checkDialog.locationError = err.message || 'Could not access your location.'
      checkDialog.locating = false
    },
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 },
  )
}

async function submitCheck() {
  checkDialog.pinError = ''
  if (!canSubmitCheck.value) return
  checkDialog.saving = true
  try {
    const url = `/homecare/schedules/${checkDialog.shift.id}/`
              + (checkDialog.action === 'in' ? 'check_in/' : 'check_out/')
    await $api.post(url, {
      acknowledged: checkDialog.acknowledged,
      pin: checkDialog.pin,
      gps: checkDialog.gps,
    })
    Object.assign(snack, {
      show: true, color: 'success',
      text: checkDialog.action === 'in'
        ? 'Checked in — shift is in progress.'
        : 'Checked out — shift completed.',
    })
    checkDialog.show = false
    loadShifts()
  } catch (e) {
    const data = e?.response?.data || {}
    if (data.pin) checkDialog.pinError = Array.isArray(data.pin) ? data.pin[0] : String(data.pin)
    Object.assign(snack, {
      show: true, color: 'error',
      text: data.detail
        || (Array.isArray(data.acknowledged) && data.acknowledged[0])
        || (Array.isArray(data.gps) && data.gps[0])
        || checkDialog.pinError
        || 'Failed to record check-in/out.',
    })
  } finally {
    checkDialog.saving = false
  }
}

async function markMissed(s) {
  Object.assign(missedDialog, {
    show: true, shift: s,
    reason: '', reasonError: '',
    pin: '', pinError: '', showMyPin: false,
    requestReassign: true, saving: false,
  })
}

const missedDialog = reactive({
  show: false, shift: null,
  reason: '', reasonError: '',
  pin: '', pinError: '', showMyPin: false,
  requestReassign: true, saving: false,
})

async function submitMissed() {
  missedDialog.reasonError = ''
  missedDialog.pinError = ''
  if (!missedDialog.reason?.trim()) {
    missedDialog.reasonError = 'Reason is required.'
    return
  }
  if ((missedDialog.pin || '').length < 4) {
    missedDialog.pinError = 'PIN is required.'
    return
  }
  missedDialog.saving = true
  try {
    await $api.post(`/homecare/schedules/${missedDialog.shift.id}/mark_missed/`, {
      reason: missedDialog.reason.trim(),
      pin: missedDialog.pin,
      request_reassign: missedDialog.requestReassign,
    })
    Object.assign(snack, {
      show: true, color: 'warning',
      text: missedDialog.requestReassign
        ? 'Marked missed — reassignment requested.'
        : 'Shift marked as missed.',
    })
    missedDialog.show = false
    loadShifts()
  } catch (e) {
    const data = e?.response?.data || {}
    if (data.pin) missedDialog.pinError = Array.isArray(data.pin) ? data.pin[0] : String(data.pin)
    if (data.reason) missedDialog.reasonError = Array.isArray(data.reason) ? data.reason[0] : String(data.reason)
    if (!data.pin && !data.reason) {
      Object.assign(snack, {
        show: true, color: 'error',
        text: data.detail || 'Failed to mark missed',
      })
    }
  } finally {
    missedDialog.saving = false
  }
}

// ═════════════════════════════════════════════════════════
//  REASSIGN DIALOG
// ═════════════════════════════════════════════════════════
const reassignDialog = reactive({
  show: false, shift: null, caregiver: null,
  reason: '', error: '', saving: false,
})

const reassignCandidateOptions = computed(() => {
  if (!reassignDialog.shift) return []
  const startMs = new Date(reassignDialog.shift.start_at).getTime()
  const endMs   = new Date(reassignDialog.shift.end_at).getTime()
  return caregivers.value
    .filter(c => c.id !== reassignDialog.shift.caregiver
                 && c.is_available !== false
                 && c.employment_status !== 'terminated')
    .map(c => {
      const conflict = shifts.value.find(x =>
        x.caregiver === c.id
        && x.id !== reassignDialog.shift.id
        && x.status !== 'cancelled' && x.status !== 'missed'
        && new Date(x.start_at).getTime() < endMs
        && new Date(x.end_at).getTime() > startMs)
      return {
        id: c.id,
        label: `${c.user?.full_name || c.user?.email} · ${catLabel(c.category)}`
             + (conflict ? `  ⚠ busy with ${conflict.patient_name}` : '  ✓ available'),
        disabled: !!conflict,
      }
    })
})

function openReassignDialog(shift) {
  Object.assign(reassignDialog, {
    show: true, shift, caregiver: null,
    reason: shift.reassignment_reason || '', error: '', saving: false,
  })
}

async function submitReassign() {
  reassignDialog.error = ''
  if (!reassignDialog.caregiver) {
    reassignDialog.error = 'Pick a replacement caregiver.'
    return
  }
  reassignDialog.saving = true
  try {
    await $api.post(`/homecare/schedules/${reassignDialog.shift.id}/reassign/`, {
      caregiver: reassignDialog.caregiver,
      start_at: reassignDialog.shift.start_at,
      end_at: reassignDialog.shift.end_at,
    })
    if (reassignDialog.reason) {
      // Best-effort store the reason
      await $api.post(`/homecare/schedules/${reassignDialog.shift.id}/request-reassign/`, {
        reason: reassignDialog.reason,
      }).catch(() => {})
    }
    Object.assign(snack, { show: true, color: 'success', text: 'Shift reassigned.' })
    reassignDialog.show = false
    loadShifts()
  } catch (e) {
    reassignDialog.error = e?.response?.data?.detail
      || JSON.stringify(e?.response?.data || {}).slice(0, 200)
      || 'Failed to reassign'
  } finally {
    reassignDialog.saving = false
  }
}

// React to date change → reload shifts window
watch(sheetDate, () => loadShifts())

// ═════════════════════════════════════════════════════════
//  CAREGIVER CALENDAR TAB
// ═════════════════════════════════════════════════════════
const calCaregiverId = ref(null)
const calRange = ref('week')          // day | week | month | custom
const calAnchor = ref(dateOffset(0))  // ISO date string used as range anchor
const calCustomStart = ref(dateOffset(0))
const calCustomEnd = ref(dateOffset(6))
// Per-day capacity used to compute utilization % (configurable, default 12h).
const CAL_DAY_CAPACITY_MIN = 12 * 60

const calRangeOptions = [
  { value: 'day',    label: 'Today',      icon: 'mdi-calendar-today', hint: 'Single day view' },
  { value: 'week',   label: 'This week',  icon: 'mdi-calendar-week',  hint: 'Mon → Sun (7 days)' },
  { value: 'month',  label: 'This month', icon: 'mdi-calendar-month', hint: 'Full calendar month' },
  { value: 'custom', label: 'Custom',     icon: 'mdi-calendar-edit',  hint: 'Pick your own range' },
]

const calCaregiverOptions = computed(() =>
  caregivers.value.map(c => ({
    id: c.id,
    label: `${c.user?.full_name || c.user?.email} · ${catLabel(c.category)}`,
  }))
)

// Compute the [start, end] inclusive ISO date range based on calRange + anchor.
const calRangeBounds = computed(() => {
  if (calRange.value === 'custom') {
    if (!calCustomStart.value || !calCustomEnd.value) return null
    const a = calCustomStart.value, b = calCustomEnd.value
    return a <= b ? { start: a, end: b } : { start: b, end: a }
  }
  const anchor = new Date(`${calAnchor.value}T00:00`)
  if (calRange.value === 'day') {
    return { start: ymd(anchor), end: ymd(anchor) }
  }
  if (calRange.value === 'week') {
    // Monday-based week
    const dow = (anchor.getDay() + 6) % 7
    const start = new Date(anchor); start.setDate(start.getDate() - dow)
    const end = new Date(start);    end.setDate(end.getDate() + 6)
    return { start: ymd(start), end: ymd(end) }
  }
  if (calRange.value === 'month') {
    const start = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
    const end   = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0)
    return { start: ymd(start), end: ymd(end) }
  }
  return null
})

const calDays = computed(() => {
  const b = calRangeBounds.value
  if (!b) return []
  const out = []
  const start = new Date(`${b.start}T00:00`)
  const end   = new Date(`${b.end}T00:00`)
  const today = ymd(new Date())
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  const dows   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const iso = ymd(d)
    out.push({
      iso,
      dow: dows[d.getDay()],
      dayNum: d.getDate(),
      month: months[d.getMonth()],
      isToday: iso === today,
      isWeekend: d.getDay() === 0 || d.getDay() === 6,
    })
  }
  return out
})

const calRangeLabel = computed(() => {
  const b = calRangeBounds.value
  if (!b) return ''
  if (b.start === b.end) return formatDateShort(b.start)
  return `${formatDateShort(b.start)} – ${formatDateShort(b.end)}`
})

function calShiftRange(dir) {
  const map = { day: 1, week: 7, month: 30 }
  const step = map[calRange.value] || 7
  if (calRange.value === 'custom') {
    // For custom, slide both endpoints by the range width.
    const s = new Date(`${calCustomStart.value}T00:00`)
    const e = new Date(`${calCustomEnd.value}T00:00`)
    const width = Math.round((e - s) / 86400000) + 1
    s.setDate(s.getDate() + dir * width)
    e.setDate(e.getDate() + dir * width)
    calCustomStart.value = ymd(s)
    calCustomEnd.value = ymd(e)
    return
  }
  if (calRange.value === 'month') {
    const a = new Date(`${calAnchor.value}T00:00`)
    a.setMonth(a.getMonth() + dir)
    calAnchor.value = ymd(a)
    return
  }
  const a = new Date(`${calAnchor.value}T00:00`)
  a.setDate(a.getDate() + dir * step)
  calAnchor.value = ymd(a)
}

function calGoToday() {
  calAnchor.value = dateOffset(0)
  if (calRange.value === 'custom') {
    calCustomStart.value = dateOffset(0)
    calCustomEnd.value = dateOffset(6)
  }
}

// ── Custom range dialog ──
const calCustomDialog = reactive({
  show: false, start: dateOffset(0), end: dateOffset(6), error: '',
})
const calCustomPresets = [
  { label: 'Next 7 days',  icon: 'mdi-calendar-week',     start: 0,   end: 6 },
  { label: 'Next 14 days', icon: 'mdi-calendar-week-begin', start: 0, end: 13 },
  { label: 'Next 30 days', icon: 'mdi-calendar-month',    start: 0,   end: 29 },
  { label: 'Last 7 days',  icon: 'mdi-history',           start: -6,  end: 0 },
  { label: 'Last 30 days', icon: 'mdi-calendar-clock',    start: -29, end: 0 },
  { label: 'This quarter', icon: 'mdi-calendar-multiselect', start: 0, end: 89 },
]
const calCustomDialogDays = computed(() => {
  if (!calCustomDialog.start || !calCustomDialog.end) return 0
  const s = new Date(`${calCustomDialog.start}T00:00`)
  const e = new Date(`${calCustomDialog.end}T00:00`)
  return Math.max(0, Math.round((e - s) / 86400000) + 1)
})
const calCustomDialogValid = computed(() =>
  calCustomDialog.start && calCustomDialog.end
  && calCustomDialog.end >= calCustomDialog.start
)

function openCalCustomDialog() {
  calCustomDialog.start = calCustomStart.value || dateOffset(0)
  calCustomDialog.end = calCustomEnd.value || dateOffset(6)
  calCustomDialog.error = ''
  calCustomDialog.show = true
}
function applyCalCustomPreset(p) {
  calCustomDialog.start = dateOffset(p.start)
  calCustomDialog.end = dateOffset(p.end)
  calCustomDialog.error = ''
}
function applyCalCustom() {
  if (!calCustomDialogValid.value) {
    calCustomDialog.error = 'End date must be on or after the start date.'
    return
  }
  calCustomStart.value = calCustomDialog.start
  calCustomEnd.value = calCustomDialog.end
  calCustomDialog.show = false
}
function cancelCalCustom() {
  calCustomDialog.show = false
  // If user picked Custom but never confirmed a range, fall back to "This week".
  if (calRange.value === 'custom'
      && (!calCustomStart.value || !calCustomEnd.value)) {
    calRange.value = 'week'
  }
}

// Auto-open the dialog whenever the user switches to Custom.
watch(calRange, (val, prev) => {
  if (val === 'custom' && prev !== 'custom') openCalCustomDialog()
})

// Filtered caregivers list for the calendar tab.
const calCaregiversForDisplay = computed(() => {
  if (calCaregiverId.value) {
    const c = caregivers.value.find(x => x.id === calCaregiverId.value)
    return c ? [c] : []
  }
  return caregivers.value
})

// Per-caregiver row data: byDay { iso → shifts[] }, byDayMin, byDayPct, totals.
const calRowsForDisplay = computed(() => {
  const days = calDays.value
  if (!days.length) return []
  return calCaregiversForDisplay.value.map(c => {
    const byDay = {}, byDayMin = {}, byDayPct = {}
    let totalEngagedMin = 0
    days.forEach(d => { byDay[d.iso] = []; byDayMin[d.iso] = 0; byDayPct[d.iso] = 0 })
    shifts.value
      .filter(s => s.caregiver === c.id
                && s.status !== 'cancelled')
      .forEach(s => {
        const sd = splitDateTime(s.start_at).date
        if (!(sd in byDay)) return
        byDay[sd].push(s)
        const mins = Math.max(0,
          (new Date(s.end_at).getTime() - new Date(s.start_at).getTime()) / 60000)
        byDayMin[sd] += mins
        totalEngagedMin += mins
      })
    days.forEach(d => {
      byDay[d.iso].sort((a, b) => new Date(a.start_at) - new Date(b.start_at))
      byDayPct[d.iso] = Math.min(100,
        Math.round((byDayMin[d.iso] / CAL_DAY_CAPACITY_MIN) * 100))
    })
    const totalCapacityMin = days.length * CAL_DAY_CAPACITY_MIN
    const utilization = totalCapacityMin
      ? Math.min(100, Math.round((totalEngagedMin / totalCapacityMin) * 100))
      : 0
    return { caregiver: c, byDay, byDayMin, byDayPct, totalEngagedMin, utilization }
  })
})

const calStats = computed(() => {
  const rows = calRowsForDisplay.value
  const totalShifts = rows.reduce((acc, r) =>
    acc + Object.values(r.byDay).reduce((a, l) => a + l.length, 0), 0)
  const totalEngagedMin = rows.reduce((acc, r) => acc + r.totalEngagedMin, 0)
  const days = calDays.value.length
  const capacity = rows.length * days * CAL_DAY_CAPACITY_MIN
  const util = capacity ? Math.round((totalEngagedMin / capacity) * 100) : 0
  const freeMin = Math.max(0, capacity - totalEngagedMin)
  return [
    { label: 'Caregivers',      value: rows.length, icon: 'mdi-account-heart',  color: 'purple' },
    { label: 'Days in view',    value: days,        icon: 'mdi-calendar-range', color: 'indigo' },
    { label: 'Total shifts',    value: totalShifts, icon: 'mdi-clipboard-list', color: 'teal',
      sub: `${formatHours(totalEngagedMin)} engaged` },
    { label: 'Avg utilization', value: `${util}%`,  icon: 'mdi-chart-donut',    color: util > 80 ? 'error' : util > 50 ? 'warning' : 'success',
      sub: `${formatHours(freeMin)} free capacity` },
  ]
})

function formatHours(min) {
  const m = Math.max(0, Math.round(min || 0))
  const h = Math.floor(m / 60), r = m % 60
  if (!h && !r) return '0h'
  if (!h) return `${r}m`
  if (!r) return `${h}h`
  return `${h}h ${r}m`
}

function availColor(pct) {
  if (pct >= 90) return '#ef4444'
  if (pct >= 70) return '#f59e0b'
  if (pct >= 40) return '#6366f1'
  return '#10b981'
}

function openCalShift(s) {
  // Reuse the existing shift edit dialog from the sheets tab.
  openShiftDialog(s)
}

// Reload shifts whenever the calendar window changes so we always have data.
watch(calRangeBounds, () => loadShifts(), { deep: true })

// ═════════════════════════════════════════════════════════
//  PATIENT CALENDAR TAB
// ═════════════════════════════════════════════════════════
const patCalPatientId = ref(null)
const patCalRange = ref('week')
const patCalAnchor = ref(dateOffset(0))
const patCalCustomStart = ref(dateOffset(0))
const patCalCustomEnd = ref(dateOffset(6))
// 24h/day capacity for "covered %" — patients ideally have someone available all day.
const PAT_DAY_CAPACITY_MIN = 24 * 60

const patCalPatientOptions = computed(() =>
  patients.value.map(p => ({
    id: p.id,
    label: `${p.user?.full_name || p.user?.email}`
         + (p.medical_record_number ? ` · ${p.medical_record_number}` : ''),
  }))
)

const patCalRangeBounds = computed(() => {
  if (patCalRange.value === 'custom') {
    if (!patCalCustomStart.value || !patCalCustomEnd.value) return null
    const a = patCalCustomStart.value, b = patCalCustomEnd.value
    return a <= b ? { start: a, end: b } : { start: b, end: a }
  }
  const anchor = new Date(`${patCalAnchor.value}T00:00`)
  if (patCalRange.value === 'day') return { start: ymd(anchor), end: ymd(anchor) }
  if (patCalRange.value === 'week') {
    const dow = (anchor.getDay() + 6) % 7
    const start = new Date(anchor); start.setDate(start.getDate() - dow)
    const end = new Date(start);    end.setDate(end.getDate() + 6)
    return { start: ymd(start), end: ymd(end) }
  }
  if (patCalRange.value === 'month') {
    const start = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
    const end   = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 0)
    return { start: ymd(start), end: ymd(end) }
  }
  return null
})

const patCalDays = computed(() => {
  const b = patCalRangeBounds.value
  if (!b) return []
  const out = []
  const start = new Date(`${b.start}T00:00`)
  const end   = new Date(`${b.end}T00:00`)
  const today = ymd(new Date())
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  const dows   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    out.push({
      iso: ymd(d),
      dow: dows[d.getDay()],
      dayNum: d.getDate(),
      month: months[d.getMonth()],
      isToday: ymd(d) === today,
      isWeekend: d.getDay() === 0 || d.getDay() === 6,
    })
  }
  return out
})

const patCalRangeLabel = computed(() => {
  const b = patCalRangeBounds.value
  if (!b) return ''
  if (b.start === b.end) return formatDateShort(b.start)
  return `${formatDateShort(b.start)} – ${formatDateShort(b.end)}`
})

function patCalShiftRange(dir) {
  const map = { day: 1, week: 7, month: 30 }
  const step = map[patCalRange.value] || 7
  if (patCalRange.value === 'custom') {
    const s = new Date(`${patCalCustomStart.value}T00:00`)
    const e = new Date(`${patCalCustomEnd.value}T00:00`)
    const width = Math.round((e - s) / 86400000) + 1
    s.setDate(s.getDate() + dir * width)
    e.setDate(e.getDate() + dir * width)
    patCalCustomStart.value = ymd(s)
    patCalCustomEnd.value = ymd(e)
    return
  }
  if (patCalRange.value === 'month') {
    const a = new Date(`${patCalAnchor.value}T00:00`)
    a.setMonth(a.getMonth() + dir)
    patCalAnchor.value = ymd(a)
    return
  }
  const a = new Date(`${patCalAnchor.value}T00:00`)
  a.setDate(a.getDate() + dir * step)
  patCalAnchor.value = ymd(a)
}

function patCalGoToday() {
  patCalAnchor.value = dateOffset(0)
  if (patCalRange.value === 'custom') {
    patCalCustomStart.value = dateOffset(0)
    patCalCustomEnd.value = dateOffset(6)
  }
}

// Custom range dialog
const patCalCustomDialog = reactive({
  show: false, start: dateOffset(0), end: dateOffset(6), error: '',
})
const patCalCustomDialogDays = computed(() => {
  if (!patCalCustomDialog.start || !patCalCustomDialog.end) return 0
  const s = new Date(`${patCalCustomDialog.start}T00:00`)
  const e = new Date(`${patCalCustomDialog.end}T00:00`)
  return Math.max(0, Math.round((e - s) / 86400000) + 1)
})
const patCalCustomDialogValid = computed(() =>
  patCalCustomDialog.start && patCalCustomDialog.end
  && patCalCustomDialog.end >= patCalCustomDialog.start
)
function openPatCalCustomDialog() {
  patCalCustomDialog.start = patCalCustomStart.value || dateOffset(0)
  patCalCustomDialog.end = patCalCustomEnd.value || dateOffset(6)
  patCalCustomDialog.error = ''
  patCalCustomDialog.show = true
}
function applyPatCalCustomPreset(p) {
  patCalCustomDialog.start = dateOffset(p.start)
  patCalCustomDialog.end = dateOffset(p.end)
  patCalCustomDialog.error = ''
}
function applyPatCalCustom() {
  if (!patCalCustomDialogValid.value) {
    patCalCustomDialog.error = 'End date must be on or after the start date.'
    return
  }
  patCalCustomStart.value = patCalCustomDialog.start
  patCalCustomEnd.value = patCalCustomDialog.end
  patCalCustomDialog.show = false
}
function cancelPatCalCustom() {
  patCalCustomDialog.show = false
  if (patCalRange.value === 'custom'
      && (!patCalCustomStart.value || !patCalCustomEnd.value)) {
    patCalRange.value = 'week'
  }
}

watch(patCalRange, (val, prev) => {
  if (val === 'custom' && prev !== 'custom') openPatCalCustomDialog()
})

const patCalPatientsForDisplay = computed(() => {
  if (patCalPatientId.value) {
    const p = patients.value.find(x => x.id === patCalPatientId.value)
    return p ? [p] : []
  }
  return patients.value
})

const patCalRowsForDisplay = computed(() => {
  const days = patCalDays.value
  if (!days.length) return []
  return patCalPatientsForDisplay.value.map(p => {
    const byDay = {}, byDayMin = {}, byDayPct = {}
    let totalCareMin = 0
    const cgSet = new Set()
    days.forEach(d => { byDay[d.iso] = []; byDayMin[d.iso] = 0; byDayPct[d.iso] = 0 })
    shifts.value
      .filter(s => s.patient === p.id && s.status !== 'cancelled')
      .forEach(s => {
        const sd = splitDateTime(s.start_at).date
        if (!(sd in byDay)) return
        byDay[sd].push(s)
        const mins = Math.max(0,
          (new Date(s.end_at).getTime() - new Date(s.start_at).getTime()) / 60000)
        byDayMin[sd] += mins
        totalCareMin += mins
        if (s.caregiver) cgSet.add(s.caregiver)
      })
    days.forEach(d => {
      byDay[d.iso].sort((a, b) => new Date(a.start_at) - new Date(b.start_at))
      byDayPct[d.iso] = Math.min(100,
        Math.round((byDayMin[d.iso] / PAT_DAY_CAPACITY_MIN) * 100))
    })
    const totalCapacityMin = days.length * PAT_DAY_CAPACITY_MIN
    const coveragePct = totalCapacityMin
      ? Math.min(100, Math.round((totalCareMin / totalCapacityMin) * 100))
      : 0
    return {
      patient: p, byDay, byDayMin, byDayPct,
      totalCareMin, coveragePct, uniqueCaregivers: cgSet.size,
    }
  })
})

const patCalStats = computed(() => {
  const rows = patCalRowsForDisplay.value
  const totalShifts = rows.reduce((acc, r) =>
    acc + Object.values(r.byDay).reduce((a, l) => a + l.length, 0), 0)
  const totalCareMin = rows.reduce((acc, r) => acc + r.totalCareMin, 0)
  const days = patCalDays.value.length
  const capacity = rows.length * days * PAT_DAY_CAPACITY_MIN
  const coverage = capacity ? Math.round((totalCareMin / capacity) * 100) : 0
  const uncoveredDays = rows.reduce((acc, r) =>
    acc + Object.values(r.byDay).filter(l => l.length === 0).length, 0)
  return [
    { label: 'Patients',       value: rows.length, icon: 'mdi-account-multiple', color: 'purple' },
    { label: 'Days in view',   value: days,        icon: 'mdi-calendar-range',   color: 'indigo' },
    { label: 'Total visits',   value: totalShifts, icon: 'mdi-clipboard-list',   color: 'teal',
      sub: `${formatHours(totalCareMin)} of care` },
    { label: 'Avg coverage',   value: `${coverage}%`, icon: 'mdi-shield-check',
      color: coverage >= 50 ? 'success' : coverage >= 25 ? 'warning' : 'error',
      sub: `${uncoveredDays} uncovered day(s)` },
  ]
})

function coverageColor(pct) {
  if (pct >= 75) return '#10b981'
  if (pct >= 40) return '#6366f1'
  if (pct >= 15) return '#f59e0b'
  return '#ef4444'
}

watch(patCalRangeBounds, () => loadShifts(), { deep: true })

onMounted(async () => {
  await loadAll()
  await loadShifts()
})
</script>

<style scoped>
.hc-bg {
  min-height: calc(100vh - 64px);
  background: linear-gradient(135deg, rgba(124,58,237,0.05) 0%, rgba(13,148,136,0.05) 100%);
}
.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.06);
}
.hc-asn-hero {
  border-radius: 24px;
  background: linear-gradient(135deg, #6d28d9 0%, #7c3aed 60%, #a78bfa 100%);
  position: relative;
  overflow: hidden;
}
.hc-asn-hero::after {
  content: ''; position: absolute; right: -60px; top: -60px;
  width: 220px; height: 220px; border-radius: 50%;
  background: rgba(255,255,255,0.10);
}
.hc-cg-list {
  max-height: calc(100vh - 280px);
  overflow-y: auto;
}
.hc-cg-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px;
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.15s ease;
}
.hc-cg-item:hover { background: rgba(124,58,237,0.06); }
.hc-cg-item--active {
  background: linear-gradient(135deg, rgba(124,58,237,0.12), rgba(124,58,237,0.05));
  border: 1px solid rgba(124,58,237,0.25);
}
.hc-pa-card {
  background: rgba(255,255,255,0.6);
  border: 1px solid rgba(15,23,42,0.06);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.15s ease;
}
.hc-pa-card:hover {
  border-color: rgba(124,58,237,0.4);
  background: white;
}
.hc-pa-card--on {
  background: linear-gradient(135deg, rgba(124,58,237,0.10), rgba(124,58,237,0.04));
  border-color: rgba(124,58,237,0.5);
  box-shadow: 0 0 0 1px rgba(124,58,237,0.2);
}
:global(.v-theme--dark) .hc-pa-card { background: rgba(30,41,59,0.5); }

/* Sheet card */
.hc-sheet { transition: transform .15s ease, box-shadow .15s ease; }
.hc-sheet:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(15,23,42,0.08); }
.hc-status-line {
  background: rgba(15,23,42,0.04);
  font-size: .85rem;
}
:global(.v-theme--dark) .hc-status-line { background: rgba(255,255,255,0.05); }
.hc-shift-list { max-height: 220px; overflow-y: auto; }
.hc-shift-row {
  background: rgba(15,23,42,0.03);
  border: 1px solid rgba(15,23,42,0.06);
}
.hc-shift-row.hc-shift-day    { background: rgba(245,158,11,0.08); border-color: rgba(245,158,11,0.25); }
.hc-shift-row.hc-shift-night  { background: rgba(99,102,241,0.10); border-color: rgba(99,102,241,0.25); }
.hc-shift-row.hc-shift-livein { background: rgba(124,58,237,0.10); border-color: rgba(124,58,237,0.30); }
.hc-shift-row.hc-shift-oncall { background: rgba(59,130,246,0.10); border-color: rgba(59,130,246,0.25); }
:global(.v-theme--dark) .hc-shift-row { background: rgba(255,255,255,0.04); }

.hc-check-section {
  background: rgba(15,23,42,0.03);
  border: 1px solid rgba(15,23,42,0.08);
}
:global(.v-theme--dark) .hc-check-section {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.08);
}

/* ── Caregiver calendar ───────────────────────────────── */
.hc-cal-scroll {
  overflow-x: auto;
  overflow-y: hidden;
  max-width: 100%;
  -webkit-overflow-scrolling: touch;
}
.hc-cal {
  width: max-content;
  border-collapse: separate;
  border-spacing: 0;
  table-layout: fixed;
}
.hc-cal th, .hc-cal td {
  border-bottom: 1px solid rgba(15,23,42,0.08);
  border-right:  1px solid rgba(15,23,42,0.08);
  vertical-align: top;
  padding: 6px;
}
.hc-cal th {
  position: sticky; top: 0; z-index: 2;
  background: rgba(124,58,237,0.06);
  text-align: center;
  font-weight: 600;
}
.hc-cal-cg {
  width: 200px;
  min-width: 200px;
  position: sticky; left: 0; z-index: 3;
  background: var(--v-theme-surface, #fff);
}
.hc-cal-day { min-width: 130px; }
.hc-cal-cell { min-width: 130px; height: 110px; }
.hc-cal-today { background: rgba(124,58,237,0.08); }
.hc-cal-weekend { background: rgba(15,23,42,0.025); }
.hc-cell-shifts { display: flex; flex-direction: column; gap: 3px; }
.hc-cell-shift {
  border-radius: 6px;
  padding: 4px 6px;
  cursor: pointer;
  border: 1px solid rgba(15,23,42,0.06);
  background: rgba(15,23,42,0.03);
  transition: transform .12s ease, box-shadow .12s ease;
}
.hc-cell-shift:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(15,23,42,0.10);
}
.hc-cell-day    { background: rgba(245,158,11,0.10); border-color: rgba(245,158,11,0.30); }
.hc-cell-night  { background: rgba(99,102,241,0.12); border-color: rgba(99,102,241,0.30); }
.hc-cell-livein { background: rgba(124,58,237,0.12); border-color: rgba(124,58,237,0.32); }
.hc-cell-oncall { background: rgba(59,130,246,0.12); border-color: rgba(59,130,246,0.30); }
.hc-cell-empty {
  text-align: center;
  color: rgba(15,23,42,0.38);
  font-style: italic;
  padding: 6px 0;
}
.hc-availbar {
  width: 100%; height: 4px;
  background: rgba(15,23,42,0.08);
  border-radius: 2px; overflow: hidden;
}
.hc-availbar-fill { height: 100%; transition: width .25s ease; }
:global(.v-theme--dark) .hc-cal-cg { background: #1e1e1e; }
:global(.v-theme--dark) .hc-cal th { background: rgba(124,58,237,0.18); }
:global(.v-theme--dark) .hc-cal th, :global(.v-theme--dark) .hc-cal td {
  border-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark) .hc-cal-today { background: rgba(124,58,237,0.18); }
:global(.v-theme--dark) .hc-availbar { background: rgba(255,255,255,0.10); }

.hc-perday {
  background: rgba(124,58,237,0.04);
  border: 1px solid rgba(124,58,237,0.15);
}
:global(.v-theme--dark) .hc-perday {
  background: rgba(255,255,255,0.04);
  border-color: rgba(255,255,255,0.08);
}

.min-w-0 { min-width: 0; }
</style>
