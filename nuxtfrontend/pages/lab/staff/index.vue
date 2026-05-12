<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-account-group</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab staff</div>
        <div class="text-body-2 text-medium-emphasis">
          Manage technologists, schedules, specializations &amp; access
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="reloadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportStaffCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-account-plus"
             @click="openStaffDialog()">Add staff</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3"
                @click="k.tab && (tab = k.tab)" style="cursor: pointer">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="section-pills pa-2 my-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                filter variant="tonal" :color="s.color">
          <v-icon size="16" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- ────────── Team tab ────────── -->
    <template v-if="tab === 'team'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="4">
            <v-text-field v-model="staffSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search by name or email…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg" hide-details clearable
                          @update:model-value="debouncedLoadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterRole" :items="roleFilterItems" label="Role"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterBranch" :items="branchItems" item-title="name" item-value="id"
                      label="Branch" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterSpec" :items="specItems" item-title="name" item-value="id"
                      label="Specialization" variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterAvail" :items="availItems" label="Availability"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details
                      @update:model-value="loadStaff" />
          </v-col>
        </v-row>

        <v-row v-if="selectedStaff.length" dense align="center" class="mt-2">
          <v-col cols="auto" class="text-caption text-medium-emphasis">
            <strong>{{ selectedStaff.length }}</strong> selected
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check"
                   @click="bulkSetAvailability(true)">Set available</v-btn>
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="warning" prepend-icon="mdi-pause"
                   @click="bulkSetAvailability(false)">Set unavailable</v-btn>
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-delete"
                   @click="bulkDelete">Delete</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table-server
          v-model="selectedStaff" :headers="staffHeaders" :items="staff"
          :items-length="staffTotal" :loading="loading" item-value="id" show-select
          :items-per-page="staffPageSize" :page="staffPage"
          :items-per-page-options="[25, 50, 100, 200]"
          class="acct-table"
          @update:page="(p) => { staffPage = p; loadStaff() }"
          @update:items-per-page="(n) => { staffPageSize = n; staffPage = 1; loadStaff() }">

          <template #item.user_name="{ item }">
            <div class="d-flex align-center py-1">
              <v-avatar :color="avatarColor(item.user_name)" size="36" class="mr-3 text-white">
                <span class="text-caption font-weight-bold">{{ initials(item.user_name) }}</span>
              </v-avatar>
              <div class="min-width-0">
                <div class="font-weight-medium text-truncate">{{ item.user_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ item.user_email }}</div>
              </div>
            </div>
          </template>

          <template #item.user_role="{ item }">
            <v-chip size="small" :color="roleColor(item.user_role)" variant="tonal" class="font-weight-medium">
              <v-icon size="14" start>{{ roleIcon(item.user_role) }}</v-icon>
              {{ roleLabel(item.user_role) }}
            </v-chip>
          </template>

          <template #item.specialization_name="{ item }">
            <span v-if="item.specialization_name">{{ item.specialization_name }}</span>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.branch_name="{ item }">
            <span v-if="item.branch_name">{{ item.branch_name }}</span>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.license_number="{ item }">
            <span v-if="item.license_number" class="font-monospace text-caption">{{ item.license_number }}</span>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.years_of_experience="{ item }">
            <v-chip size="x-small" variant="outlined">{{ item.years_of_experience || 0 }} yr</v-chip>
          </template>

          <template #item.is_available="{ item }">
            <v-switch :model-value="item.is_available" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleAvailability(item, v)" />
          </template>

          <template #item.actions="{ item }">
            <v-btn icon size="small" variant="text" @click="openStaffDialog(item)">
              <v-icon size="20">mdi-pencil</v-icon>
              <v-tooltip activator="parent" location="top">Edit</v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" color="error" @click="confirmDelete(item)">
              <v-icon size="20">mdi-delete</v-icon>
              <v-tooltip activator="parent" location="top">Delete</v-tooltip>
            </v-btn>
          </template>

          <template #no-data>
            <div class="text-center pa-6 text-medium-emphasis">
              <v-icon size="48" color="grey-lighten-1">mdi-account-off</v-icon>
              <div class="mt-2">No staff members yet.</div>
              <v-btn class="mt-3" color="primary" rounded="lg" variant="text"
                     prepend-icon="mdi-account-plus" @click="openStaffDialog()">
                Add your first staff member
              </v-btn>
            </div>
          </template>
        </v-data-table-server>
      </v-card>
    </template>

    <!-- ────────── Specializations tab ────────── -->
    <template v-if="tab === 'specializations'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="specSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search specializations…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg" hide-details clearable
                          @update:model-value="loadSpecs" />
          </v-col>
          <v-spacer />
          <v-col cols="auto">
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
                   @click="openSpecDialog()">New specialization</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table :headers="specHeaders" :items="specs" :loading="loading"
                      item-value="id" class="acct-table">
          <template #item.is_active="{ item }">
            <v-switch :model-value="item.is_active" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleSpecActive(item, v)" />
          </template>
          <template #item.actions="{ item }">
            <v-btn icon size="small" variant="text" @click="openSpecDialog(item)">
              <v-icon size="20">mdi-pencil</v-icon>
            </v-btn>
            <v-btn icon size="small" variant="text" color="error" @click="deleteSpec(item)">
              <v-icon size="20">mdi-delete</v-icon>
            </v-btn>
          </template>
          <template #no-data>
            <div class="text-center pa-6 text-medium-emphasis">
              <v-icon size="48" color="grey-lighten-1">mdi-school-outline</v-icon>
              <div class="mt-2">No specializations defined.</div>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ────────── Schedule tab ────────── -->
    <template v-if="tab === 'schedule'">
      <v-card flat rounded="lg" class="pa-4 section-card">
        <div class="d-flex align-center flex-wrap ga-2 mb-3">
          <v-icon color="indigo-darken-2" class="mr-1">mdi-calendar-week</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Weekly schedule overview</div>
          <v-spacer />
          <v-chip size="small" variant="tonal" color="indigo">
            {{ scheduledCount }} of {{ allStaff.length }} staff scheduled
          </v-chip>
        </div>

        <v-row>
          <v-col v-for="d in weekdays" :key="d.key" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="schedule-day pa-3 h-100">
              <div class="d-flex align-center mb-2">
                <v-icon size="18" color="indigo-darken-2" class="mr-2">mdi-calendar</v-icon>
                <div class="font-weight-medium">{{ d.label }}</div>
                <v-spacer />
                <v-chip size="x-small" variant="tonal" color="indigo">
                  {{ scheduleByDay[d.key]?.length || 0 }}
                </v-chip>
              </div>
              <div v-if="(scheduleByDay[d.key] || []).length === 0"
                   class="text-caption text-disabled pa-2 text-center">
                No staff scheduled
              </div>
              <div v-for="entry in (scheduleByDay[d.key] || [])" :key="entry.id"
                   class="d-flex align-center pa-2 schedule-entry rounded mb-1">
                <v-avatar :color="avatarColor(entry.user_name)" size="28" class="mr-2 text-white">
                  <span class="text-caption">{{ initials(entry.user_name) }}</span>
                </v-avatar>
                <div class="flex-grow-1 text-body-2 min-width-0">
                  <div class="font-weight-medium text-truncate">{{ entry.user_name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">{{ entry.shift }}</div>
                </div>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ────────── Roster tab (compact directory) ────────── -->
    <template v-if="tab === 'roster'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="rosterSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Filter by name, role or specialization…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg" hide-details clearable />
          </v-col>
        </v-row>
      </v-card>

      <v-row dense>
        <v-col v-for="s in filteredRoster" :key="s.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="pa-3 section-card h-100">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="avatarColor(s.user_name)" size="40" class="mr-2 text-white">
                <span class="font-weight-bold">{{ initials(s.user_name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-truncate">{{ s.user_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ s.user_email }}</div>
              </div>
              <v-icon v-if="s.is_available" size="16" color="success">mdi-circle</v-icon>
              <v-icon v-else size="16" color="grey-lighten-1">mdi-circle-outline</v-icon>
            </div>
            <v-chip size="x-small" :color="roleColor(s.user_role)" variant="tonal" class="mb-2">
              <v-icon size="12" start>{{ roleIcon(s.user_role) }}</v-icon>{{ roleLabel(s.user_role) }}
            </v-chip>
            <div v-if="s.specialization_name" class="text-caption">
              <v-icon size="14" class="mr-1" color="indigo-darken-2">mdi-school</v-icon>
              {{ s.specialization_name }}
            </div>
            <div v-if="s.branch_name" class="text-caption">
              <v-icon size="14" class="mr-1" color="grey-darken-1">mdi-bank</v-icon>
              {{ s.branch_name }}
            </div>
            <div v-if="s.user_phone" class="text-caption">
              <v-icon size="14" class="mr-1" color="grey-darken-1">mdi-phone</v-icon>
              {{ s.user_phone }}
            </div>
            <v-divider class="my-2" />
            <div class="d-flex justify-end">
              <v-btn size="small" variant="text" prepend-icon="mdi-pencil"
                     @click="openStaffDialog(s)">Edit</v-btn>
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!filteredRoster.length" cols="12">
          <v-card flat rounded="lg" class="pa-12 text-center section-card">
            <v-icon size="56" color="grey-lighten-1">mdi-account-search</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No staff matched your filter</div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ────────── Staff dialog ────────── -->
    <v-dialog v-model="staffDialog" max-width="820" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="indigo-lighten-5" size="36">
            <v-icon color="indigo-darken-2" size="20">
              {{ editingStaff ? 'mdi-account-edit' : 'mdi-account-plus' }}
            </v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Lab staff</div>
            <div class="text-h6 font-weight-bold">
              {{ editingStaff ? 'Edit staff member' : 'New staff member' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon size="small" variant="text" @click="staffDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.first_name" label="First name *"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.last_name" label="Last name *"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.email" label="Email *" type="email"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.phone" label="Phone"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="staffForm.role" :items="roleSelectItems" label="Role *"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-autocomplete v-model="staffForm.specialization_name" :items="labSpecOptions"
                              label="Specialization" placeholder="Pick or type to add a new one…"
                              variant="outlined" density="compact" rounded="lg"
                              persistent-placeholder hide-details clearable
                              :menu-props="{ maxHeight: 320 }">
                <template #prepend-inner>
                  <v-icon size="18" color="indigo-darken-2">mdi-school</v-icon>
                </template>
                <template #no-data>
                  <div class="px-3 py-2 text-caption text-medium-emphasis">
                    Type a name and press Enter to use a custom specialization.
                  </div>
                </template>
              </v-autocomplete>
            </v-col>
            <v-col v-if="!editingStaff" cols="12" md="6">
              <v-text-field v-model="staffForm.password" :type="showPassword ? 'text' : 'password'"
                            label="Password *" variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details
                            :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                            @click:append-inner="showPassword = !showPassword" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="staffForm.branch_id" :items="branchItems"
                        item-title="name" item-value="id" label="Branch"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details clearable />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.license_number" label="License number"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-combobox v-model="staffForm.qualification" :items="qualificationOptions"
                          label="Qualification" placeholder="Pick a common one or type your own…"
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details clearable
                          :menu-props="{ maxHeight: 320 }">
                <template #prepend-inner>
                  <v-icon size="18" color="indigo-darken-2">mdi-certificate</v-icon>
                </template>
              </v-combobox>
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="staffForm.years_of_experience" type="number" min="0"
                            label="Years exp." variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="6" md="3" class="d-flex align-center">
              <v-switch v-model="staffForm.is_available" color="success" inset
                        label="Available" hide-details density="compact" />
            </v-col>

            <v-col v-if="editingStaff" cols="12">
              <v-divider class="my-2" />
              <v-card flat rounded="lg" class="pa-3 notes-card">
                <div class="d-flex align-center mb-2">
                  <v-icon size="20" color="warning-darken-2" class="mr-2">mdi-key-variant</v-icon>
                  <div class="text-subtitle-2 font-weight-bold">Login credentials</div>
                  <v-spacer />
                  <v-switch v-model="staffForm.is_user_active" color="success" inset hide-details
                            density="compact" class="mt-0"
                            :label="staffForm.is_user_active ? 'Account enabled' : 'Account disabled'" />
                </div>
                <div class="text-caption text-medium-emphasis mb-3">
                  Change the staff member's email or set a new password. Leave the password
                  empty to keep the current one.
                </div>
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="staffForm.new_password"
                                  :type="showNewPassword ? 'text' : 'password'"
                                  label="New password" placeholder="Leave blank to keep current"
                                  variant="outlined" density="compact" rounded="lg"
                                  persistent-placeholder hide-details
                                  :append-inner-icon="showNewPassword ? 'mdi-eye-off' : 'mdi-eye'"
                                  @click:append-inner="showNewPassword = !showNewPassword" />
                  </v-col>
                  <v-col cols="12" md="6" class="d-flex align-center">
                    <v-btn variant="tonal" rounded="lg" color="indigo" prepend-icon="mdi-lock-reset"
                           @click="generatePassword">Generate strong password</v-btn>
                    <v-btn v-if="staffForm.new_password" class="ml-2" icon size="small" variant="text"
                           @click="copyPassword">
                      <v-icon size="20">mdi-content-copy</v-icon>
                      <v-tooltip activator="parent" location="top">Copy to clipboard</v-tooltip>
                    </v-btn>
                  </v-col>
                </v-row>
              </v-card>
            </v-col>

            <v-col cols="12">
              <v-divider class="my-2" />
              <div class="d-flex align-center flex-wrap ga-2 mb-2">
                <v-icon size="18" color="indigo-darken-2">mdi-calendar-week</v-icon>
                <div class="text-subtitle-2 font-weight-bold">Weekly schedule</div>
                <v-spacer />
                <v-menu>
                  <template #activator="{ props }">
                    <v-btn v-bind="props" size="small" variant="tonal" rounded="lg"
                           prepend-icon="mdi-lightning-bolt" color="indigo">Quick fill</v-btn>
                  </template>
                  <v-list density="compact">
                    <v-list-item v-for="p in schedulePresets" :key="p.label"
                                 @click="applySchedulePreset(p)">
                      <template #prepend>
                        <v-icon size="18" :color="p.color">{{ p.icon }}</v-icon>
                      </template>
                      <v-list-item-title>{{ p.label }}</v-list-item-title>
                      <v-list-item-subtitle class="text-caption">{{ p.summary }}</v-list-item-subtitle>
                    </v-list-item>
                  </v-list>
                </v-menu>
                <v-btn size="small" variant="text" prepend-icon="mdi-close-circle-outline"
                       @click="clearSchedule">Clear all</v-btn>
              </div>
              <v-card flat rounded="lg" class="section-card pa-2">
                <div v-for="d in weekdays" :key="d.key" class="schedule-row">
                  <div class="d-flex align-center ga-2 py-2 px-2 flex-wrap">
                    <div class="day-label font-weight-medium">{{ d.label }}</div>
                    <v-switch :model-value="!scheduleState[d.key].off"
                              color="success" inset hide-details density="compact"
                              class="mt-0 flex-grow-0"
                              :label="scheduleState[d.key].off ? 'Off' : 'Working'"
                              @update:model-value="(v) => toggleDayOff(d.key, !v)" />
                    <v-spacer />
                    <template v-if="!scheduleState[d.key].off">
                      <v-text-field v-model="scheduleState[d.key].start" type="time" label="Start"
                                    variant="outlined" density="compact" rounded="lg"
                                    hide-details persistent-placeholder
                                    style="max-width: 130px" />
                      <v-icon color="grey-darken-1">mdi-arrow-right</v-icon>
                      <v-text-field v-model="scheduleState[d.key].end" type="time" label="End"
                                    variant="outlined" density="compact" rounded="lg"
                                    hide-details persistent-placeholder
                                    style="max-width: 130px" />
                      <v-btn icon="mdi-content-copy" size="x-small" variant="text"
                             @click="copyDayToAll(d.key)">
                        <v-icon size="18">mdi-content-copy</v-icon>
                        <v-tooltip activator="parent" location="top">Copy to all working days</v-tooltip>
                      </v-btn>
                    </template>
                    <span v-else class="text-caption text-medium-emphasis">Day off</span>
                  </div>
                  <v-divider />
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="staffDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="saving" @click="saveStaff">
            {{ editingStaff ? 'Save changes' : 'Create staff' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ────────── Specialization dialog ────────── -->
    <v-dialog v-model="specDialog" max-width="540" persistent>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="purple-lighten-5" size="36">
            <v-icon color="purple-darken-2" size="20">mdi-school</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Specialization</div>
            <div class="text-h6 font-weight-bold">
              {{ editingSpec ? 'Edit specialization' : 'New specialization' }}
            </div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="specForm.name" label="Name *"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details class="mb-3" />
          <v-textarea v-model="specForm.description" label="Description" rows="3"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details class="mb-3" />
          <v-switch v-model="specForm.is_active" color="success" inset
                    label="Active" hide-details density="compact" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="specDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="saving" @click="saveSpec">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ────────── Confirm delete dialog ────────── -->
    <v-dialog v-model="confirmDialog" max-width="460" persistent>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="red-lighten-5" size="36">
            <v-icon color="red-darken-2" size="20">mdi-alert-circle</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Confirm delete</div>
            <div class="text-h6 font-weight-bold">Remove staff member</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          Permanently delete <strong>{{ pendingDelete?.user_name }}</strong>?
          This cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="confirmDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" prepend-icon="mdi-delete"
                 @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()
const route = useRoute()

// ─────────────── State ───────────────
const validTabs = ['team', 'specializations', 'schedule', 'roster']
const tab = ref(validTabs.includes(route.query.tab) ? route.query.tab : 'team')
const loading = ref(false)
const saving = ref(false)
const showPassword = ref(false)
const showNewPassword = ref(false)

const staff = ref([])
const allStaff = ref([])
const staffTotal = ref(0)
const staffPage = ref(1)
const staffPageSize = ref(50)
const selectedStaff = ref([])

const specs = ref([])
const branches = ref([])

const staffSearch = ref('')
const specSearch = ref('')
const rosterSearch = ref('')
const filterRole = ref(null)
const filterBranch = ref(null)
const filterSpec = ref(null)
const filterAvail = ref('all')

const staffDialog = ref(false)
const editingStaff = ref(null)
const staffForm = ref(blankStaff())

const specDialog = ref(false)
const editingSpec = ref(null)
const specForm = ref({ name: '', description: '', is_active: true })

const confirmDialog = ref(false)
const pendingDelete = ref(null)

const snack = reactive({ show: false, color: 'success', message: '' })

// ─────────────── Roles ───────────────
const ROLE_LABELS = {
  lab_tech: 'Lab Tech',
  radiologist: 'Radiologist',
  receptionist: 'Receptionist',
  cashier: 'Cashier',
  doctor: 'Doctor',
  clinical_officer: 'Clinical Officer',
  nurse: 'Nurse',
}
const ROLE_COLORS = {
  lab_tech: 'indigo',
  radiologist: 'deep-purple',
  receptionist: 'teal',
  cashier: 'amber-darken-2',
  doctor: 'blue-darken-2',
  clinical_officer: 'cyan-darken-2',
  nurse: 'pink-darken-1',
}
const ROLE_ICONS = {
  lab_tech: 'mdi-test-tube',
  radiologist: 'mdi-radioactive',
  receptionist: 'mdi-face-agent',
  cashier: 'mdi-cash-register',
  doctor: 'mdi-stethoscope',
  clinical_officer: 'mdi-medical-bag',
  nurse: 'mdi-account-heart',
}
const roleSelectItems = Object.entries(ROLE_LABELS).map(([value, title]) => ({ value, title }))
const roleFilterItems = [{ value: null, title: 'All roles' }, ...roleSelectItems]
const availItems = [
  { value: 'all', title: 'All' },
  { value: 'true', title: 'Available' },
  { value: 'false', title: 'Unavailable' },
]

const weekdays = [
  { key: 'mon', label: 'Monday' },
  { key: 'tue', label: 'Tuesday' },
  { key: 'wed', label: 'Wednesday' },
  { key: 'thu', label: 'Thursday' },
  { key: 'fri', label: 'Friday' },
  { key: 'sat', label: 'Saturday' },
  { key: 'sun', label: 'Sunday' },
]

// Curated lab-specific specializations (used in addition to any matching
// records returned by the backend). Selecting one that does not yet exist on
// the server will create it on save.
const LAB_SPECIALIZATIONS = [
  'Clinical Chemistry',
  'Hematology',
  'Histopathology',
  'Cytopathology',
  'Microbiology',
  'Mycology',
  'Parasitology',
  'Virology',
  'Immunology / Serology',
  'Molecular Biology / PCR',
  'Blood Bank / Transfusion Medicine',
  'Endocrinology',
  'Toxicology',
  'Urinalysis',
  'Phlebotomy',
  'Cytogenetics',
  'Flow Cytometry',
  'Radiology — General',
  'Radiology — CT',
  'Radiology — MRI',
  'Radiology — Ultrasound',
  'Radiology — X-Ray',
  'Radiology — Mammography',
  'Nuclear Medicine',
  'Quality Control',
  'Lab Reception',
  'Sample Accessioning',
  'General Lab',
]

const QUALIFICATION_OPTIONS = [
  'Certificate in Medical Laboratory Sciences',
  'Diploma in Medical Laboratory Sciences',
  'Higher Diploma in Medical Laboratory Sciences',
  'BSc Medical Laboratory Sciences',
  'BSc Biomedical Sciences',
  'BSc Biotechnology',
  'MSc Medical Laboratory Sciences',
  'MSc Clinical Chemistry',
  'MSc Microbiology',
  'MSc Hematology',
  'MBChB',
  'MD',
  'MMed Pathology',
  'MMed Radiology',
  'Diploma in Radiography',
  'BSc Radiography',
  'Diploma in Nursing',
  'BSc Nursing',
  'Certificate in Phlebotomy',
  'Other',
]

const schedulePresets = [
  { label: 'Full week (08:00 – 17:00)', summary: 'Mon–Sun working',
    icon: 'mdi-calendar-check', color: 'success',
    days: ['mon','tue','wed','thu','fri','sat','sun'], start: '08:00', end: '17:00' },
  { label: 'Weekdays (08:00 – 17:00)', summary: 'Mon–Fri working, weekends off',
    icon: 'mdi-briefcase', color: 'indigo',
    days: ['mon','tue','wed','thu','fri'], start: '08:00', end: '17:00' },
  { label: 'Weekdays half-day (08:00 – 13:00)', summary: 'Mon–Fri morning only',
    icon: 'mdi-weather-sunny', color: 'amber-darken-2',
    days: ['mon','tue','wed','thu','fri'], start: '08:00', end: '13:00' },
  { label: 'Day shift (07:00 – 19:00)', summary: 'Mon–Sat 12-hour day',
    icon: 'mdi-white-balance-sunny', color: 'orange',
    days: ['mon','tue','wed','thu','fri','sat'], start: '07:00', end: '19:00' },
  { label: 'Night shift (19:00 – 07:00)', summary: 'Mon–Sat overnight',
    icon: 'mdi-weather-night', color: 'deep-purple',
    days: ['mon','tue','wed','thu','fri','sat'], start: '19:00', end: '07:00' },
  { label: 'Weekends only (08:00 – 17:00)', summary: 'Sat–Sun working',
    icon: 'mdi-calendar-weekend', color: 'teal',
    days: ['sat','sun'], start: '08:00', end: '17:00' },
]

const sectionPills = [
  { value: 'team',            label: 'Team',            color: 'indigo',      icon: 'mdi-account-group' },
  { value: 'roster',          label: 'Roster',          color: 'teal',        icon: 'mdi-card-account-details' },
  { value: 'specializations', label: 'Specializations', color: 'purple',      icon: 'mdi-school' },
  { value: 'schedule',        label: 'Weekly schedule', color: 'deep-purple', icon: 'mdi-calendar-week' },
]

const staffHeaders = [
  { title: 'Staff', key: 'user_name', sortable: true },
  { title: 'Role', key: 'user_role', sortable: true, width: 160 },
  { title: 'Specialization', key: 'specialization_name', width: 180 },
  { title: 'Branch', key: 'branch_name', width: 160 },
  { title: 'License', key: 'license_number', width: 140 },
  { title: 'Exp.', key: 'years_of_experience', width: 90, align: 'center' },
  { title: 'Available', key: 'is_available', width: 110, sortable: false },
  { title: '', key: 'actions', width: 110, sortable: false, align: 'end' },
]
const specHeaders = [
  { title: 'Name', key: 'name', sortable: true },
  { title: 'Description', key: 'description' },
  { title: 'Active', key: 'is_active', width: 110, sortable: false },
  { title: '', key: 'actions', width: 110, sortable: false, align: 'end' },
]

// ─────────────── Computeds ───────────────
const branchItems = computed(() => branches.value.map(b => ({ id: b.id, name: b.name })))
const specItems = computed(() => specs.value.map(s => ({ id: s.id, name: s.name })))

// Lab-relevant specializations: the curated list, plus any backend specs that
// match lab-related keywords (so legacy/admin-created entries also appear).
const LAB_KEYWORDS = /\b(lab|laborator|hemat|chemistr|microb|mycolog|parasit|virol|histopath|cytopath|immunolog|serolog|molecular|pcr|blood\s*bank|transfusion|endocrin|toxicolog|urinaly|phlebot|cytogenet|flow\s*cytometr|radiolog|imaging|ct|mri|ultrasound|x-?ray|mammograph|nuclear|quality\s*control|accession)/i
const labSpecOptions = computed(() => {
  const set = new Set(LAB_SPECIALIZATIONS)
  for (const s of specs.value) {
    if (s?.name && LAB_KEYWORDS.test(s.name)) set.add(s.name)
  }
  return [...set].sort((a, b) => a.localeCompare(b))
})
const qualificationOptions = QUALIFICATION_OPTIONS

// Per-day schedule editor state. Mirrors `staffForm.schedule` but as structured
// objects so the UI can use time pickers + an Off toggle.
const scheduleState = reactive(blankScheduleState())
function blankScheduleState() {
  const obj = {}
  for (const d of ['mon','tue','wed','thu','fri','sat','sun']) {
    obj[d] = { off: true, start: '08:00', end: '17:00' }
  }
  return obj
}
function parseScheduleString(raw) {
  const s = (raw ?? '').toString().trim()
  if (!s || /^off$/i.test(s)) return { off: true, start: '08:00', end: '17:00' }
  const m = s.match(/(\d{1,2}:\d{2})\s*(?:–|-|to)\s*(\d{1,2}:\d{2})/i)
  if (m) return { off: false, start: pad(m[1]), end: pad(m[2]) }
  return { off: false, start: '08:00', end: '17:00' }
}
function pad(t) {
  const [h, m] = t.split(':')
  return `${String(h).padStart(2, '0')}:${m}`
}
function loadScheduleFromForm(map) {
  const src = map || {}
  for (const d of weekdays) {
    Object.assign(scheduleState[d.key], parseScheduleString(src[d.key]))
  }
}
function serializeSchedule() {
  const out = {}
  for (const d of weekdays) {
    const s = scheduleState[d.key]
    out[d.key] = s.off ? 'Off' : `${s.start} – ${s.end}`
  }
  return out
}
function toggleDayOff(key, off) {
  scheduleState[key].off = !!off
  if (!off && (!scheduleState[key].start || !scheduleState[key].end)) {
    scheduleState[key].start = '08:00'
    scheduleState[key].end = '17:00'
  }
}
function copyDayToAll(srcKey) {
  const src = scheduleState[srcKey]
  for (const d of weekdays) {
    if (d.key === srcKey || scheduleState[d.key].off) continue
    scheduleState[d.key].start = src.start
    scheduleState[d.key].end = src.end
  }
  notify(`Copied ${src.start} – ${src.end} to all working days`, 'info')
}
function applySchedulePreset(p) {
  const days = new Set(p.days)
  for (const d of weekdays) {
    if (days.has(d.key)) {
      scheduleState[d.key].off = false
      scheduleState[d.key].start = p.start
      scheduleState[d.key].end = p.end
    } else {
      scheduleState[d.key].off = true
    }
  }
  notify(`Applied: ${p.label}`, 'info')
}
function clearSchedule() {
  for (const d of weekdays) {
    scheduleState[d.key].off = true
  }
}

const kpiTiles = computed(() => {
  const counts = roleCounts(allStaff.value)
  const available = allStaff.value.filter(s => s.is_available).length
  return [
    { tab: 'team', label: 'Total staff', value: allStaff.value.length, sub: `${available} available`,
      icon: 'mdi-account-group', color: 'indigo' },
    { tab: 'team', label: 'Lab techs', value: counts.lab_tech || 0,
      icon: 'mdi-test-tube', color: 'blue' },
    { tab: 'team', label: 'Radiologists', value: counts.radiologist || 0,
      icon: 'mdi-radioactive', color: 'deep-purple' },
    { tab: 'specializations', label: 'Specializations', value: specs.value.length,
      sub: `${specs.value.filter(s => s.is_active).length} active`,
      icon: 'mdi-school', color: 'green' },
  ]
})

const scheduleByDay = computed(() => {
  const map = {}
  weekdays.forEach(d => { map[d.key] = [] })
  for (const s of allStaff.value) {
    const sch = s.schedule || {}
    for (const d of weekdays) {
      const v = (sch[d.key] || '').toString().trim()
      if (v && v.toLowerCase() !== 'off') {
        map[d.key].push({ id: `${s.id}-${d.key}`, user_name: s.user_name, shift: v })
      }
    }
  }
  return map
})

const scheduledCount = computed(() =>
  allStaff.value.filter(s => Object.values(s.schedule || {})
    .some(v => v && String(v).trim() && String(v).toLowerCase() !== 'off')).length
)

const filteredRoster = computed(() => {
  const q = (rosterSearch.value || '').toLowerCase().trim()
  if (!q) return allStaff.value
  return allStaff.value.filter(s => {
    const hay = [
      s.user_name, s.user_email, s.user_role, s.specialization_name,
      s.branch_name, s.license_number, s.qualification,
    ].filter(Boolean).join(' ').toLowerCase()
    return hay.includes(q)
  })
})

// ─────────────── Helpers ───────────────
function blankStaff() {
  return {
    email: '', first_name: '', last_name: '', phone: '',
    role: 'lab_tech', password: '',
    new_password: '', is_user_active: true,
    specialization: null, specialization_name: '',
    branch_id: null,
    license_number: '', qualification: '', years_of_experience: 0,
    is_available: true,
    schedule: {},
  }
}
function initials(name) {
  if (!name) return '?'
  return name.trim().split(/\s+/).slice(0, 2).map(p => p[0]).join('').toUpperCase()
}
function avatarColor(name) {
  const palette = ['indigo', 'teal', 'deep-purple', 'pink', 'cyan', 'orange', 'green', 'blue-grey', 'red']
  if (!name) return 'grey'
  let h = 0
  for (const c of name) h = (h * 31 + c.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function roleLabel(r) { return ROLE_LABELS[r] || r || '—' }
function roleColor(r) { return ROLE_COLORS[r] || 'grey' }
function roleIcon(r) { return ROLE_ICONS[r] || 'mdi-account' }
function roleCounts(list) {
  const c = {}
  for (const s of list) {
    const r = s.user_role
    if (!r) continue
    c[r] = (c[r] || 0) + 1
  }
  return c
}
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

function generatePassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lower = 'abcdefghjkmnpqrstuvwxyz'
  const digits = '23456789'
  const symbols = '!@#$%&*?'
  const all = upper + lower + digits + symbols
  const pick = s => s[Math.floor(Math.random() * s.length)]
  let pw = pick(upper) + pick(lower) + pick(digits) + pick(symbols)
  for (let i = 0; i < 8; i++) pw += pick(all)
  pw = pw.split('').sort(() => Math.random() - 0.5).join('')
  staffForm.value.new_password = pw
  showNewPassword.value = true
  notify('Strong password generated', 'info')
}

async function copyPassword() {
  try {
    await navigator.clipboard.writeText(staffForm.value.new_password)
    notify('Password copied to clipboard', 'info')
  } catch { notify('Copy failed — select and copy manually', 'warning') }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join('; ')
}

let debTimer = null
function debouncedLoadStaff() {
  clearTimeout(debTimer)
  debTimer = setTimeout(() => { staffPage.value = 1; loadStaff() }, 350)
}

// ─────────────── Loaders ───────────────
async function loadStaff() {
  loading.value = true
  try {
    const params = { page: staffPage.value, page_size: staffPageSize.value }
    if (staffSearch.value) params.search = staffSearch.value
    if (filterRole.value) params.user__role = filterRole.value
    if (filterBranch.value) params.branch = filterBranch.value
    if (filterSpec.value) params.specialization = filterSpec.value
    if (filterAvail.value !== 'all') params.is_available = filterAvail.value
    const { data } = await $api.get('/staff/', { params })
    if (data?.results) { staff.value = data.results; staffTotal.value = data.count ?? data.results.length }
    else { staff.value = Array.isArray(data) ? data : []; staffTotal.value = staff.value.length }
  } catch (e) {
    notify(extractError(e) || 'Failed to load staff', 'error')
    staff.value = []; staffTotal.value = 0
  } finally { loading.value = false }
}

async function loadAllStaff() {
  try {
    const { data } = await $api.get('/staff/', { params: { page_size: 1000 } })
    allStaff.value = data?.results || (Array.isArray(data) ? data : [])
  } catch { allStaff.value = [] }
}

async function loadSpecs() {
  loading.value = true
  try {
    const params = {}
    if (specSearch.value) params.search = specSearch.value
    const { data } = await $api.get('/staff/specializations/', { params })
    specs.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load specializations', 'error')
    specs.value = []
  } finally { loading.value = false }
}

async function loadBranches() {
  try {
    const { data } = await $api.get('/pharmacy-profile/branches/', { params: { page_size: 200 } })
    branches.value = data?.results || (Array.isArray(data) ? data : [])
  } catch { branches.value = [] }
}

async function reloadAll() {
  await Promise.all([loadStaff(), loadAllStaff(), loadSpecs(), loadBranches()])
}

// ─────────────── Staff CRUD ───────────────
function openStaffDialog(item = null) {
  editingStaff.value = item
  if (item) {
    staffForm.value = {
      email: item.user_email || '',
      first_name: (item.user_name || '').split(' ')[0] || '',
      last_name: (item.user_name || '').split(' ').slice(1).join(' ') || '',
      phone: item.user_phone || '',
      role: item.user_role || 'lab_tech',
      password: '',
      new_password: '',
      is_user_active: item.is_user_active ?? true,
      specialization: item.specialization || null,
      specialization_name: item.specialization_name || '',
      branch_id: item.branch || null,
      license_number: item.license_number || '',
      qualification: item.qualification || '',
      years_of_experience: item.years_of_experience || 0,
      is_available: item.is_available ?? true,
      schedule: { ...(item.schedule || {}) },
    }
  } else {
    staffForm.value = blankStaff()
  }
  loadScheduleFromForm(staffForm.value.schedule)
  showNewPassword.value = false
  staffDialog.value = true
}

async function saveStaff() {
  saving.value = true
  try {
    const f = staffForm.value
    // Resolve specialization name to an id (create on the fly if needed).
    let specId = null
    const wantedName = (f.specialization_name || '').trim()
    if (wantedName) {
      const existing = specs.value.find(
        s => (s.name || '').toLowerCase() === wantedName.toLowerCase()
      )
      if (existing) {
        specId = existing.id
      } else {
        try {
          const { data } = await $api.post('/staff/specializations/',
            { name: wantedName, description: '', is_active: true })
          specs.value.push(data)
          specId = data.id
        } catch (e) {
          notify(extractError(e) || 'Failed to create specialization', 'warning')
        }
      }
    }
    const base = {
      first_name: f.first_name, last_name: f.last_name, email: f.email,
      phone: f.phone, role: f.role,
      specialization: specId,
      branch_id: f.branch_id || null,
      license_number: f.license_number,
      qualification: f.qualification,
      years_of_experience: f.years_of_experience || 0,
      is_available: f.is_available,
      schedule: serializeSchedule(),
    }
    if (editingStaff.value) {
      const payload = { ...base, is_user_active: f.is_user_active }
      if (f.new_password) payload.password = f.new_password
      await $api.patch(`/staff/${editingStaff.value.id}/`, payload)
      notify('Staff updated', 'success')
    } else {
      await $api.post('/staff/', { ...base, password: f.password })
      notify('Staff created', 'success')
    }
    staffDialog.value = false
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) {
    notify(extractError(e) || 'Failed to save staff', 'error')
  } finally { saving.value = false }
}

async function toggleAvailability(item, val) {
  try {
    await $api.patch(`/staff/${item.id}/`, { is_available: val })
    item.is_available = val
    notify(val ? 'Marked available' : 'Marked unavailable', 'info')
    loadAllStaff()
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}

function confirmDelete(item) { pendingDelete.value = item; confirmDialog.value = true }
async function performDelete() {
  if (!pendingDelete.value) return
  try {
    await $api.delete(`/staff/${pendingDelete.value.id}/`)
    notify('Staff deleted', 'success')
    confirmDialog.value = false
    pendingDelete.value = null
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
}

async function bulkSetAvailability(val) {
  try {
    await Promise.all(selectedStaff.value.map(id =>
      $api.patch(`/staff/${id}/`, { is_available: val })
    ))
    notify(`Updated ${selectedStaff.value.length} staff`, 'success')
    selectedStaff.value = []
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) { notify(extractError(e) || 'Bulk update failed', 'error') }
}

async function bulkDelete() {
  if (!confirm(`Delete ${selectedStaff.value.length} staff member(s)? This cannot be undone.`)) return
  try {
    await Promise.all(selectedStaff.value.map(id => $api.delete(`/staff/${id}/`)))
    notify(`Deleted ${selectedStaff.value.length} staff`, 'success')
    selectedStaff.value = []
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) { notify(extractError(e) || 'Bulk delete failed', 'error') }
}

// ─────────────── Specialization CRUD ───────────────
function openSpecDialog(item = null) {
  editingSpec.value = item
  specForm.value = item
    ? { name: item.name, description: item.description || '', is_active: item.is_active }
    : { name: '', description: '', is_active: true }
  specDialog.value = true
}

async function saveSpec() {
  saving.value = true
  try {
    if (editingSpec.value) {
      await $api.patch(`/staff/specializations/${editingSpec.value.id}/`, specForm.value)
      notify('Specialization updated', 'success')
    } else {
      await $api.post('/staff/specializations/', specForm.value)
      notify('Specialization created', 'success')
    }
    specDialog.value = false
    await loadSpecs()
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}

async function toggleSpecActive(item, val) {
  try {
    await $api.patch(`/staff/specializations/${item.id}/`, { is_active: val })
    item.is_active = val
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}

async function deleteSpec(item) {
  if (!confirm(`Delete specialization "${item.name}"?`)) return
  try {
    await $api.delete(`/staff/specializations/${item.id}/`)
    notify('Specialization deleted', 'success')
    await loadSpecs()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
}

// ─────────────── Export ───────────────
function exportStaffCsv() {
  const rows = allStaff.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const headers = [
    'Name', 'Email', 'Phone', 'Role', 'Specialization', 'Branch',
    'License', 'Qualification', 'Years exp.', 'Available', 'Account active',
  ]
  const csvRows = [headers.join(',')]
  for (const r of rows) {
    const cells = [
      r.user_name, r.user_email, r.user_phone, roleLabel(r.user_role),
      r.specialization_name || '', r.branch_name || '',
      r.license_number || '', r.qualification || '',
      r.years_of_experience || 0,
      r.is_available ? 'Yes' : 'No',
      r.is_user_active ? 'Yes' : 'No',
    ].map(v => `"${String(v ?? '').replace(/"/g, '""')}"`)
    csvRows.push(cells.join(','))
  }
  const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-staff-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

// ─────────────── Init ───────────────
onMounted(() => { reloadAll() })
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: all 120ms ease;
}
.kpi:hover {
  border-color: rgba(var(--v-theme-primary), 0.4);
  transform: translateY(-1px);
}
.section-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-pills {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.schedule-day {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.schedule-entry {
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.acct-table :deep(tbody tr:hover) {
  background: #eef2ff !important;
}
.schedule-row:last-child :deep(.v-divider) { display: none; }
.schedule-row .day-label { width: 96px; }
@media (max-width: 600px) {
  .schedule-row .day-label { width: 100%; }
}
</style>
