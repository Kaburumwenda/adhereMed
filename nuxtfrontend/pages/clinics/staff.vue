<template>
  <v-container fluid class="pa-4 pa-md-6 sf-page">
    <!-- ═══════════════ Header — refined surface panel, no brand gradient ═══════════════ -->
    <header class="sf-head">
      <span class="sf-head-hair" aria-hidden="true" />

      <div class="sf-head-bar">
        <div class="sf-monogram" aria-hidden="true">
          <span class="sf-monogram-ring" />
          <span class="sf-monogram-txt">{{ rosterCount }}</span>
        </div>

        <div class="sf-head-id">
          <div class="sf-eyebrow">
            <span class="sf-pulse" />
            CLINIC · PEOPLE DIRECTORY
          </div>
          <h1 class="sf-title">Staff</h1>
          <p class="sf-sub">
            The people who run this clinic — roles, access, departments and today's workload.
          </p>
        </div>

        <div class="sf-head-actions">
          <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">Refresh</v-btn>
          <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-export-variant"
                 :disabled="!staff.length" @click="exportCsv">Export</v-btn>
          <v-btn class="sf-cta text-none" rounded="lg" prepend-icon="mdi-account-plus"
                 @click="openNew">Add staff</v-btn>
        </div>
      </div>

      <div class="sf-head-foot">
        <span class="sf-chip"><v-icon size="13">mdi-account-multiple-outline</v-icon>{{ fmt(kpis.total) }} people</span>
        <span class="sf-chip sf-chip--ok"><v-icon size="13">mdi-shield-check-outline</v-icon>{{ fmt(kpis.active) }} active</span>
        <span class="sf-chip"><v-icon size="13">mdi-stethoscope</v-icon>{{ fmt(kpis.clinical) }} clinical</span>
        <span class="sf-chip"><v-icon size="13">mdi-calendar-today</v-icon>{{ fmt(kpis.on_shift_today) }} booked today</span>
        <span v-if="kpis.inactive" class="sf-chip sf-chip--warn">
          <v-icon size="13">mdi-account-off-outline</v-icon>{{ fmt(kpis.inactive) }} suspended
        </span>
        <span class="sf-stamp">{{ updatedLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ KPI strip ═══════════════ -->
    <section class="sf-kpis">
      <article v-for="k in kpiTiles" :key="k.key" class="sf-kpi" :style="{ '--tone': k.tone }">
        <div class="sf-kpi-head">
          <span class="sf-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
        </div>
        <div class="sf-kpi-value">{{ k.value }}</div>
        <div class="sf-kpi-label">{{ k.label }}</div>
        <div class="sf-kpi-sub">{{ k.sub }}</div>
        <span class="sf-kpi-rule" aria-hidden="true" />
      </article>
    </section>

    <!-- ═══════════════ Toolbar ═══════════════ -->
    <section class="sf-toolbar">
      <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                    placeholder="Search name, email, phone, role or department…"
                    variant="outlined" density="compact" rounded="lg" hide-details
                    clearable class="sf-search" />

      <v-select v-model="roleFilter" :items="roleFilterOptions" item-title="label"
                item-value="value" label="Role" variant="outlined" density="compact"
                rounded="lg" hide-details clearable class="sf-field" />

      <v-select v-model="departmentFilter" :items="departmentOptions" label="Department"
                variant="outlined" density="compact" rounded="lg" hide-details
                clearable class="sf-field" />

      <v-select v-model="statusFilter" :items="statusOptions" item-title="label"
                item-value="value" label="Status" variant="outlined" density="compact"
                rounded="lg" hide-details clearable class="sf-field" />

      <div class="sf-viewtoggle" role="group" aria-label="Layout">
        <button type="button" :class="{ 'is-on': view === 'grid' }" title="Card view"
                aria-label="Card view" @click="setView('grid')">
          <v-icon size="17">mdi-view-grid-outline</v-icon>
        </button>
        <button type="button" :class="{ 'is-on': view === 'table' }" title="Table view"
                aria-label="Table view" @click="setView('table')">
          <v-icon size="17">mdi-format-list-bulleted</v-icon>
        </button>
      </div>
    </section>

    <div v-if="activeFilterCount" class="sf-hint">
      <v-icon size="14">mdi-filter-outline</v-icon>
      <span>{{ filtered.length }} of {{ staff.length }} shown</span>
      <button type="button" class="sf-hint-clear" @click="clearFilters">Clear filters</button>
    </div>

    <!-- ═══════════════ Body ═══════════════ -->
    <div class="sf-layout">
      <main class="sf-main">
        <!-- Skeleton -->
        <div v-if="loading" class="sf-grid">
          <div v-for="n in 6" :key="`sk-${n}`" class="sf-skel" />
        </div>

        <!-- Empty -->
        <div v-else-if="!filtered.length" class="sf-empty">
          <span class="sf-empty-icon"><v-icon size="30">mdi-account-search-outline</v-icon></span>
          <div class="sf-empty-title">No one matches this view</div>
          <p class="sf-empty-sub">
            {{ activeFilterCount
              ? 'Try loosening the filters — or search by a different name.'
              : 'Add the first staff member to start building the directory.' }}
          </p>
          <div class="sf-empty-actions">
            <v-btn v-if="activeFilterCount" variant="outlined" rounded="lg" class="text-none"
                   prepend-icon="mdi-filter-off-outline" @click="clearFilters">Clear filters</v-btn>
            <v-btn v-else class="sf-cta text-none" rounded="lg" prepend-icon="mdi-account-plus"
                   @click="openNew">Add staff</v-btn>
          </div>
        </div>

        <!-- Card grid -->
        <div v-else-if="view === 'grid'" class="sf-grid">
          <article v-for="(row, i) in filtered" :key="row.id" class="sf-card"
                   :class="{ 'sf-card--off': !row.is_active }"
                   :style="{ '--i': i }">
            <div class="sf-card-top">
              <div class="sf-avatar" :style="{ '--ring': roleTone(row.role) }">
                <span>{{ row.initials }}</span>
                <span v-if="row.is_active" class="sf-avatar-dot" />
              </div>

              <div class="sf-card-id">
                <div class="sf-card-name">{{ row.full_name }}</div>
                <div class="sf-card-role" :style="{ color: roleTone(row.role) }">
                  {{ row.role_label }}
                </div>
              </div>

              <v-menu location="bottom end" :close-on-content-click="true">
                <template #activator="{ props: mp }">
                  <button v-bind="mp" type="button" class="sf-kebab" aria-label="Staff actions">
                    <v-icon size="18">mdi-dots-vertical</v-icon>
                  </button>
                </template>
                <v-list density="compact" rounded="lg" min-width="210">
                  <v-list-item prepend-icon="mdi-pencil-outline" title="Edit details"
                               @click="openEdit(row)" />
                  <v-list-item prepend-icon="mdi-card-account-details-outline"
                               title="View profile" @click="openProfile(row)" />
                  <v-list-item :prepend-icon="row.is_active ? 'mdi-account-off-outline' : 'mdi-account-check-outline'"
                               :title="row.is_active ? 'Suspend access' : 'Restore access'"
                               @click="toggleActive(row)" />
                  <v-divider class="my-1" />
                  <v-list-item prepend-icon="mdi-delete-outline" title="Remove from clinic"
                               base-color="error" @click="confirmDelete(row)" />
                </v-list>
              </v-menu>
            </div>

            <div class="sf-card-tags">
              <span class="sf-tag sf-tag--role" :style="{ '--tone': roleTone(row.role) }">
                <v-icon size="12">{{ roleIcon(row.role) }}</v-icon>{{ row.role_label }}
              </span>
              <span v-if="row.department" class="sf-tag">
                <v-icon size="12">mdi-domain</v-icon>{{ row.department }}
              </span>
              <span v-if="row.specialization" class="sf-tag">
                <v-icon size="12">mdi-star-four-points-outline</v-icon>{{ row.specialization }}
              </span>
            </div>

            <ul class="sf-meta">
              <li>
                <v-icon size="14">mdi-email-outline</v-icon>
                <span class="sf-meta-text">{{ row.email || 'No email on file' }}</span>
              </li>
              <li>
                <v-icon size="14">mdi-phone-outline</v-icon>
                <span class="sf-meta-text">{{ row.phone || 'No phone on file' }}</span>
              </li>
              <li>
                <v-icon size="14">mdi-calendar-account-outline</v-icon>
                <span class="sf-meta-text">Joined {{ shortDate(row.date_joined) }}</span>
              </li>
            </ul>

            <div class="sf-stats">
              <div class="sf-stat">
                <span class="sf-stat-value">{{ fmt(row.appointments_today) }}</span>
                <span class="sf-stat-label">today</span>
              </div>
              <span class="sf-stat-sep" />
              <div class="sf-stat">
                <span class="sf-stat-value">{{ fmt(row.consultations_30d) }}</span>
                <span class="sf-stat-label">consults · 30d</span>
              </div>
              <span class="sf-stat-sep" />
              <div class="sf-stat">
                <span class="sf-stat-value">{{ row.is_active ? 'Active' : 'Suspended' }}</span>
                <span class="sf-stat-label">{{ loginLabel(row) }}</span>
              </div>
            </div>

            <div class="sf-card-foot">
              <button type="button" class="sf-linkbtn" @click="openProfile(row)">
                View profile
                <v-icon size="13">mdi-arrow-right</v-icon>
              </button>
              <button type="button" class="sf-linkbtn" @click="openEdit(row)">
                <v-icon size="13">mdi-pencil-outline</v-icon>
                Edit
              </button>
            </div>
          </article>
        </div>

        <!-- Table -->
        <div v-else class="sf-tablecard">
          <v-table class="sf-table" hover>
            <thead>
              <tr>
                <th>Staff</th>
                <th>Role</th>
                <th>Department</th>
                <th>Phone</th>
                <th class="text-center">Today</th>
                <th class="text-center">Consults · 30d</th>
                <th>Status</th>
                <th>Joined</th>
                <th class="sf-cell-actions" />
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filtered" :key="row.id" :class="{ 'sf-row--off': !row.is_active }">
                <td>
                  <div class="sf-rowid">
                    <div class="sf-avatar sf-avatar--sm" :style="{ '--ring': roleTone(row.role) }">
                      <span>{{ row.initials }}</span>
                    </div>
                    <div class="min-w-0">
                      <div class="sf-rowname">{{ row.full_name }}</div>
                      <div class="sf-rowemail">{{ row.email || '—' }}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <span class="sf-tag sf-tag--role" :style="{ '--tone': roleTone(row.role) }">
                    <v-icon size="12">{{ roleIcon(row.role) }}</v-icon>{{ row.role_label }}
                  </span>
                </td>
                <td class="sf-cell-muted">{{ row.department || '—' }}</td>
                <td class="sf-cell-muted">{{ row.phone || '—' }}</td>
                <td class="text-center sf-cell-num">{{ fmt(row.appointments_today) }}</td>
                <td class="text-center sf-cell-num">{{ fmt(row.consultations_30d) }}</td>
                <td>
                  <v-chip size="x-small" variant="tonal"
                          :color="row.is_active ? 'success' : 'grey'">
                    {{ row.is_active ? 'Active' : 'Suspended' }}
                  </v-chip>
                </td>
                <td class="sf-cell-muted">{{ shortDate(row.date_joined) }}</td>
                <td class="sf-cell-actions">
                  <div class="sf-rowactions">
                    <v-btn icon="mdi-pencil-outline" variant="text" size="small"
                           title="Edit" @click="openEdit(row)" />
                    <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                           title="Remove" @click="confirmDelete(row)" />
                  </div>
                </td>
              </tr>
            </tbody>
          </v-table>
        </div>
      </main>

      <!-- ═══════════════ Right rail ═══════════════ -->
      <aside class="sf-rail">
        <section class="sf-panel">
          <header class="sf-panel-head">
            <div>
              <h2 class="sf-panel-title">Role mix</h2>
              <p class="sf-panel-hint">How this clinic is staffed</p>
            </div>
            <span class="sf-panel-badge">{{ roles.length }}</span>
          </header>

          <ul v-if="roles.length" class="sf-mix">
            <li v-for="r in roles" :key="r.role" class="sf-mix-row">
              <button type="button" class="sf-mix-btn"
                      :class="{ 'is-on': roleFilter === r.role }"
                      :aria-pressed="roleFilter === r.role"
                      @click="toggleRole(r.role)">
                <span class="sf-mix-icon" :style="{ '--tone': roleTone(r.role) }">
                  <v-icon size="13">{{ roleIcon(r.role) }}</v-icon>
                </span>
                <span class="sf-mix-label">{{ r.label }}</span>
                <span class="sf-mix-count">{{ r.count }}</span>
              </button>
              <span class="sf-mix-track">
                <span class="sf-mix-fill"
                      :style="{ width: barWidth(r.count), background: roleTone(r.role) }" />
              </span>
            </li>
          </ul>
          <div v-else class="sf-panel-empty">No roles yet</div>
        </section>

        <section class="sf-panel">
          <header class="sf-panel-head">
            <div>
              <h2 class="sf-panel-title">Needs attention</h2>
              <p class="sf-panel-hint">Access and onboarding gaps</p>
            </div>
          </header>

          <ul class="sf-attention">
            <li v-for="a in attention" :key="a.key" class="sf-attn" :class="`sf-attn--${a.tone}`">
              <span class="sf-attn-icon"><v-icon size="15">{{ a.icon }}</v-icon></span>
              <div class="min-w-0 flex-grow-1">
                <div class="sf-attn-title">{{ a.title }}</div>
                <div class="sf-attn-sub">{{ a.sub }}</div>
              </div>
              <span class="sf-attn-count">{{ a.count }}</span>
            </li>
          </ul>
        </section>

        <section class="sf-panel sf-panel--quiet">
          <div class="sf-quiet-icon"><v-icon size="17">mdi-shield-lock-outline</v-icon></div>
          <div>
            <div class="sf-quiet-title">Access is audited</div>
            <p class="sf-quiet-text">
              Every role change and sign-in is written to the clinic audit trail.
              Review it in Security Centre.
            </p>
            <NuxtLink to="/clinics/audit" class="sf-quiet-link">
              Open audit log
              <v-icon size="13">mdi-arrow-top-right</v-icon>
            </NuxtLink>
          </div>
        </section>
      </aside>
    </div>

    <!-- ═══════════════ Profile dialog ═══════════════ -->
    <v-dialog v-model="profileDialog" max-width="560" scrollable>
      <v-card rounded="xl" class="sf-dialog" :style="dialogTheme">
        <div class="sf-profile-head">
          <div class="sf-avatar sf-avatar--lg" :style="{ '--ring': roleTone(profileRow?.role) }">
            <span>{{ profileRow?.initials }}</span>
          </div>
          <div class="min-w-0 flex-grow-1">
            <div class="sf-profile-name">{{ profileRow?.full_name }}</div>
            <div class="sf-profile-role">{{ profileRow?.role_label }}</div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" aria-label="Close"
                 @click="profileDialog = false" />
        </div>

        <v-divider />

        <v-card-text class="pa-5">
          <dl class="sf-dl">
            <div class="sf-dl-row">
              <dt>Email</dt>
              <dd>{{ profileRow?.email || '—' }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Phone</dt>
              <dd>{{ profileRow?.phone || '—' }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Department</dt>
              <dd>{{ profileRow?.department || 'Not assigned' }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Specialisation</dt>
              <dd>{{ profileRow?.specialization || '—' }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Licence</dt>
              <dd>{{ profileRow?.license_number || 'Not recorded' }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Experience</dt>
              <dd>{{ experienceLabel(profileRow) }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Joined</dt>
              <dd>{{ longDate(profileRow?.date_joined) }}</dd>
            </div>
            <div class="sf-dl-row">
              <dt>Last sign-in</dt>
              <dd>{{ loginLabel(profileRow) }}</dd>
            </div>
          </dl>

          <div class="sf-profile-stats">
            <div class="sf-profile-stat">
              <span>{{ fmt(profileRow?.appointments_today) }}</span>
              <small>appointments today</small>
            </div>
            <div class="sf-profile-stat">
              <span>{{ fmt(profileRow?.appointments_upcoming) }}</span>
              <small>upcoming</small>
            </div>
            <div class="sf-profile-stat">
              <span>{{ fmt(profileRow?.consultations_30d) }}</span>
              <small>consults · 30d</small>
            </div>
          </div>
        </v-card-text>

        <v-divider />
        <div class="sf-dialog-foot">
          <v-btn variant="text" class="text-none" @click="profileDialog = false">Close</v-btn>
          <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil-outline"
                 @click="editFromProfile">Edit details</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Create / edit dialog ═══════════════ -->
    <v-dialog v-model="dialog" max-width="720" persistent scrollable>
      <v-card rounded="xl" class="sf-dialog" :style="dialogTheme">
        <div class="sf-dialog-head sf-dialog-head--brand">
          <span class="sf-dialog-head-glow" />
          <span class="sf-dialog-icon">
            <v-icon size="19">{{ editing ? 'mdi-account-edit-outline' : 'mdi-account-plus-outline' }}</v-icon>
          </span>
          <div class="min-w-0 flex-grow-1">
            <div class="sf-dialog-title">{{ editing ? 'Edit staff member' : 'Add a staff member' }}</div>
            <div class="sf-dialog-sub">
              {{ editing
                ? 'Update details, role or access. Changes are audited.'
                : 'Creates a clinic login with the role you choose.' }}
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" aria-label="Close"
                 class="sf-dialog-close" @click="dialog = false" />
        </div>

        <v-card-text class="pa-5">
          <div class="sf-form-label">Identity</div>
          <v-row dense>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.first_name" label="First name *" variant="outlined"
                            density="comfortable" rounded="lg" :error-messages="formErrors.first_name"
                            @update:model-value="clearError('first_name')" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.middle_name" label="Middle name" variant="outlined"
                            density="comfortable" rounded="lg" hide-details />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.last_name" label="Last name *" variant="outlined"
                            density="comfortable" rounded="lg" :error-messages="formErrors.last_name"
                            @update:model-value="clearError('last_name')" />
            </v-col>
          </v-row>

          <div class="sf-form-label mt-4">Contact</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.email" label="Email *" type="email" variant="outlined"
                            density="comfortable" rounded="lg" prepend-inner-icon="mdi-email-outline"
                            :error-messages="formErrors.email"
                            @update:model-value="clearError('email')" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.phone" label="Phone" type="tel" variant="outlined"
                            density="comfortable" rounded="lg" prepend-inner-icon="mdi-phone-outline" />
            </v-col>
          </v-row>

          <div class="sf-form-label mt-4">Role and access</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.role" :items="roleOptions" item-title="title"
                        item-value="value" label="Role *" variant="outlined"
                        density="comfortable" rounded="lg" :error-messages="formErrors.role"
                        prepend-inner-icon="mdi-shield-account-outline"
                        @update:model-value="clearError('role')" />
            </v-col>
            <v-col cols="12" sm="6">
              <div class="sf-role-preview">
                <span class="sf-role-preview-icon" :style="{ '--tone': roleTone(form.role) }">
                  <v-icon size="15">{{ roleIcon(form.role) }}</v-icon>
                </span>
                <div class="min-w-0">
                  <div class="sf-role-preview-title">{{ roleHint(form.role).title }}</div>
                  <div class="sf-role-preview-sub">{{ roleHint(form.role).sub }}</div>
                </div>
              </div>
            </v-col>
          </v-row>

          <div class="sf-form-label mt-4">
            {{ editing ? 'Reset password' : 'Login password' }}
          </div>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.password" :type="showPwd ? 'text' : 'password'"
                            :label="editing ? 'New password (optional)' : 'Password *'"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-lock-outline"
                            :append-inner-icon="showPwd ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
                            :error-messages="formErrors.password"
                            @click:append-inner="showPwd = !showPwd"
                            @update:model-value="clearError('password')" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-btn block variant="tonal" rounded="lg" class="text-none sf-genbtn"
                     prepend-icon="mdi-dice-multiple-outline" @click="generatePassword">
                Generate
              </v-btn>
            </v-col>
          </v-row>

          <div class="sf-switchrow">
            <div class="min-w-0">
              <div class="sf-switch-title">Account active</div>
              <div class="sf-switch-sub">
                Suspended staff keep their history but cannot sign in.
              </div>
            </div>
            <v-switch v-model="form.is_active" color="primary" density="compact"
                      hide-details inset aria-label="Account active" />
          </div>

          <v-alert v-if="pageError" type="error" variant="tonal" density="compact"
                   rounded="lg" class="mt-3">{{ pageError }}</v-alert>
        </v-card-text>

        <v-divider />
        <div class="sf-dialog-foot">
          <v-btn variant="text" class="text-none sf-dialog-cancel" @click="dialog = false">Cancel</v-btn>
          <v-btn class="sf-dialog-cta text-none" rounded="lg" :loading="saving"
                 prepend-icon="mdi-content-save-outline" @click="save">
            {{ editing ? 'Save changes' : 'Create staff member' }}
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Delete dialog ═══════════════ -->
    <v-dialog v-model="deleteDialog" max-width="460">
      <v-card rounded="xl" class="sf-dialog" :style="dialogTheme">
        <div class="sf-dialog-head">
          <span class="sf-dialog-icon sf-dialog-icon--danger">
            <v-icon size="19">mdi-account-remove-outline</v-icon>
          </span>
          <div class="min-w-0 flex-grow-1">
            <div class="sf-dialog-title">Remove staff member</div>
            <div class="sf-dialog-sub">This cannot be undone.</div>
          </div>
        </div>

        <v-card-text class="pa-5">
          <p class="sf-confirm-text">
            Remove <strong>{{ deleteTarget?.full_name || 'this person' }}</strong>
            from the clinic? Their clinical records stay intact, but the login and
            role assignment are deleted.
          </p>
          <v-alert v-if="deleteTarget?.appointments_upcoming" type="warning" variant="tonal"
                   density="compact" rounded="lg" class="mt-3">
            They are assigned {{ deleteTarget.appointments_upcoming }} upcoming
            appointment{{ deleteTarget.appointments_upcoming === 1 ? '' : 's' }} —
            reassign first to avoid gaps.
          </v-alert>
        </v-card-text>

        <v-divider />
        <div class="sf-dialog-foot">
          <v-btn variant="text" class="text-none" @click="deleteDialog = false">Keep</v-btn>
          <v-btn color="error" rounded="lg" variant="flat" class="text-none"
                 :loading="saving" prepend-icon="mdi-delete-outline" @click="performDelete">
            Remove
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500"
                rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
/**
 * Premium staff directory.
 *
 * Data comes from `/auth/users/overview/` (roster + workload aggregates). That
 * endpoint is admin-only, so non-admins fall back to the plain user list and
 * simply see zeros in the workload columns.
 */
const { $api } = useNuxtApp()

/**
 * Brand bridge for the create/edit dialog.
 *
 * `v-dialog` teleports its content outside `.sf-page`, so the `--sf-*`
 * custom properties declared there never reach the dialog — every
 * `var(--sf-…)` inside it resolved to nothing (which left the Save button
 * white-on-transparent). Re-declaring them here, plus the hero gradient
 * stops from the brand palette, keeps the dialog on-brand.
 */
const brand = useBranding()

const dialogTheme = computed(() => ({
  '--sf-line': 'rgba(var(--v-theme-on-surface), 0.09)',
  '--sf-line-soft': 'rgba(var(--v-theme-on-surface), 0.06)',
  '--sf-ink': 'rgba(var(--v-theme-on-surface), 0.94)',
  '--sf-muted': 'rgba(var(--v-theme-on-surface), 0.55)',
  '--sf-faint': 'rgba(var(--v-theme-on-surface), 0.4)',
  '--sf-accent': brand.primary.value,
  '--sf-on-accent': brand.onPrimary.value,
  // Same stops BrandDialogHeader uses, so the dialog matches the page heroes.
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.18),
  '--hero-shadow': brand.shadow.value,
}))

const loading = ref(false)
const saving = ref(false)
const staff = ref([])
const kpis = ref({})
const roles = ref([])
const generatedAt = ref(null)
const pageError = ref('')

const search = ref('')
const roleFilter = ref(null)
const departmentFilter = ref(null)
const statusFilter = ref(null)
// List (table) is the default view — it scans faster than cards for a roster.
// A user's choice is remembered, but the first visit is always the list.
const VIEW_KEY = 'adheremed.clinic.staff.view'
const view = ref('table')

function setView(next) {
  view.value = next
  if (import.meta.client) {
    try { localStorage.setItem(VIEW_KEY, next) } catch { /* storage blocked */ }
  }
}

const roleOptions = [
  { title: 'Tenant Admin', value: 'tenant_admin' },
  { title: 'Doctor', value: 'doctor' },
  { title: 'Clinical Officer', value: 'clinical_officer' },
  { title: 'Dentist', value: 'dentist' },
  { title: 'Nurse', value: 'nurse' },
  { title: 'Midwife', value: 'midwife' },
  { title: 'Receptionist', value: 'receptionist' },
  { title: 'Lab Tech', value: 'lab_tech' },
  { title: 'Radiologist', value: 'radiologist' },
  { title: 'Pharmacist', value: 'pharmacist' },
  { title: 'Pharmacy Tech', value: 'pharmacy_tech' },
  { title: 'Cashier', value: 'cashier' },
]
const clinicRoleValues = new Set(roleOptions.map(r => r.value))

const statusOptions = [
  { label: 'Active', value: 'active' },
  { label: 'Suspended', value: 'inactive' },
]

// ── Derived ─────────────────────────────────────────────────────────
const rosterCount = computed(() => {
  const count = Number(kpis.value.total) || 0
  return count ? String(count) : '—'
})

const updatedLabel = computed(() => {
  if (!generatedAt.value) return ''
  const d = new Date(generatedAt.value)
  return `Updated ${d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}`
})

const kpiTiles = computed(() => {
  const k = kpis.value
  return [
    {
      key: 'total', label: 'People on file', icon: 'mdi-account-multiple-outline',
      tone: '#6366f1', value: fmt(k.total),
      sub: `${fmt(k.new_this_month)} joined this month`,
    },
    {
      key: 'active', label: 'Active access', icon: 'mdi-shield-check-outline',
      tone: '#10b981', value: fmt(k.active),
      sub: k.inactive ? `${fmt(k.inactive)} suspended` : 'All accounts in good standing',
    },
    {
      key: 'clinical', label: 'Clinical staff', icon: 'mdi-stethoscope',
      tone: '#0ea5e9', value: fmt(k.clinical), sub: 'Doctors, nurses, technicians',
    },
    {
      key: 'shift', label: 'Booked today', icon: 'mdi-calendar-today',
      tone: '#f59e0b', value: fmt(k.on_shift_today), sub: 'Have appointments on the board',
    },
    {
      key: 'consults', label: 'Consults · 30d', icon: 'mdi-clipboard-pulse-outline',
      tone: '#a855f7', value: fmt(k.consultations_30d),
      sub: `${fmt(k.visits_month)} visits this month`,
    },
    {
      key: 'admin', label: 'Administrators', icon: 'mdi-shield-crown-outline',
      tone: '#64748b', value: fmt(k.admin), sub: 'Can manage staff and billing',
    },
  ]
})

const roleFilterOptions = computed(() => {
  const seen = new Map()
  for (const r of roles.value) seen.set(r.role, r.label)
  for (const r of roleOptions) if (!seen.has(r.value)) seen.set(r.value, r.title)
  return [...seen.entries()].map(([value, label]) => ({ value, label }))
})

const departmentOptions = computed(() => {
  const set = new Set()
  for (const s of staff.value) if (s.department) set.add(s.department)
  return [...set].sort()
})

const activeFilterCount = computed(() => {
  let n = 0
  if (search.value.trim()) n += 1
  if (roleFilter.value) n += 1
  if (departmentFilter.value) n += 1
  if (statusFilter.value) n += 1
  return n
})

const filtered = computed(() => {
  let list = staff.value

  if (roleFilter.value) list = list.filter(s => s.role === roleFilter.value)
  if (departmentFilter.value) list = list.filter(s => s.department === departmentFilter.value)
  if (statusFilter.value === 'active') list = list.filter(s => s.is_active)
  if (statusFilter.value === 'inactive') list = list.filter(s => !s.is_active)

  const q = search.value.trim().toLowerCase()
  if (q) {
    list = list.filter(s => [
      s.full_name, s.email, s.phone, s.role, s.role_label,
      s.department, s.specialization,
    ].filter(Boolean).join(' ').toLowerCase().includes(q))
  }

  // Suspended accounts always sink. The list reads alphabetically (directory
  // semantics); the card view leads with whoever has the most on today.
  return [...list].sort((a, b) => {
    if (a.is_active !== b.is_active) return a.is_active ? -1 : 1
    if (view.value === 'grid') {
      if (b.appointments_today !== a.appointments_today) {
        return b.appointments_today - a.appointments_today
      }
      if (b.consultations_30d !== a.consultations_30d) {
        return b.consultations_30d - a.consultations_30d
      }
    }
    return String(a.full_name).localeCompare(String(b.full_name))
  })
})

const maxRoleCount = computed(() =>
  Math.max(1, ...roles.value.map(r => Number(r.count) || 0)))

const attention = computed(() => {
  const inactive = staff.value.filter(s => !s.is_active).length
  const neverSignedIn = staff.value.filter(s => s.is_active && !s.last_login).length
  const noDepartment = staff.value.filter(s => s.is_active && s.is_clinical && !s.department).length
  const noContact = staff.value.filter(s => s.is_active && !s.phone).length
  return [
    {
      key: 'suspended', icon: 'mdi-account-off-outline', tone: inactive ? 'danger' : 'ok',
      title: 'Suspended accounts', sub: 'Cannot sign in', count: inactive,
    },
    {
      key: 'never', icon: 'mdi-login-variant', tone: neverSignedIn ? 'warn' : 'ok',
      title: 'Never signed in', sub: 'Invite or reset the password', count: neverSignedIn,
    },
    {
      key: 'dept', icon: 'mdi-domain-off-outline', tone: noDepartment ? 'warn' : 'ok',
      title: 'No department', sub: 'Clinical staff unassigned', count: noDepartment,
    },
    {
      key: 'contact', icon: 'mdi-phone-off-outline', tone: noContact ? 'warn' : 'ok',
      title: 'Missing phone', sub: 'Hard to reach in an emergency', count: noContact,
    },
  ]
})

/** Bar width as an inline string so no comparison operators sit in the template. */
function barWidth(count) {
  const pct = Math.max(3, Math.round(((Number(count) || 0) / maxRoleCount.value) * 100))
  return `${pct}%`
}

// ── Role visuals ────────────────────────────────────────────────────
const ROLE_TONES = {
  tenant_admin: '#6366f1',
  clinic_admin: '#6366f1',
  admin: '#6366f1',
  doctor: '#2f6dff',
  clinical_officer: '#0ea5e9',
  dentist: '#0891b2',
  nurse: '#10b981',
  midwife: '#14b8a6',
  pharmacist: '#a855f7',
  pharmacy_tech: '#9333ea',
  lab_tech: '#f59e0b',
  radiologist: '#f97316',
  receptionist: '#64748b',
  cashier: '#0d9488',
}

const ROLE_ICONS = {
  tenant_admin: 'mdi-shield-crown-outline',
  clinic_admin: 'mdi-shield-crown-outline',
  admin: 'mdi-shield-crown-outline',
  doctor: 'mdi-stethoscope',
  clinical_officer: 'mdi-medical-bag',
  dentist: 'mdi-tooth-outline',
  nurse: 'mdi-hand-heart-outline',
  midwife: 'mdi-human-pregnant',
  pharmacist: 'mdi-pill',
  pharmacy_tech: 'mdi-pill-multiple',
  lab_tech: 'mdi-flask-outline',
  radiologist: 'mdi-radiology-box-outline',
  receptionist: 'mdi-desk',
  cashier: 'mdi-cash-register',
}

const ROLE_HINTS = {
  tenant_admin: { title: 'Full clinic control', sub: 'Staff, billing, settings and audit' },
  doctor: { title: 'Clinical access', sub: 'Consultations, prescriptions and results' },
  clinical_officer: { title: 'Clinical access', sub: 'Consultations and prescriptions' },
  dentist: { title: 'Clinical access', sub: 'Dental consultations and procedures' },
  nurse: { title: 'Triage and care', sub: 'Vitals, triage and care notes' },
  midwife: { title: 'Maternity care', sub: 'Antenatal and delivery workflows' },
  receptionist: { title: 'Front desk', sub: 'Registration, queue and appointments' },
  lab_tech: { title: 'Laboratory', sub: 'Lab orders, samples and results' },
  radiologist: { title: 'Imaging', sub: 'Radiology requests and reporting' },
  pharmacist: { title: 'Pharmacy', sub: 'Dispensing and stock' },
  pharmacy_tech: { title: 'Pharmacy support', sub: 'Dispensing under supervision' },
  cashier: { title: 'Cash desk', sub: 'Invoices and payments' },
}

function roleTone(role) {
  return ROLE_TONES[role] || '#64748b'
}

function roleIcon(role) {
  return ROLE_ICONS[role] || 'mdi-account-outline'
}

function roleHint(role) {
  return ROLE_HINTS[role] || { title: 'Clinic access', sub: 'Limited to assigned modules' }
}

// ── Formatting ──────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}

function shortDate(value) {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
}

function longDate(value) {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-US', { day: 'numeric', month: 'long', year: 'numeric' })
}

function loginLabel(row) {
  if (!row) return '—'
  if (!row.last_login) return 'Never signed in'
  const then = new Date(row.last_login).getTime()
  if (Number.isNaN(then)) return 'Never signed in'
  const mins = Math.floor((Date.now() - then) / 60000)
  if (mins < 1) return 'Active now'
  if (mins < 60) return `Seen ${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `Seen ${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `Seen ${days}d ago`
  return `Seen ${shortDate(row.last_login)}`
}

function experienceLabel(row) {
  const years = Number(row?.years_of_experience) || 0
  if (!years) return 'Not recorded'
  return `${years} year${years === 1 ? '' : 's'}`
}

function clearFilters() {
  search.value = ''
  roleFilter.value = null
  departmentFilter.value = null
  statusFilter.value = null
}

function toggleRole(role) {
  roleFilter.value = roleFilter.value === role ? null : role
}

// ── Loading ─────────────────────────────────────────────────────────
function rowsOf(payload) {
  return Array.isArray(payload) ? payload : (payload?.results || [])
}

function normaliseUser(u) {
  const full = `${u.first_name || ''} ${u.middle_name || ''} ${u.last_name || ''}`
    .replace(/\s+/g, ' ').trim()
  return {
    ...u,
    full_name: full || u.email || 'Unnamed',
    initials: ((u.first_name || ' ')[0] + (u.last_name || ' ')[0]).trim().toUpperCase() || '?',
    role_label: u.role_label || String(u.role || '')
      .replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
    department: u.department || '',
    specialization: u.specialization || '',
    is_clinical: u.is_clinical ?? true,
    appointments_today: u.appointments_today || 0,
    appointments_upcoming: u.appointments_upcoming || 0,
    consultations_30d: u.consultations_30d || 0,
    visits_month: u.visits_month || 0,
  }
}

async function load() {
  loading.value = true
  pageError.value = ''
  try {
    const { data } = await $api.get('/auth/users/overview/')
    kpis.value = data.kpis || {}
    roles.value = (data.roles || []).filter(r => clinicRoleValues.has(r.role) || r.count > 0)
    staff.value = (data.staff || [])
      .filter(s => clinicRoleValues.has(s.role))
      .map(normaliseUser)
    generatedAt.value = data.generated_at || Date.now()
  } catch {
    // Overview is admin-only — fall back to the plain user list.
    try {
      const { data } = await $api.get('/auth/users/', { params: { page_size: 1000 } })
      const all = rowsOf(data).filter(u => clinicRoleValues.has(u.role))
      staff.value = all.map(normaliseUser)
      const clinicalRoles = [
        'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife',
        'lab_tech', 'radiologist', 'pharmacist', 'pharmacy_tech',
      ]
      kpis.value = {
        total: all.length,
        active: all.filter(u => u.is_active).length,
        inactive: all.filter(u => !u.is_active).length,
        clinical: all.filter(u => clinicalRoles.includes(u.role)).length,
        admin: all.filter(u => ['tenant_admin', 'clinic_admin', 'admin'].includes(u.role)).length,
      }
      roles.value = roleOptions
        .map(r => ({ role: r.value, label: r.title, count: all.filter(u => u.role === r.value).length }))
        .filter(r => r.count > 0)
        .sort((a, b) => b.count - a.count)
      generatedAt.value = Date.now()
    } catch (e) {
      pageError.value = e?.response?.data?.detail || 'Could not load the staff directory.'
      staff.value = []
    }
  } finally {
    loading.value = false
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────
const dialog = ref(false)
const profileDialog = ref(false)
const profileRow = ref(null)
const editing = ref(null)
const showPwd = ref(false)
const formErrors = reactive({})

function blankForm() {
  return {
    first_name: '', middle_name: '', last_name: '',
    email: '', phone: '', role: 'doctor',
    password: '', is_active: true,
  }
}

const form = reactive(blankForm())

function clearError(key) {
  if (formErrors[key]) delete formErrors[key]
}

function openNew() {
  editing.value = null
  Object.assign(form, blankForm())
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  pageError.value = ''
  showPwd.value = false
  dialog.value = true
}

function openEdit(row) {
  editing.value = row.id
  Object.assign(form, {
    first_name: row.first_name || '',
    middle_name: row.middle_name || '',
    last_name: row.last_name || '',
    email: row.email || '',
    phone: row.phone || '',
    role: row.role || 'doctor',
    password: '',
    is_active: row.is_active !== false,
  })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  pageError.value = ''
  showPwd.value = false
  dialog.value = true
}

function openProfile(row) {
  profileRow.value = row
  profileDialog.value = true
}

function editFromProfile() {
  const row = profileRow.value
  profileDialog.value = false
  if (row) openEdit(row)
}

function generatePassword() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
  const digits = '23456789'
  const symbols = '!@#$%'
  const pool = letters + digits
  let out = ''
  for (let i = 0; i < 11; i += 1) {
    out += pool[Math.floor(Math.random() * pool.length)]
  }
  out += digits[Math.floor(Math.random() * digits.length)]
  out += symbols[Math.floor(Math.random() * symbols.length)]
  form.password = out
  showPwd.value = true
  clearError('password')
}

async function save() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  pageError.value = ''

  if (!form.first_name.trim()) formErrors.first_name = 'First name is required'
  if (!form.last_name.trim()) formErrors.last_name = 'Last name is required'
  if (!form.email.trim()) formErrors.email = 'Email is required'
  else if (!/.+@.+\..+/.test(form.email.trim())) formErrors.email = 'Enter a valid email'
  if (!form.role) formErrors.role = 'Choose a role'
  if (!editing.value && (!form.password || form.password.length < 8)) {
    formErrors.password = 'Minimum 8 characters'
  }
  if (editing.value && form.password && form.password.length < 8) {
    formErrors.password = 'Minimum 8 characters'
  }
  if (Object.keys(formErrors).length) return

  saving.value = true
  try {
    const payload = {
      first_name: form.first_name.trim(),
      middle_name: form.middle_name.trim(),
      last_name: form.last_name.trim(),
      email: form.email.trim(),
      phone: form.phone.trim(),
      role: form.role,
      is_active: form.is_active,
    }
    if (form.password) payload.password = form.password

    if (editing.value) {
      await $api.patch(`/auth/users/${editing.value}/`, payload)
      notify('Staff member updated')
    } else {
      await $api.post('/auth/users/', payload)
      notify('Staff member created')
    }
    dialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    if (d && typeof d === 'object' && !Array.isArray(d)) {
      Object.entries(d).forEach(([k, v]) => {
        if (k === 'detail' || k === 'non_field_errors') return
        formErrors[k] = Array.isArray(v) ? v[0] : String(v)
      })
    }
    pageError.value = d?.detail
      || (d?.non_field_errors ? d.non_field_errors[0] : '')
      || (Object.keys(formErrors).length ? 'Please fix the highlighted fields.' : '')
      || e?.message
      || 'Could not save this staff member.'
  } finally {
    saving.value = false
  }
}

async function toggleActive(row) {
  try {
    await $api.patch(`/auth/users/${row.id}/`, { is_active: !row.is_active })
    notify(row.is_active ? `${row.full_name} suspended` : `${row.full_name} restored`)
    await load()
  } catch {
    notify('Could not change access for this person.', 'error')
  }
}

// ── Delete ──────────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)

function confirmDelete(row) {
  deleteTarget.value = row
  deleteDialog.value = true
}

async function performDelete() {
  saving.value = true
  try {
    await $api.delete(`/auth/users/${deleteTarget.value.id}/`)
    notify('Staff member removed')
    deleteDialog.value = false
    await load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Could not remove this staff member.', 'error')
  } finally {
    saving.value = false
  }
}

// ── Export ──────────────────────────────────────────────────────────
function exportCsv() {
  const headers = ['Name', 'Role', 'Department', 'Email', 'Phone', 'Status', 'Joined']
  const rows = filtered.value.map(s => [
    s.full_name, s.role_label, s.department, s.email, s.phone,
    s.is_active ? 'Active' : 'Suspended', shortDate(s.date_joined),
  ])
  const csv = [headers, ...rows]
    .map(r => r.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `clinic-staff-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
  notify('Staff list exported')
}

// ── Snackbar ────────────────────────────────────────────────────────
const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

onMounted(() => {
  if (import.meta.client) {
    try {
      const stored = localStorage.getItem(VIEW_KEY)
      if (stored === 'grid' || stored === 'table') view.value = stored
    } catch { /* storage blocked — keep the list default */ }
  }
  load()
})
</script>

<style scoped>
.min-w-0 { min-width: 0; }

.sf-page {
  width: 100%;
  --sf-line: rgba(var(--v-theme-on-surface), 0.09);
  --sf-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --sf-ink: rgba(var(--v-theme-on-surface), 0.94);
  --sf-muted: rgba(var(--v-theme-on-surface), 0.55);
  --sf-faint: rgba(var(--v-theme-on-surface), 0.4);
  --sf-surface: rgb(var(--v-theme-surface));
  --sf-raise: 0 1px 2px rgba(15, 23, 42, 0.04), 0 18px 40px -28px rgba(15, 23, 42, 0.35);
  --sf-accent: var(--brand-primary, #2f6dff);
}

/* ══ Header — calm surface, no gradient ══ */
.sf-head {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 18px 20px 14px;
  background:
    radial-gradient(120% 140% at 100% 0%, rgba(99, 102, 241, 0.06), transparent 58%),
    var(--sf-surface);
  border: 1px solid var(--sf-line);
  box-shadow: var(--sf-raise);
}
.sf-head-hair {
  position: absolute;
  top: 0; left: 0;
  width: 100%;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--sf-accent), transparent);
  opacity: 0.35;
}
.sf-head-bar { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }

.sf-monogram {
  position: relative;
  width: 54px; height: 54px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 16px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
}
.sf-monogram-ring {
  position: absolute; inset: 4px;
  border-radius: 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
}
.sf-monogram-txt {
  position: relative;
  font-size: 15px; font-weight: 800; letter-spacing: -0.4px;
  color: var(--sf-ink);
}

.sf-head-id { flex: 1 1 340px; min-width: 0; }
.sf-eyebrow {
  display: inline-flex; align-items: center; gap: 7px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase;
  color: var(--sf-faint);
}
.sf-pulse {
  width: 6px; height: 6px; border-radius: 50%;
  background: #10b981;
  box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.16);
}
.sf-title {
  font-size: 1.55rem; font-weight: 800; letter-spacing: -0.6px;
  line-height: 1.1; margin: 2px 0 0;
  color: var(--sf-ink);
}
.sf-sub {
  font-size: 12.5px; line-height: 1.45; color: var(--sf-muted);
  margin: 3px 0 0; max-width: 72ch;
}

.sf-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.sf-cta {
  background: var(--sf-accent) !important;
  color: #fff !important;
  font-weight: 700 !important;
  letter-spacing: 0.1px;
  box-shadow: 0 10px 22px -14px rgba(47, 109, 255, 0.9);
}
.sf-cta:hover { filter: brightness(1.05); }

.sf-head-foot {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  margin-top: 14px; padding-top: 12px;
  border-top: 1px solid var(--sf-line-soft);
}
.sf-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px; border-radius: 999px;
  font-size: 11.5px; font-weight: 650;
  color: var(--sf-muted);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px solid var(--sf-line-soft);
  white-space: nowrap;
}
.sf-chip--ok {
  color: #047857; background: rgba(16, 185, 129, 0.08);
  border-color: rgba(16, 185, 129, 0.24);
}
.sf-chip--warn {
  color: #b45309; background: rgba(245, 158, 11, 0.1);
  border-color: rgba(245, 158, 11, 0.26);
}
.sf-stamp { margin-left: auto; font-size: 11px; color: var(--sf-faint); }

/* ══ KPI strip ══ */
.sf-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(168px, 1fr));
  gap: 10px;
  margin-top: 14px;
}
.sf-kpi {
  --tone: #6366f1;
  position: relative; overflow: hidden;
  padding: 13px 14px 14px;
  border-radius: 14px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
}
.sf-kpi:hover {
  transform: translateY(-2px);
  box-shadow: var(--sf-raise);
  border-color: color-mix(in srgb, var(--tone) 30%, transparent);
}
.sf-kpi-head { display: flex; align-items: center; justify-content: space-between; }
.sf-kpi-icon {
  width: 26px; height: 26px; display: grid; place-items: center;
  border-radius: 8px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.sf-kpi-value {
  font-size: 1.5rem; font-weight: 800; letter-spacing: -0.8px;
  line-height: 1.05; margin-top: 9px;
  color: var(--sf-ink);
  font-variant-numeric: tabular-nums;
}
.sf-kpi-label {
  margin-top: 3px;
  font-size: 10px; font-weight: 800; letter-spacing: 0.8px; text-transform: uppercase;
  color: var(--sf-faint);
}
.sf-kpi-sub { margin-top: 4px; font-size: 11px; color: var(--sf-muted); }
.sf-kpi-rule {
  position: absolute; left: 14px; right: 14px; bottom: 0; height: 2px;
  border-radius: 2px 2px 0 0;
  background: var(--tone); opacity: 0.5;
}

/* ══ Toolbar ══ */
.sf-toolbar {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  margin-top: 14px;
  padding: 9px 10px;
  border-radius: 14px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
}
.sf-search { flex: 1 1 300px; max-width: none; }
.sf-field { flex: 0 1 168px; }
.sf-viewtoggle {
  display: inline-flex; padding: 3px; border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.05);
  border: 1px solid var(--sf-line-soft);
}
.sf-viewtoggle button {
  width: 32px; height: 30px; display: grid; place-items: center;
  border: 0; background: transparent; border-radius: 8px; cursor: pointer;
  color: var(--sf-faint);
  transition: background 0.16s ease, color 0.16s ease;
}
.sf-viewtoggle button.is-on {
  color: var(--sf-ink);
  background: var(--sf-surface);
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
}

.sf-hint {
  display: flex; align-items: center; gap: 7px;
  margin: 10px 2px 0;
  font-size: 11.5px; color: var(--sf-muted);
}
.sf-hint-clear {
  border: 0; background: none; padding: 0; cursor: pointer;
  font-family: inherit;
  font-size: 11.5px; font-weight: 700;
  color: var(--sf-accent);
  text-decoration: underline;
  text-underline-offset: 2px;
}

/* ══ Layout ══ */
.sf-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 300px;
  gap: 14px;
  margin-top: 14px;
  align-items: start;
}
@media (max-width: 1279px) { .sf-layout { grid-template-columns: minmax(0, 1fr); } }

/* ══ Cards ══ */
.sf-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 12px;
}
.sf-card {
  position: relative;
  display: flex; flex-direction: column;
  padding: 15px 15px 12px;
  border-radius: 16px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s, border-color 0.2s;
  animation: sf-rise 0.42s cubic-bezier(0.16, 1, 0.3, 1) both;
  animation-delay: calc(var(--i, 0) * 28ms);
}
.sf-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 2px 4px rgba(15, 23, 42, 0.05), 0 22px 44px -26px rgba(15, 23, 42, 0.4);
  border-color: rgba(var(--v-theme-on-surface), 0.14);
}
.sf-card--off { opacity: 0.62; }

@keyframes sf-rise {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}

.sf-card-top { display: flex; align-items: center; gap: 11px; }
.sf-avatar {
  --ring: #64748b;
  position: relative;
  width: 42px; height: 42px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 13px;
  font-size: 13px; font-weight: 800; letter-spacing: 0.3px;
  color: var(--ring);
  background: color-mix(in srgb, var(--ring) 12%, var(--sf-surface));
  border: 1px solid color-mix(in srgb, var(--ring) 26%, transparent);
}
.sf-avatar--sm { width: 32px; height: 32px; border-radius: 10px; font-size: 11px; }
.sf-avatar--lg { width: 52px; height: 52px; border-radius: 15px; font-size: 15px; }
.sf-avatar-dot {
  position: absolute; right: -2px; bottom: -2px;
  width: 10px; height: 10px; border-radius: 50%;
  background: #10b981;
  border: 2px solid var(--sf-surface);
}
.sf-card-id { min-width: 0; flex: 1; }
.sf-card-name {
  font-size: 0.92rem; font-weight: 750; letter-spacing: -0.15px;
  color: var(--sf-ink);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sf-card-role { font-size: 11px; font-weight: 700; letter-spacing: 0.2px; }

.sf-kebab {
  width: 28px; height: 28px; flex-shrink: 0;
  display: grid; place-items: center;
  border: 0; border-radius: 8px;
  background: transparent; cursor: pointer;
  color: var(--sf-faint);
  transition: background 0.16s ease, color 0.16s ease;
}
.sf-kebab:hover { background: rgba(var(--v-theme-on-surface), 0.06); color: var(--sf-ink); }

.sf-card-tags { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 11px; }
.sf-tag {
  --tone: #64748b;
  display: inline-flex; align-items: center; gap: 4px;
  padding: 3px 8px; border-radius: 7px;
  font-size: 10.5px; font-weight: 650;
  color: var(--sf-muted);
  background: rgba(var(--v-theme-on-surface), 0.045);
  border: 1px solid var(--sf-line-soft);
  white-space: nowrap;
}
.sf-tag--role {
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 10%, transparent);
  border-color: color-mix(in srgb, var(--tone) 24%, transparent);
}

.sf-meta {
  list-style: none; margin: 11px 0 0; padding: 0;
  display: flex; flex-direction: column; gap: 5px;
}
.sf-meta li {
  display: flex; align-items: center; gap: 7px;
  font-size: 11.5px; color: var(--sf-muted);
}
.sf-meta li .v-icon { color: var(--sf-faint); flex-shrink: 0; }
.sf-meta-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.sf-stats {
  display: flex; align-items: center; gap: 10px;
  margin-top: 12px; padding: 9px 10px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid var(--sf-line-soft);
}
.sf-stat { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.sf-stat-value {
  font-size: 12.5px; font-weight: 800;
  color: var(--sf-ink);
  font-variant-numeric: tabular-nums;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sf-stat-label {
  font-size: 9.5px; font-weight: 650; letter-spacing: 0.3px; color: var(--sf-faint);
}
.sf-stat-sep { width: 1px; align-self: stretch; background: var(--sf-line-soft); }

.sf-card-foot {
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  margin-top: 11px; padding-top: 10px;
  border-top: 1px solid var(--sf-line-soft);
}
.sf-linkbtn {
  display: inline-flex; align-items: center; gap: 5px;
  border: 0; background: none; padding: 2px 0; cursor: pointer;
  font-family: inherit; font-size: 11.5px; font-weight: 700;
  color: var(--sf-accent);
  transition: gap 0.16s ease, opacity 0.16s ease;
}
.sf-linkbtn:hover { gap: 8px; opacity: 0.82; }

/* ══ Table ══ */
.sf-tablecard {
  border-radius: 16px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
  overflow: hidden;
}
.sf-table { background: transparent; }
.sf-table :deep(th) {
  font-size: 9.5px !important; font-weight: 800 !important;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: var(--sf-faint) !important;
  white-space: nowrap;
  height: 38px !important;
}
.sf-table :deep(td) {
  font-size: 12px;
  /* Vuetify pins `height: var(--v-table-row-height)` on cells; `auto` lets the
     row size to the avatar + two text lines instead of a fixed 52px box. */
  height: auto !important;
  padding-top: 8px !important;
  padding-bottom: 8px !important;
}
.sf-table :deep(tbody tr) { transition: background 0.14s ease; }
.sf-rowid { display: flex; align-items: center; gap: 9px; padding: 0; }
.sf-rowactions { display: flex; align-items: center; justify-content: flex-end; gap: 2px; }
.sf-cell-actions { white-space: nowrap; width: 92px; }
.sf-rowname { font-size: 12.5px; font-weight: 700; color: var(--sf-ink); }
.sf-rowemail { font-size: 11px; color: var(--sf-muted); }
.sf-cell-muted { font-size: 11.5px; color: var(--sf-muted); }
.sf-cell-num { font-weight: 750; font-variant-numeric: tabular-nums; }
.sf-row--off { opacity: 0.6; }

/* ══ Right rail ══ */
.sf-rail { display: flex; flex-direction: column; gap: 12px; }
.sf-panel {
  border-radius: 15px;
  padding: 14px 15px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
}
.sf-panel--quiet {
  display: flex; gap: 11px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border-style: dashed;
}
.sf-panel-head {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 10px;
  margin-bottom: 11px;
}
.sf-panel-title {
  font-size: 0.86rem; font-weight: 750; letter-spacing: -0.1px; color: var(--sf-ink);
}
.sf-panel-hint { font-size: 11px; color: var(--sf-muted); }
.sf-panel-badge {
  min-width: 22px; height: 20px; padding: 0 7px;
  display: grid; place-items: center;
  border-radius: 999px;
  font-size: 10.5px; font-weight: 800;
  color: var(--sf-muted);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.sf-panel-empty { font-size: 11.5px; color: var(--sf-faint); padding: 6px 0; }

.sf-mix { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.sf-mix-row { display: flex; flex-direction: column; gap: 4px; }
.sf-mix-btn {
  display: flex; align-items: center; gap: 7px;
  width: 100%; padding: 3px 4px;
  border: 0; border-radius: 7px; background: transparent;
  cursor: pointer; text-align: left;
  font-family: inherit; font-size: 11.5px; font-weight: 650;
  color: var(--sf-ink);
  transition: background 0.16s ease;
}
.sf-mix-btn:hover { background: rgba(var(--v-theme-on-surface), 0.05); }
.sf-mix-btn.is-on { background: rgba(var(--v-theme-on-surface), 0.08); }
.sf-mix-icon {
  --tone: #64748b;
  width: 20px; height: 20px; flex-shrink: 0;
  display: grid; place-items: center; border-radius: 6px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.sf-mix-label {
  flex: 1; min-width: 0;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.sf-mix-count {
  font-size: 11px; font-weight: 800; color: var(--sf-muted);
  font-variant-numeric: tabular-nums;
}
.sf-mix-track {
  display: block; height: 4px; margin-left: 27px;
  border-radius: 3px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  overflow: hidden;
}
.sf-mix-fill { display: block; height: 100%; border-radius: 3px; opacity: 0.85; }

.sf-attention {
  list-style: none; margin: 0; padding: 0;
  display: flex; flex-direction: column; gap: 7px;
}
.sf-attn {
  --tone: #64748b;
  display: flex; align-items: center; gap: 9px;
  padding: 8px 9px;
  border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid var(--sf-line-soft);
}
.sf-attn--ok { --tone: #10b981; }
.sf-attn--warn { --tone: #f59e0b; }
.sf-attn--danger { --tone: #ef4444; }
.sf-attn-icon { color: var(--tone); display: flex; flex-shrink: 0; }
.sf-attn-title { font-size: 11.5px; font-weight: 700; color: var(--sf-ink); }
.sf-attn-sub { font-size: 10.5px; color: var(--sf-muted); }
.sf-attn-count {
  font-size: 12px; font-weight: 800; color: var(--tone);
  font-variant-numeric: tabular-nums;
}

.sf-quiet-icon { color: var(--sf-muted); display: flex; }
.sf-quiet-title { font-size: 11.5px; font-weight: 750; color: var(--sf-ink); }
.sf-quiet-text {
  font-size: 11px; line-height: 1.4; color: var(--sf-muted); margin: 2px 0 6px;
}
.sf-quiet-link {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 11px; font-weight: 750; text-decoration: none;
  color: var(--sf-accent);
}

/* ══ Empty / skeleton ══ */
.sf-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 7px; padding: 56px 20px; text-align: center;
  border-radius: 16px;
  background: var(--sf-surface);
  border: 1px dashed var(--sf-line);
}
.sf-empty-icon {
  width: 56px; height: 56px; display: grid; place-items: center;
  border-radius: 16px;
  color: var(--sf-faint);
  background: rgba(var(--v-theme-on-surface), 0.04);
}
.sf-empty-title { font-size: 0.95rem; font-weight: 750; color: var(--sf-ink); }
.sf-empty-sub { font-size: 12px; color: var(--sf-muted); max-width: 42ch; margin: 0; }
.sf-empty-actions { display: flex; gap: 8px; margin-top: 6px; }

.sf-skel {
  height: 246px;
  border-radius: 16px;
  background: var(--sf-surface);
  border: 1px solid var(--sf-line);
  position: relative;
  overflow: hidden;
}
.sf-skel::after {
  content: '';
  position: absolute; inset: 0;
  transform: translateX(-100%);
  background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.16), transparent);
  animation: sf-shimmer 1.4s infinite;
}
@keyframes sf-shimmer { to { transform: translateX(100%); } }

/* ══ Dialogs ══ */
.sf-dialog { background: rgb(var(--v-theme-surface)); }
.sf-dialog-head {
  position: relative;
  overflow: hidden;
  display: flex; align-items: center; gap: 12px;
  padding: 16px 18px;
  border-bottom: 1px solid var(--sf-line-soft);
}

/* Branded header — matches the BrandDialogHeader gradient used elsewhere.
   Foreground is forced white: these gradients are always mid-to-dark, so
   `--sf-ink` (near-black) would be unreadable on them. */
.sf-dialog-head--brand {
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep) 0%,
    var(--hero-main) 54%,
    var(--hero-accent) 100%
  );
  border-bottom: 0;
  padding: 18px 18px 17px;
}
.sf-dialog-head--brand :deep(.v-icon) { color: currentColor; }
.sf-dialog-head--brand .sf-dialog-title { color: #fff; }
.sf-dialog-head--brand .sf-dialog-sub { color: rgba(255, 255, 255, 0.8); }

.sf-dialog-head-glow {
  position: absolute;
  width: 230px; height: 230px;
  border-radius: 50%;
  right: -84px; top: -132px;
  background: radial-gradient(circle, var(--hero-glow), transparent 68%);
  pointer-events: none;
}
.sf-dialog-head--brand .sf-dialog-icon {
  position: relative;
  color: #fff;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.28);
}
.sf-dialog-head--brand > div,
.sf-dialog-head--brand > .sf-dialog-icon { position: relative; }
/* The ✕ sits on the light tail of the gradient (~3.3:1 for a bare white
   glyph), so it carries its own translucent backdrop. */
.sf-dialog-close {
  position: relative;
  color: #fff !important;
  background: rgba(255, 255, 255, 0.14) !important;
}
.sf-dialog-close:hover { background: rgba(255, 255, 255, 0.26) !important; }

.sf-dialog-icon {
  width: 36px; height: 36px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 11px;
  color: var(--sf-accent);
  background: color-mix(in srgb, var(--sf-accent) 11%, transparent);
}
.sf-dialog-icon--danger { color: #dc2626; background: rgba(220, 38, 38, 0.1); }
.sf-dialog-title { font-size: 0.95rem; font-weight: 750; color: var(--sf-ink); }
.sf-dialog-sub { font-size: 11.5px; color: var(--sf-muted); }
.sf-dialog-foot {
  display: flex; align-items: center; justify-content: flex-end; gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid var(--sf-line-soft);
}

/* Footer buttons — brand primary for the action, brand tint for the dismiss. */
.sf-dialog-cancel {
  color: var(--sf-accent) !important;
  font-weight: 650 !important;
  background: color-mix(in srgb, var(--sf-accent) 8%, transparent) !important;
}
.sf-dialog-cancel:hover {
  background: color-mix(in srgb, var(--sf-accent) 15%, transparent) !important;
}
.sf-dialog-cta {
  background: var(--sf-accent) !important;
  color: var(--sf-on-accent) !important;
  font-weight: 700 !important;
  letter-spacing: 0.1px;
  box-shadow: 0 10px 22px -14px color-mix(in srgb, var(--sf-accent) 80%, transparent);
}
.sf-dialog-cta:hover { filter: brightness(1.06); }
.sf-form-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.9px; text-transform: uppercase;
  color: var(--sf-faint);
  margin-bottom: 7px;
}
.sf-role-preview {
  display: flex; align-items: center; gap: 9px;
  height: 100%;
  padding: 10px 12px;
  border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px dashed var(--sf-line);
}
.sf-role-preview-icon {
  --tone: #64748b;
  width: 26px; height: 26px; flex-shrink: 0;
  display: grid; place-items: center; border-radius: 8px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.sf-role-preview-title { font-size: 11.5px; font-weight: 750; color: var(--sf-ink); }
.sf-role-preview-sub { font-size: 10.5px; line-height: 1.3; color: var(--sf-muted); }
.sf-genbtn { height: 44px; }
.sf-switchrow {
  display: flex; align-items: center; justify-content: space-between; gap: 14px;
  margin-top: 14px; padding: 10px 12px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid var(--sf-line-soft);
}
.sf-switch-title { font-size: 12px; font-weight: 700; color: var(--sf-ink); }
.sf-switch-sub { font-size: 11px; color: var(--sf-muted); }
.sf-confirm-text { font-size: 12.5px; line-height: 1.5; color: var(--sf-muted); margin: 0; }
.sf-confirm-text strong { color: var(--sf-ink); }

/* Profile dialog */
.sf-profile-head {
  display: flex; align-items: center; gap: 13px;
  padding: 18px;
  background: linear-gradient(160deg, rgba(var(--v-theme-on-surface), 0.035), transparent 70%);
}
.sf-profile-name {
  font-size: 1.02rem; font-weight: 750; letter-spacing: -0.2px; color: var(--sf-ink);
}
.sf-profile-role { font-size: 11.5px; font-weight: 650; color: var(--sf-muted); }
.sf-dl { margin: 0; display: flex; flex-direction: column; gap: 1px; }
.sf-dl-row {
  display: flex; align-items: baseline; justify-content: space-between; gap: 14px;
  padding: 8px 0;
  border-bottom: 1px solid var(--sf-line-soft);
}
.sf-dl-row:last-child { border-bottom: 0; }
.sf-dl-row dt {
  font-size: 10px; font-weight: 800; letter-spacing: 0.7px; text-transform: uppercase;
  color: var(--sf-faint);
}
.sf-dl-row dd {
  margin: 0; font-size: 12px; font-weight: 600; color: var(--sf-ink); text-align: right;
}
.sf-profile-stats {
  display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px; margin-top: 14px;
}
.sf-profile-stat {
  display: flex; flex-direction: column; gap: 1px;
  padding: 10px 11px;
  border-radius: 11px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid var(--sf-line-soft);
}
.sf-profile-stat span {
  font-size: 1.15rem; font-weight: 800; letter-spacing: -0.4px;
  color: var(--sf-ink); font-variant-numeric: tabular-nums;
}
.sf-profile-stat small { font-size: 10px; font-weight: 650; color: var(--sf-faint); }

@media (max-width: 719px) {
  .sf-head-actions { width: 100%; }
  .sf-head-actions :deep(.v-btn) { flex: 1 1 auto; }
  .sf-field { flex: 1 1 46%; }
  .sf-profile-stats { grid-template-columns: minmax(0, 1fr); }
}
</style>
