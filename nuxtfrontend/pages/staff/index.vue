<template>
  <v-container fluid class="pa-4 pa-md-6 staff-module">
    <!-- ───────────────────────── Hero band ───────────────────────── -->
    <v-card flat rounded="xl" class="hero-band text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <div class="hero-icon-wrap mr-4">
              <v-icon :color="isInventory ? 'teal-darken-2' : 'indigo-darken-2'" size="32">
                {{ isInventory ? 'mdi-warehouse' : 'mdi-badge-account-horizontal' }}
              </v-icon>
            </div>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">{{ pageTitle }}</div>
              <div class="text-body-2" style="opacity:.9">Manage team members, specializations &amp; schedules</div>
              <div class="d-flex flex-wrap ga-2 mt-2">
                <v-chip size="small" class="hero-chip" prepend-icon="mdi-account-multiple">
                  {{ allStaff.length }} members
                </v-chip>
                <v-chip size="small" class="hero-chip" prepend-icon="mdi-check-circle">
                  {{ availableCount }} available
                </v-chip>
                <v-chip size="small" class="hero-chip" prepend-icon="mdi-calendar-check">
                  {{ scheduledCount }} scheduled
                </v-chip>
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end align-center mt-4 mt-md-0">
          <v-btn color="primary" prepend-icon="mdi-account-plus" class="text-none mr-2"
                 @click="openStaffDialog()">
            {{ $t('staff.addStaff') }}
          </v-btn>
          <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" :loading="loading"
                 @click="reloadAll">{{ $t('common.refresh') }}</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- ─────────────────────── KPI Cards ─────────────────────── -->
    <v-row dense class="mb-4">
      <v-col v-for="(k, i) in statCards" :key="k.key" cols="6" md="3">
        <v-card rounded="xl" class="pa-4 h-100 kpi-gradient-card position-relative overflow-hidden"
                :class="`kpi-grad-${i}`">
          <div class="kpi-glow" />
          <div class="d-flex align-start justify-space-between position-relative">
            <div class="text-truncate">
              <div class="text-caption kpi-label text-truncate">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold mt-1 kpi-value">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption kpi-sub mt-1 text-truncate">{{ k.sub }}</div>
            </div>
            <div class="kpi-icon-wrap">
              <v-icon size="22">{{ k.icon }}</v-icon>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ───────────────────────── Tabs ───────────────────────── -->
    <v-card flat rounded="xl" class="mb-4 tab-bar">
      <v-tabs v-model="tab" color="primary" align-tabs="start" show-arrows>
        <v-tab value="team" prepend-icon="mdi-account-group">{{ $t('staff.team') }}</v-tab>
        <v-tab value="specializations" prepend-icon="mdi-school">{{ $t('staff.specializations') }}</v-tab>
        <v-tab value="schedule" prepend-icon="mdi-calendar-week">{{ $t('staff.weeklySchedule') }}</v-tab>
      </v-tabs>
    </v-card>

    <!-- ───────────────────── Team tab ───────────────────── -->
    <template v-if="tab === 'team'">
      <v-card flat rounded="xl" class="pa-3 mb-3 filter-card">
        <v-row dense align="center">
          <v-col cols="12" md="4">
            <v-text-field v-model="staffSearch" prepend-inner-icon="mdi-magnify"
                          :placeholder="$t('staff.searchByNameEmail')" density="comfortable" hide-details
                          variant="solo-filled" flat clearable @update:model-value="debouncedLoadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterRole" :items="roleFilterItems" label="Role"
                      density="comfortable" hide-details variant="outlined" clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterBranch" :items="branchItems" item-title="name" item-value="id"
                      label="Branch" density="comfortable" hide-details variant="outlined" clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterSpec" :items="specItems" item-title="name" item-value="id"
                      label="Specialization" density="comfortable" hide-details variant="outlined" clearable
                      @update:model-value="loadStaff" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="filterAvail" :items="availItems" label="Availability"
                      density="comfortable" hide-details variant="outlined"
                      @update:model-value="loadStaff" />
          </v-col>
        </v-row>

        <v-row v-if="selectedStaff.length" dense align="center" class="mt-2">
          <v-col cols="auto" class="text-caption text-medium-emphasis">
            <strong>{{ selectedStaff.length }}</strong> selected
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check"
                   @click="bulkSetAvailability(true)">Set Available</v-btn>
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="warning" prepend-icon="mdi-pause"
                   @click="bulkSetAvailability(false)">Set Unavailable</v-btn>
          </v-col>
          <v-col cols="auto">
            <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-delete"
                   @click="bulkDelete">{{ $t('common.delete') }}</v-btn>
          </v-col>
          <v-spacer />
          <v-col cols="auto">
            <v-btn size="small" variant="text" prepend-icon="mdi-download" @click="exportStaffCsv">{{ $t('common.exportCSV') }}</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl" class="mb-1">
        <v-data-table-server v-model="selectedStaff" :headers="staffHeaders" :items="staff"
                             :items-length="staffTotal" :loading="loading" item-value="id" show-select
                             :items-per-page="staffPageSize" :page="staffPage"
                             :items-per-page-options="[25, 50, 100, 200]"
                             class="staff-table" hover
                             @update:page="(p) => { staffPage = p; loadStaff() }"
                             @update:items-per-page="(n) => { staffPageSize = n; staffPage = 1; loadStaff() }">

          <template #item.user_name="{ item }">
            <div class="d-flex align-center py-1">
              <div class="position-relative mr-3">
                <v-avatar :color="avatarColor(item.user_name)" size="40" class="text-white staff-avatar">
                  <span class="text-body-2 font-weight-bold">{{ initials(item.user_name) }}</span>
                </v-avatar>
                <span class="avail-dot" :class="item.is_available ? 'avail-dot--on' : 'avail-dot--off'"
                      :title="item.is_available ? 'Available' : 'Unavailable'" />
              </div>
              <div>
                <div class="font-weight-medium">{{ item.user_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ item.user_email }}</div>
              </div>
            </div>
          </template>

          <template #item.user_role="{ item }">
            <v-chip size="small" :color="roleColor(item.user_role)" variant="tonal" class="font-weight-medium"
                    :prepend-icon="roleIcon(item.user_role)">
              {{ roleLabel(item.user_role) }}
            </v-chip>
          </template>

          <template #item.specialization_name="{ item }">
            <v-chip v-if="item.specialization_name" size="small" variant="tonal" color="deep-purple"
                    prepend-icon="mdi-school">{{ item.specialization_name }}</v-chip>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.branch_name="{ item }">
            <v-chip v-if="item.branch_name" size="small" variant="tonal" color="blue"
                    :prepend-icon="isInventory ? 'mdi-warehouse' : 'mdi-map-marker'">
              {{ item.branch_name }}
            </v-chip>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.years_of_experience="{ item }">
            <v-chip size="x-small" variant="outlined">{{ item.years_of_experience || 0 }} yr</v-chip>
          </template>

          <template #item.is_available="{ item }">
            <div class="d-flex align-center">
              <v-switch :model-value="item.is_available" color="success" inset hide-details density="compact"
                        class="mt-0" @update:model-value="(v) => toggleAvailability(item, v)" />
            </div>
          </template>

          <template #item.actions="{ item }">
            <v-menu offset="4">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact" min-width="180">
                <v-list-item prepend-icon="mdi-pencil" :title="$t('common.edit')" @click="openStaffDialog(item)" />
                <v-list-item prepend-icon="mdi-lock-reset" title="Reset password" @click="quickResetPassword(item)" />
                <v-list-item prepend-icon="mdi-delete" :title="$t('common.delete')" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </template>

          <template #no-data>
            <div class="text-center pa-8 text-medium-emphasis">
              <div class="empty-icon-wrap mx-auto mb-3">
                <v-icon size="48" color="grey-lighten-1">mdi-account-off</v-icon>
              </div>
              <div class="text-h6 font-weight-medium mb-1">No staff members yet</div>
              <div class="text-body-2 mb-4">Add your first team member to get started</div>
              <v-btn color="primary" variant="flat" prepend-icon="mdi-account-plus" class="text-none"
                     @click="openStaffDialog()">Add your first staff member</v-btn>
            </div>
          </template>
        </v-data-table-server>
      </v-card>
    </template>

    <!-- ───────────────── Specializations tab ───────────────── -->
    <template v-if="tab === 'specializations'">
      <v-card flat rounded="xl" class="pa-3 mb-3 filter-card">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="specSearch" prepend-inner-icon="mdi-magnify" placeholder="Search specializations…"
                          density="comfortable" hide-details variant="solo-filled" flat clearable
                          @update:model-value="loadSpecs" />
          </v-col>
          <v-spacer />
          <v-col cols="auto">
            <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openSpecDialog()">New Specialization</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl">
        <v-data-table :headers="specHeaders" :items="specs" :loading="loading" item-value="id" hover>
          <template #item.is_active="{ item }">
            <v-switch :model-value="item.is_active" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleSpecActive(item, v)" />
          </template>
          <template #item.actions="{ item }">
            <v-menu offset="4">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact" min-width="180">
                <v-list-item prepend-icon="mdi-pencil" :title="$t('common.edit')" @click="openSpecDialog(item)" />
                <v-list-item prepend-icon="mdi-delete" :title="$t('common.delete')" base-color="error"
                             @click="deleteSpec(item)" />
              </v-list>
            </v-menu>
          </template>
          <template #no-data>
            <div class="text-center pa-8 text-medium-emphasis">
              <div class="empty-icon-wrap mx-auto mb-3">
                <v-icon size="48" color="grey-lighten-1">mdi-school-outline</v-icon>
              </div>
              <div class="text-h6 font-weight-medium mb-1">No specializations defined</div>
              <div class="text-body-2 mb-4">Create a specialization to categorize your staff</div>
              <v-btn color="primary" variant="flat" class="text-none" prepend-icon="mdi-plus" @click="openSpecDialog()">Create specialization</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ───────────────── Schedule tab ───────────────── -->
    <template v-if="tab === 'schedule'">
      <v-card flat rounded="xl" class="pa-5 schedule-hero">
        <div class="d-flex align-center mb-4">
          <div class="header-icon-wrap mr-3">
            <v-icon size="22" color="white">mdi-calendar-week</v-icon>
          </div>
          <div>
            <div class="text-h6 font-weight-bold text-white">Weekly Schedule Overview</div>
            <div class="text-caption text-white" style="opacity:.85">Who is rostered on each day</div>
          </div>
          <v-spacer />
          <v-chip size="small" class="hero-chip" prepend-icon="mdi-calendar-check">
            {{ scheduledCount }} of {{ allStaff.length }} staff scheduled
          </v-chip>
        </div>

        <v-row>
          <v-col v-for="d in weekdays" :key="d.key" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="xl" class="schedule-day pa-3 h-100" :border="true"
                    :class="{ 'schedule-day--today': d.key === todayKey }">
              <div class="d-flex align-center mb-2">
                <div class="schedule-day-icon" :class="{ 'schedule-day-icon--today': d.key === todayKey }">
                  <v-icon size="16">{{ d.key === todayKey ? 'mdi-star' : 'mdi-calendar' }}</v-icon>
                </div>
                <div class="font-weight-medium ml-2">{{ d.label }}</div>
                <v-spacer />
                <v-chip size="x-small" :variant="d.key === todayKey ? 'flat' : 'tonal'"
                        :color="d.key === todayKey ? 'primary' : 'primary'"
                        :class="{ 'text-white': d.key === todayKey }">
                  {{ scheduleByDay[d.key]?.length || 0 }}
                </v-chip>
              </div>
              <div v-if="(scheduleByDay[d.key] || []).length === 0"
                   class="text-caption text-disabled pa-4 text-center rounded-lg border-dashed">
                No staff scheduled
              </div>
              <transition-group name="list">
                <div v-for="entry in (scheduleByDay[d.key] || [])" :key="entry.id"
                     class="d-flex align-center pa-2 schedule-entry rounded mb-1">
                  <v-avatar :color="avatarColor(entry.user_name)" size="30" class="mr-2 text-white">
                    <span class="text-caption font-weight-bold">{{ initials(entry.user_name) }}</span>
                  </v-avatar>
                  <div class="flex-grow-1 text-body-2">
                    <div class="font-weight-medium">{{ entry.user_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ entry.shift }}</div>
                  </div>
                  <v-icon size="14" color="success">mdi-clock-outline</v-icon>
                </div>
              </transition-group>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ───────────────────── Staff dialog ───────────────────── -->
    <v-dialog v-model="staffDialog" max-width="780" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="primary" class="mr-2">{{ editingStaff ? 'mdi-account-edit' : 'mdi-account-plus' }}</v-icon>
          {{ editingStaff ? 'Edit Staff Member' : 'Add Staff Member' }}
          <v-spacer />
          <v-btn icon size="small" variant="text" @click="staffDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.first_name" label="First name *" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.last_name" label="Last name *" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.email" label="Email *" type="email"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.phone" label="Phone" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="staffForm.role" :items="roleSelectItems" label="Role *"
                        variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="staffForm.specialization" :items="specItems" item-title="name" item-value="id"
                        label="Specialization" clearable variant="outlined" density="comfortable" />
            </v-col>
            <v-col v-if="!editingStaff" cols="12" md="6">
              <v-text-field v-model="staffForm.password" :type="showPassword ? 'text' : 'password'"
                            label="Password *" variant="outlined" density="comfortable"
                            :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                            @click:append-inner="showPassword = !showPassword" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="staffForm.branch_id" :items="branchItems" item-title="name" item-value="id"
                        label="Branch" clearable variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.license_number" label="License number"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="staffForm.qualification" label="Qualification"
                            placeholder="e.g. BPharm, Diploma" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="staffForm.years_of_experience" type="number" min="0"
                            label="Years exp." variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="6" md="3" class="d-flex align-center">
              <v-switch v-model="staffForm.is_available" color="success" inset label="Available" />
            </v-col>

            <v-col v-if="editingStaff" cols="12">
              <v-divider class="my-2" />
              <v-card flat rounded="lg" border class="pa-3 credentials-panel">
                <div class="d-flex align-center mb-2">
                  <v-icon size="20" color="indigo" class="mr-2">mdi-key-variant</v-icon>
                  <div class="text-subtitle-2 font-weight-medium">Login credentials</div>
                  <v-spacer />
                  <v-switch v-model="staffForm.is_user_active" color="success" inset hide-details density="compact"
                            class="mt-0" :label="staffForm.is_user_active ? 'Account enabled' : 'Account disabled'" />
                </div>
                <div class="text-caption text-medium-emphasis mb-3">
                  Change the staff member's email or set a new password. Leave the password empty to keep the current one.
                </div>
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="staffForm.new_password" :type="showNewPassword ? 'text' : 'password'"
                                  label="New password" placeholder="Leave blank to keep current"
                                  variant="outlined" density="comfortable" hide-details
                                  :append-inner-icon="showNewPassword ? 'mdi-eye-off' : 'mdi-eye'"
                                  @click:append-inner="showNewPassword = !showNewPassword" />
                  </v-col>
                  <v-col cols="12" md="6" class="d-flex align-center">
                    <v-btn variant="tonal" color="indigo" prepend-icon="mdi-lock-reset"
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
              <div class="text-subtitle-2 mb-2">
                <v-icon size="18" class="mr-1">mdi-calendar-week</v-icon>
                Weekly schedule
              </div>
              <v-row dense>
                <v-col v-for="d in weekdays" :key="d.key" cols="12" sm="6" md="4">
                  <v-text-field v-model="staffForm.schedule[d.key]"
                                :label="d.label" placeholder="e.g. 08:00 – 17:00 or Off"
                                variant="outlined" density="comfortable" hide-details />
                </v-col>
              </v-row>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="staffDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="elevated" :loading="saving" @click="saveStaff">
            {{ editingStaff ? 'Save changes' : 'Create staff' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ─────────────── Specialization dialog ─────────────── -->
    <v-dialog v-model="specDialog" max-width="540" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="primary" class="mr-2">mdi-school</v-icon>
          {{ editingSpec ? 'Edit Specialization' : 'New Specialization' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-text-field v-model="specForm.name" label="Name *" variant="outlined" density="comfortable" />
          <v-textarea v-model="specForm.description" label="Description" rows="3"
                      variant="outlined" density="comfortable" />
          <v-switch v-model="specForm.is_active" color="success" inset label="Active" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="specDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="elevated" :loading="saving" @click="saveSpec">{{ $t('common.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ─────────────── Confirm delete dialog ─────────────── -->
    <v-dialog v-model="confirmDialog" max-width="440">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>
          Confirm delete
        </v-card-title>
        <v-card-text class="pa-5">
          Permanently delete <strong>{{ pendingDelete?.user_name }}</strong>?
          This cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="confirmDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" variant="elevated" @click="performDelete">{{ $t('common.delete') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="resetDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="warning" class="mr-2">mdi-lock-reset</v-icon>
          Reset password
        </v-card-title>
        <v-card-text class="pa-5">
          <v-alert type="warning" variant="tonal" border="start" prominent density="compact" class="mb-4">
            <strong>{{ pendingReset?.user_name }}</strong> will lose access to the current password and must use the new one to log in. Make sure to share the new password securely.
          </v-alert>
          <v-alert type="info" variant="tonal" border="start" density="compact" class="mb-3">
            <div class="text-caption text-uppercase font-weight-bold mb-1">New password</div>
            <div class="d-flex align-center">
              <code class="text-body-1 flex-grow-1" style="word-break:break-all">{{ pendingResetPw }}</code>
              <v-btn icon="mdi-content-copy" size="small" variant="text" class="ml-2"
                     @click="copyToClipboard(pendingResetPw)" />
            </div>
          </v-alert>
        </v-card-text>
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="resetDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="warning" variant="elevated" prepend-icon="mdi-lock-reset" @click="performResetPassword">
            Reset password
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

// Inventory / warehouse tenants call their team "Warehouse Staff".
const isInventory = computed(() => auth.tenantType === 'inventory')
const pageTitle = computed(() =>
  auth.tenantType === 'inventory' ? 'Warehouse Staff' : t('staff.title')
)

// ─────────────── State ───────────────
const tab = ref(['team', 'specializations', 'schedule'].includes(route.query.tab) ? route.query.tab : 'team')
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

const resetDialog = ref(false)
const pendingReset = ref(null)
const pendingResetPw = ref('')

const snack = reactive({ show: false, color: 'success', message: '' })

const ROLE_LABELS = {
  branch_admin: 'Branch Admin',
  pharmacist: 'Pharmacist',
  pharmacy_tech: 'Pharmacy Tech',
  cashier: 'Cashier',
  inventory_admin: 'Inventory Admin',
  storekeeper: 'Storekeeper',
}
const ROLE_COLORS = {
  branch_admin: 'deep-purple',
  pharmacist: 'primary',
  pharmacy_tech: 'teal',
  cashier: 'amber-darken-2',
  inventory_admin: 'cyan-darken-1',
  storekeeper: 'brown',
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

const staffHeaders = [
  { title: 'Staff', key: 'user_name', sortable: true },
  { title: 'Role', key: 'user_role', sortable: true, width: 140 },
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

// ─────────────── Stats / derived ───────────────
const availableCount = computed(() => allStaff.value.filter(s => s.is_available).length)

const statCards = computed(() => {
  const total = allStaff.value.length
  const available = availableCount.value
  const pct = total ? Math.round((available / total) * 100) : 0
  const unavailable = total - available
  const scheduled = scheduledCount.value
  return [
    { key: 'total', label: 'Total Staff', value: total,
      sub: `${available} available now`, icon: 'mdi-account-group', color: 'indigo' },
    { key: 'avail', label: 'Available Now', value: available,
      sub: `${pct}% of the team`, icon: 'mdi-check-circle', color: 'success' },
    { key: 'unavail', label: 'Unavailable', value: unavailable,
      sub: unavailable ? 'check their schedules' : 'everyone is in',
      icon: 'mdi-pause-circle', color: 'amber-darken-2' },
    { key: 'sched', label: 'Scheduled', value: scheduled,
      sub: `of ${total} team members`, icon: 'mdi-calendar-check', color: 'cyan-darken-1' },
  ]
})

// Highlight today's column in the schedule
const todayKey = computed(() => {
  const keys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
  return keys[new Date().getDay()]
})

const branchItems = computed(() => branches.value.map(b => ({ id: b.id, name: b.name })))
const specItems = computed(() => specs.value.map(s => ({ id: s.id, name: s.name })))

const scheduleByDay = computed(() => {
  const map = {}
  weekdays.forEach(d => { map[d.key] = [] })
  for (const s of allStaff.value) {
    const sch = s.schedule || {}
    for (const d of weekdays) {
      const v = (sch[d.key] || '').trim()
      if (v && v.toLowerCase() !== 'off') {
        map[d.key].push({ id: `${s.id}-${d.key}`, user_name: s.user_name, shift: v })
      }
    }
  }
  return map
})

const scheduledCount = computed(() =>
  allStaff.value.filter(s => Object.values(s.schedule || {}).some(v => v && String(v).trim() && String(v).toLowerCase() !== 'off')).length
)

// ─────────────── Helpers ───────────────
function blankStaff() {
  return {
    email: '', first_name: '', last_name: '', phone: '',
    role: 'pharmacist', password: '',
    new_password: '', is_user_active: true,
    specialization: null, branch_id: null,
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
const ROLE_ICONS = {
  branch_admin: 'mdi-source-branch',
  pharmacist: 'mdi-pill',
  pharmacy_tech: 'mdi-pill-multiple',
  cashier: 'mdi-cash-register',
  inventory_admin: 'mdi-shield-crown-outline',
  storekeeper: 'mdi-warehouse',
}
function roleIcon(r) { return ROLE_ICONS[r] || 'mdi-account' }
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
    const { data } = await $api.get(branchesApi.value, { params: { page_size: 200 } })
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
      role: item.user_role || 'pharmacist',
      password: '',
      new_password: '',
      is_user_active: item.is_user_active ?? true,
      specialization: item.specialization || null,
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
  showNewPassword.value = false
  staffDialog.value = true
}

async function saveStaff() {
  const f = staffForm.value
  if (!f.first_name || !f.last_name || !f.email || !f.role) {
    notify('First name, last name, email and role are required', 'warning'); return
  }
  if (!editingStaff.value && (!f.password || f.password.length < 8)) {
    notify('Password must be at least 8 characters', 'warning'); return
  }
  saving.value = true
  try {
    if (editingStaff.value) {
      const payload = {
        first_name: f.first_name, last_name: f.last_name,
        email: f.email, phone: f.phone, role: f.role,
        is_user_active: f.is_user_active,
        specialization: f.specialization, branch_id: f.branch_id,
        license_number: f.license_number, qualification: f.qualification,
        years_of_experience: Number(f.years_of_experience) || 0,
        is_available: f.is_available,
        schedule: f.schedule,
      }
      if (f.new_password && f.new_password.length >= 8) payload.password = f.new_password
      else if (f.new_password) {
        notify('New password must be at least 8 characters', 'warning')
        saving.value = false
        return
      }
      await $api.patch(`/staff/${editingStaff.value.id}/`, payload)
      notify(f.new_password ? 'Staff updated and password reset' : 'Staff updated')
    } else {
      const payload = {
        email: f.email, first_name: f.first_name, last_name: f.last_name,
        phone: f.phone, role: f.role, password: f.password,
        specialization: f.specialization, branch_id: f.branch_id,
        license_number: f.license_number, qualification: f.qualification,
        years_of_experience: Number(f.years_of_experience) || 0,
        is_available: f.is_available,
      }
      const { data: created } = await $api.post('/staff/', payload)
      if (Object.keys(f.schedule || {}).length && created?.id) {
        await $api.patch(`/staff/${created.id}/`, { schedule: f.schedule })
      }
      notify('Staff created')
    }
    staffDialog.value = false
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}

function confirmDelete(item) { pendingDelete.value = item; confirmDialog.value = true }

function genRandomPassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lower = 'abcdefghjkmnpqrstuvwxyz'
  const digits = '23456789'
  const symbols = '!@#$%&*?'
  const all = upper + lower + digits + symbols
  const pick = s => s[Math.floor(Math.random() * s.length)]
  let pw = pick(upper) + pick(lower) + pick(digits) + pick(symbols)
  for (let i = 0; i < 8; i++) pw += pick(all)
  return pw.split('').sort(() => Math.random() - 0.5).join('')
}

function quickResetPassword(item) {
  pendingReset.value = item
  pendingResetPw.value = genRandomPassword()
  resetDialog.value = true
}

async function copyToClipboard(text) {
  try { await navigator.clipboard.writeText(text) } catch {}
}

async function performResetPassword() {
  if (!pendingReset.value) return
  try {
    await $api.patch(`/staff/${pendingReset.value.id}/`, { password: pendingResetPw.value })
    try { await navigator.clipboard.writeText(pendingResetPw.value); notify('Password reset and copied to clipboard') }
    catch { notify('Password reset (copy from dialog)') }
    resetDialog.value = false
  } catch (e) { notify(extractError(e) || 'Reset failed', 'error') }
}

async function performDelete() {
  try {
    await $api.delete(`/staff/${pendingDelete.value.id}/`)
    notify('Staff deleted')
    confirmDialog.value = false
    await Promise.all([loadStaff(), loadAllStaff()])
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
}

async function toggleAvailability(item, value) {
  try {
    await $api.patch(`/staff/${item.id}/`, { is_available: value })
    item.is_available = value
    notify(value ? 'Marked available' : 'Marked unavailable')
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}

async function bulkSetAvailability(value) {
  if (!selectedStaff.value.length) return
  await Promise.allSettled(selectedStaff.value.map(id =>
    $api.patch(`/staff/${id}/`, { is_available: value })
  ))
  notify(`Updated ${selectedStaff.value.length} staff`)
  selectedStaff.value = []
  await Promise.all([loadStaff(), loadAllStaff()])
}

async function bulkDelete() {
  if (!selectedStaff.value.length) return
  if (!confirm(`Permanently delete ${selectedStaff.value.length} staff member(s)?`)) return
  await Promise.allSettled(selectedStaff.value.map(id => $api.delete(`/staff/${id}/`)))
  notify('Bulk delete completed')
  selectedStaff.value = []
  await Promise.all([loadStaff(), loadAllStaff()])
}

function exportStaffCsv() {  const rows = staff.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const cols = ['user_name', 'user_email', 'user_phone', 'user_role', 'specialization_name',
                'branch_name', 'license_number', 'qualification', 'years_of_experience', 'is_available']
  const escape = v => {
    const s = v == null ? '' : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const out = [cols.join(','), ...rows.map(r => cols.map(c => escape(r[c])).join(','))]
  const blob = new Blob([out.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `${auth.tenantType === 'inventory' ? 'warehouse' : 'pharmacy'}-staff-${new Date().toISOString().slice(0, 10)}.csv`
  a.click(); URL.revokeObjectURL(url)
  notify(`Exported ${rows.length} record(s)`)
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
  if (!specForm.value.name) { notify('Name is required', 'warning'); return }
  saving.value = true
  try {
    if (editingSpec.value) {
      await $api.patch(`/staff/specializations/${editingSpec.value.id}/`, specForm.value)
      notify('Specialization updated')
    } else {
      await $api.post('/staff/specializations/', specForm.value)
      notify('Specialization created')
    }
    specDialog.value = false
    await loadSpecs()
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}
async function toggleSpecActive(item, value) {
  try {
    await $api.patch(`/staff/specializations/${item.id}/`, { is_active: value })
    item.is_active = value
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}
async function deleteSpec(item) {
  if (!confirm(`Delete specialization "${item.name}"?`)) return
  try {
    await $api.delete(`/staff/specializations/${item.id}/`)
    notify('Deleted')
    await loadSpecs()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
}

// ─────────────── Watchers / init ───────────────
watch(tab, (t) => {
  if (t === 'specializations' && !specs.value.length) loadSpecs()
  if (route.query.tab !== t) router.replace({ query: { ...route.query, tab: t } })
})

onMounted(() => { reloadAll() })
</script>

<style scoped>
/* ── Hero band ─────────────────────────────────────────────── */
.hero-band {
  background: linear-gradient(135deg, #1e1b4b 0%, #312e81 40%, #4338ca 70%, #6366f1 100%);
  box-shadow: 0 12px 32px rgba(79, 70, 229, 0.25);
}
.hero-icon-wrap {
  width: 56px; height: 56px; border-radius: 14px;
  background: rgba(255, 255, 255, 0.18); display: flex; align-items: center; justify-content: center;
  backdrop-filter: blur(8px);
  box-shadow: 0 4px 14px rgba(0,0,0,0.12);
}
.hero-chip {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #fff !important;
  backdrop-filter: blur(4px);
}

/* ── KPI gradient cards ────────────────────────────────────── */
.kpi-gradient-card {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  color: #fff;
  border: none;
  min-height: 120px;
}
.kpi-gradient-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 28px rgba(0,0,0,0.15);
}
.kpi-grad-0 { background: linear-gradient(135deg, #4f46e5 0%, #6366f1 50%, #818cf8 100%); }
.kpi-grad-1 { background: linear-gradient(135deg, #059669 0%, #10b981 50%, #34d399 100%); }
.kpi-grad-2 { background: linear-gradient(135deg, #d97706 0%, #f59e0b 50%, #fbbf24 100%); }
.kpi-grad-3 { background: linear-gradient(135deg, #0891b2 0%, #06b6d4 50%, #22d3ee 100%); }
.kpi-glow {
  position: absolute; top: -30px; right: -20px;
  width: 90px; height: 90px; border-radius: 50%;
  background: rgba(255,255,255,0.12); filter: blur(20px);
}
.kpi-label { color: rgba(255,255,255,0.78); font-size: 0.72rem; letter-spacing: 0.5px; }
.kpi-value { color: #fff; line-height: 1.2; }
.kpi-sub { color: rgba(255,255,255,0.65); }
.kpi-icon-wrap {
  width: 42px; height: 42px; border-radius: 12px;
  background: rgba(255,255,255,0.18); display: flex; align-items: center; justify-content: center;
  backdrop-filter: blur(6px); flex-shrink: 0;
}

/* ── Tab bar ───────────────────────────────────────────────── */
.tab-bar { box-shadow: 0 1px 4px rgba(0,0,0,0.04); }

/* ── Filter card ───────────────────────────────────────────── */
.filter-card { box-shadow: 0 1px 4px rgba(0,0,0,0.04); }

/* ── Table rows ───────────────────────────────────────────── */
.staff-table :deep(tbody tr) { transition: background-color .15s ease; }
.staff-table :deep(tbody tr:hover) { background-color: rgba(99, 102, 241, 0.06); }
.staff-avatar { box-shadow: 0 2px 6px rgba(0,0,0,0.12); }

.avail-dot {
  position: absolute;
  bottom: 0;
  right: 0;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid rgb(var(--v-theme-surface));
  box-shadow: 0 1px 3px rgba(0,0,0,0.15);
}
.avail-dot--on { background: #22c55e; }
.avail-dot--off { background: #9ca3af; }

/* ── Empty states ──────────────────────────────────────────── */
.empty-icon-wrap {
  width: 72px; height: 72px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  background: rgba(var(--v-theme-on-surface), 0.04);
}

/* ── Schedule ──────────────────────────────────────────────── */
.schedule-hero {
  background: linear-gradient(135deg, #312e81 0%, #4338ca 50%, #6366f1 100%);
  box-shadow: 0 8px 24px rgba(79, 70, 229, 0.18);
}
.header-icon-wrap {
  width: 42px; height: 42px; border-radius: 12px;
  background: rgba(255, 255, 255, 0.18); display: flex; align-items: center; justify-content: center;
  backdrop-filter: blur(6px);
}
.schedule-day {
  background: rgba(255, 255, 255, 0.08);
  transition: transform .15s ease, box-shadow .15s ease, background .15s ease;
  border-color: rgba(255, 255, 255, 0.12) !important;
}
.schedule-day:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.12); }
.schedule-day--today {
  background: rgba(255, 255, 255, 0.18);
  border-color: rgba(255, 255, 255, 0.4) !important;
}
.schedule-day-icon {
  width: 28px; height: 28px; border-radius: 8px;
  background: rgba(255, 255, 255, 0.12); display: flex; align-items: center; justify-content: center;
  color: rgba(255, 255, 255, 0.7);
}
.schedule-day-icon--today {
  background: rgb(var(--v-theme-primary));
  color: #fff;
}
.border-dashed {
  border: 1.5px dashed rgba(255,255,255,0.15);
  background: rgba(255,255,255,0.03);
}
.schedule-entry {
  background: rgba(255, 255, 255, 0.08);
  transition: background .15s ease;
}
.schedule-entry:hover { background: rgba(255, 255, 255, 0.14); }

/* ── Transitions ───────────────────────────────────────────── */
.list-enter-active, .list-leave-active { transition: all .25s ease; }
.list-enter-from { opacity: 0; transform: translateX(-10px); }
.list-leave-to { opacity: 0; transform: translateX(10px); }
</style>
