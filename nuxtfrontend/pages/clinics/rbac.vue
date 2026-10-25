<template>
  <v-container fluid class="pa-4 pa-md-6 rb-page">
    <!-- ═══════════════ Hero ═══════════════ -->
    <section v-if="!accessDenied" class="rb-hero" :style="heroTheme">
      <span class="rb-hero-glow" />
      <span class="rb-hero-glow rb-hero-glow-2" />

      <div class="rb-hero-main">
        <span class="rb-hero-kicker">Security · Access control</span>
        <div class="rb-hero-title">
          <span class="rb-hero-ico"><v-icon size="24">mdi-shield-account-outline</v-icon></span>
          <div>
            <h1>Roles &amp; Access</h1>
            <p>Decide exactly who may open a patient record, prescribe, run the bench, or take money — and who may not.</p>
          </div>
        </div>

        <div class="rb-hero-stats">
          <div class="rb-hero-stat">
            <b>{{ roles.length }}</b>
            <span>roles</span>
          </div>
          <div class="rb-hero-stat">
            <b>{{ members.length }}</b>
            <span>people</span>
          </div>
          <div class="rb-hero-stat">
            <b>{{ totalCapabilities }}</b>
            <span>capabilities</span>
          </div>
          <div class="rb-hero-stat">
            <b>{{ highRiskCount }}</b>
            <span>high-impact roles</span>
          </div>
        </div>
      </div>

      <div class="rb-hero-actions">
        <button type="button" class="rb-btn is-ghost" :disabled="loading" @click="load">
          <v-icon size="15">mdi-refresh</v-icon>
          <span>Refresh</span>
        </button>
        <button
          v-if="canManage"
          type="button"
          class="rb-btn is-primary"
          @click="openCreate"
        >
          <v-icon size="16">mdi-plus</v-icon>
          <span>New role</span>
        </button>
      </div>
    </section>

    <!-- Access denied -->
    <v-card v-if="accessDenied" flat rounded="xl" class="rb-denied text-center pa-10">
      <span class="rb-denied-ico">
        <v-icon size="30">mdi-shield-off-outline</v-icon>
      </span>
      <div class="text-subtitle-1 font-weight-bold mt-3">You do not have access to Roles &amp; Access</div>
      <p class="rb-denied-text">
        Role and permission management is limited to administrators. If you need
        to change what someone can do, ask a clinic administrator.
      </p>
      <NuxtLink to="/clinics/staff" class="rb-denied-link">
        <v-icon size="15">mdi-arrow-left</v-icon>
        Back to Staff &amp; Access
      </NuxtLink>
    </v-card>

    <!-- Read-only banner -->
    <v-card v-if="!accessDenied && !canManage && !loading" flat rounded="xl" class="rb-banner pa-4 mb-5">
      <v-icon color="info" size="20" class="mr-2">mdi-eye-outline</v-icon>
      <span>
        You can review roles and what each one may do, but only an administrator
        can change them.
      </span>
    </v-card>

    <!-- ═══════════════ Your access ═══════════════ -->
    <v-card v-if="!accessDenied" flat rounded="xl" class="rb-mine mb-5">
      <div class="rb-mine-head">
        <div class="rb-mine-lead">
          <span class="rb-mine-ico"><v-icon size="18">mdi-account-key-outline</v-icon></span>
          <div>
            <div class="rb-mine-title">
              Signed in as <b>{{ myRoleLabel }}</b>
            </div>
            <div class="rb-mine-sub">
              {{ myCapabilityCount }} of {{ totalCapabilities }} capabilities
              · {{ myAccessPct }}% of the clinic
            </div>
          </div>
        </div>
        <v-chip
          :color="myRisk.level === 'critical' ? 'error' : myRisk.level === 'high' ? 'warning' : myRisk.level === 'medium' ? 'info' : 'success'"
          size="small"
          variant="tonal"
          class="rb-chip"
        >
          {{ myRisk.level }} access
        </v-chip>
      </div>
      <div class="rb-mine-groups">
        <div v-for="g in myGroupCoverage" :key="g.name" class="rb-mine-group">
          <div class="rb-mine-group-top">
            <span>{{ g.name }}</span>
            <b>{{ g.granted }}/{{ g.total }}</b>
          </div>
          <div class="rb-bar">
            <span class="rb-bar-fill" :style="{ width: g.pct + '%' }" />
          </div>
        </div>
      </div>
    </v-card>

    <!-- ═══════════════ Tier filter ═══════════════ -->
    <div class="rb-toolbar mb-4">
      <div class="rb-seg">
        <button
          v-for="t in tierFilters"
          :key="t.value"
          type="button"
          class="rb-seg-btn"
          :class="{ 'is-on': tierFilter === t.value }"
          @click="tierFilter = t.value"
        >
          {{ t.label }}
          <span class="rb-seg-count">{{ t.count }}</span>
        </button>
      </div>
      <div class="rb-toolbar-right">
        <v-text-field
          v-model="roleSearch"
          prepend-inner-icon="mdi-magnify"
          placeholder="Find a role…"
          variant="outlined"
          density="compact"
          hide-details
          clearable
          rounded="lg"
          class="rb-search"
        />
      </div>
    </div>

    <!-- ═══════════════ Role cards ═══════════════ -->
    <div v-if="loading" class="rb-grid mb-6">
      <div v-for="n in 6" :key="n" class="rb-card rb-skel" />
    </div>
    <div v-else-if="!visibleRoles.length" class="rb-empty pa-10 text-center mb-6">
      <v-icon size="40" color="medium-emphasis" class="mb-2">mdi-shield-off-outline</v-icon>
      <div class="text-subtitle-1 font-weight-bold">No roles match that filter</div>
      <div class="text-body-2 text-medium-emphasis">Try a different tier or clear the search.</div>
    </div>
    <div v-else class="rb-grid mb-6">
      <article
        v-for="r in visibleRoles"
        :key="r.key"
        class="rb-card"
        :class="{ 'is-open': expandedRole === r.key }"
      >
        <header class="rb-card-head" @click="toggleRole(r.key)">
          <span class="rb-card-ico" :style="{ '--tone': tierColor(r) }">
            <v-icon size="19">{{ r.icon || 'mdi-badge-account-horizontal-outline' }}</v-icon>
          </span>
          <div class="rb-card-id">
            <div class="rb-card-name">
              {{ r.label }}
              <span v-if="r.is_custom" class="rb-flag is-custom">custom</span>
              <span v-else-if="r.is_override" class="rb-flag is-edited">edited</span>
            </div>
            <div class="rb-card-tier">{{ r.tier_label }}</div>
          </div>
          <v-icon class="rb-card-caret" size="18">mdi-chevron-down</v-icon>
        </header>

        <div class="rb-card-facts">
          <span class="rb-fact">
            <v-icon size="12">mdi-account-multiple-outline</v-icon>
            {{ r.user_count }} {{ r.user_count === 1 ? 'person' : 'people' }}
          </span>
          <span class="rb-fact">
            <v-icon size="12">mdi-key-variant</v-icon>
            {{ r.capability_count }}/{{ totalCapabilities }}
          </span>
          <span
            class="rb-fact rb-risk"
            :class="'is-' + r.risk.level"
          >
            <v-icon size="12">mdi-shield-alert-outline</v-icon>
            {{ r.risk.level }}
          </span>
        </div>

        <div class="rb-card-bar">
          <span class="rb-bar-fill" :style="{ width: r.risk.breadth_pct + '%' }" />
        </div>

        <v-expand-transition>
          <div v-if="expandedRole === r.key" class="rb-card-body">
            <p class="rb-card-desc">{{ r.description || 'No description yet.' }}</p>

            <div v-if="r.risk.critical.length" class="rb-card-warn">
              <v-icon size="14">mdi-alert-outline</v-icon>
              <div>
                <b>High-impact access:</b>
                {{ r.risk.critical.map(c => capLabel(c)).join(', ') }}
              </div>
            </div>

            <div v-if="r.users.length" class="rb-card-people">
              <span
                v-for="u in r.users.slice(0, 8)"
                :key="u.id"
                class="rb-person"
                :title="u.email"
              >
                <span class="rb-person-av">{{ u.initials }}</span>
                <span class="rb-person-name">{{ u.name }}</span>
              </span>
              <span v-if="r.users.length > 8" class="rb-person-more">
                +{{ r.users.length - 8 }} more
              </span>
            </div>
            <div v-else class="rb-card-empty">Nobody holds this role yet.</div>

            <div class="rb-card-actions">
              <button
                type="button"
                class="rb-mini"
                @click.stop="openCapabilities(r)"
              >
                <v-icon size="14">mdi-view-list-outline</v-icon>
                <span>What this role can do</span>
              </button>
              <button
                v-if="canManage && r.editable"
                type="button"
                class="rb-mini is-accent"
                @click.stop="openEdit(r)"
              >
                <v-icon size="14">mdi-pencil-outline</v-icon>
                <span>{{ r.is_custom ? 'Edit role' : 'Adjust access' }}</span>
              </button>
              <button
                v-if="canManage && r.is_override"
                type="button"
                class="rb-mini is-quiet"
                @click.stop="resetBuiltin(r)"
              >
                <v-icon size="14">mdi-restore</v-icon>
                <span>Reset to default</span>
              </button>
              <button
                v-if="canManage && r.is_custom"
                type="button"
                class="rb-mini is-danger"
                @click.stop="confirmDeleteRole(r)"
              >
                <v-icon size="14">mdi-trash-can-outline</v-icon>
                <span>Delete</span>
              </button>
            </div>
          </div>
        </v-expand-transition>
      </article>
    </div>

    <!-- ═══════════════ Members ═══════════════ -->
    <section class="rb-panel mb-6">
      <div class="rb-panel-head">
        <div>
          <div class="rb-panel-title">
            <v-icon size="17">mdi-account-group-outline</v-icon>
            People and their roles
          </div>
          <div class="rb-panel-sub">
            {{ filteredMembers.length }} of {{ members.length }} people
          </div>
        </div>
        <div class="rb-panel-tools">
          <v-text-field
            v-model="memberSearch"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search people…"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            rounded="lg"
            class="rb-search"
          />
          <v-select
            v-model="memberRoleFilter"
            :items="memberRoleOptions"
            item-title="title"
            item-value="value"
            placeholder="All roles"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            rounded="lg"
            class="rb-select"
          />
        </div>
      </div>

      <div v-if="!filteredMembers.length" class="rb-panel-empty">
        <v-icon size="30" color="medium-emphasis">mdi-account-off-outline</v-icon>
        <div>No people match this filter.</div>
      </div>
      <div v-else class="rb-table-wrap">
        <table class="rb-table">
          <thead>
            <tr>
              <th class="rb-th-num">#</th>
              <th>Person</th>
              <th>Role</th>
              <th class="rb-th-num">Capabilities</th>
              <th class="rb-th-actions" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="(m, i) in filteredMembers" :key="m.id">
              <td class="rb-td-num">{{ i + 1 }}</td>
              <td>
                <div class="rb-member">
                  <span class="rb-person-av is-lg">{{ m.initials }}</span>
                  <div class="rb-member-id">
                    <span class="rb-member-name">{{ m.name }}</span>
                    <span class="rb-member-mail">{{ m.email }}</span>
                  </div>
                </div>
              </td>
              <td>
                <span class="rb-role-chip" :style="{ '--tone': roleToneFor(m.role) }">
                  {{ roleLabelFor(m.role) }}
                </span>
                <span v-if="!roleExists(m.role)" class="rb-flag is-warn">no role</span>
              </td>
              <td class="rb-td-num">{{ roleCaps(m.role) }}</td>
              <td class="rb-td-actions">
                <v-btn
                  v-if="canManage && m.role !== 'tenant_admin' && m.id !== myUserId"
                  size="x-small"
                  variant="tonal"
                  rounded="lg"
                  class="text-none"
                  @click="openChangeRole(m)"
                >
                  Change role
                </v-btn>
                <span v-else class="rb-locked">
                  <v-icon size="12">mdi-lock-outline</v-icon>
                  locked
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ═══════════════ Capability matrix ═══════════════ -->
    <section class="rb-panel">
      <div class="rb-panel-head">
        <div>
          <div class="rb-panel-title">
            <v-icon size="17">mdi-grid-large</v-icon>
            Capability matrix
          </div>
          <div class="rb-panel-sub">
            What every role may do, grouped by clinic module. Scroll sideways for more roles.
          </div>
        </div>
        <v-switch
          v-model="matrixLive"
          label="Live capabilities"
          color="primary"
          density="compact"
          hide-details
          inset
          class="rb-switch"
        />
      </div>

      <div class="rb-matrix-scroll">
        <table class="rb-matrix">
          <thead>
            <tr>
              <th class="rb-mx-cap">Capability</th>
              <th
                v-for="r in matrixRoles"
                :key="r.key"
                class="rb-mx-role"
                :style="{ '--tone': tierColor(r) }"
                :title="r.label"
              >
                <v-icon size="15">{{ r.icon || 'mdi-badge-account-horizontal-outline' }}</v-icon>
                <span>{{ r.label }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="group in capabilityGroups" :key="group.name">
              <tr class="rb-mx-group">
                <td :colspan="matrixRoles.length + 1">
                  <v-icon size="13">mdi-folder-outline</v-icon>
                  {{ group.name }}
                  <span class="rb-mx-group-count">{{ group.capabilities.length }}</span>
                </td>
              </tr>
              <tr v-for="cap in group.capabilities" :key="cap.key" class="rb-mx-row">
                <td class="rb-mx-cap">
                  <span class="rb-mx-label">{{ cap.label }}</span>
                  <span class="rb-mx-desc">{{ cap.description }}</span>
                </td>
                <td
                  v-for="r in matrixRoles"
                  :key="r.key + cap.key"
                  class="rb-mx-cell"
                  :class="{ 'is-on': roleHasCap(r, cap.key) }"
                >
                  <v-icon v-if="roleHasCap(r, cap.key)" size="15">mdi-check</v-icon>
                  <span v-else class="rb-mx-dash">·</span>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ═══════════════ Role editor ═══════════════ -->
    <v-dialog v-model="editorOpen" max-width="820" persistent scrollable>
      <v-card rounded="xl" class="rb-dialog" :style="dialogTheme">
        <BrandDialogHeader
          :icon="editor.isCustom ? 'mdi-account-plus-outline' : 'mdi-tune-variant'"
          :title="editorTitle"
          :subtitle="editorSub"
          @close="editorOpen = false"
        >
          <div class="rb-dlg-pills">
            <span class="rb-dlg-pill">{{ selectedCaps.length }} capabilities</span>
            <span class="rb-dlg-pill" :class="'is-' + editorRisk.level">
              {{ editorRisk.level }} access
            </span>
            <span v-if="editor.isBuiltin" class="rb-dlg-pill">built-in role</span>
          </div>
        </BrandDialogHeader>

        <v-card-text class="pa-5">
          <!-- Identity (custom roles only) -->
          <div v-if="editor.isCustom" class="rb-form-block">
            <div class="rb-form-label">Role name</div>
            <v-row dense>
              <v-col cols="12" sm="7">
                <v-text-field
                  v-model="editor.label"
                  placeholder="e.g. Ward Clerk"
                  variant="outlined"
                  density="comfortable"
                  rounded="lg"
                  :error-messages="editorErrors.label"
                  @update:model-value="editorErrors.label = ''"
                />
              </v-col>
              <v-col cols="12" sm="5">
                <v-select
                  v-model="editor.icon"
                  :items="ICON_OPTIONS"
                  item-title="label"
                  item-value="value"
                  placeholder="Icon"
                  variant="outlined"
                  density="comfortable"
                  rounded="lg"
                >
                  <template #selection="{ item }">
                    <v-icon size="18" class="mr-2">{{ item.raw.value }}</v-icon>
                    <span>{{ item.raw.label }}</span>
                  </template>
                  <template #item="{ props: ip, item }">
                    <v-list-item v-bind="ip" :title="item.raw.label">
                      <template #prepend>
                        <v-icon size="20">{{ item.raw.value }}</v-icon>
                      </template>
                    </v-list-item>
                  </template>
                </v-select>
              </v-col>
            </v-row>
            <v-textarea
              v-model="editor.description"
              placeholder="What is this role for?"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              rows="2"
              hide-details
              class="mt-1"
            />
          </div>

          <!-- Capability picker -->
          <div class="rb-editor-tools">
            <div class="rb-form-label mb-0">What this role may do</div>
            <div class="rb-editor-quick">
              <button type="button" class="rb-mini" @click="grantAll">
                Select all
              </button>
              <button type="button" class="rb-mini" @click="grantNone">
                Clear
              </button>
              <button type="button" class="rb-mini" @click="grantReadOnly">
                Read-only only
              </button>
            </div>
          </div>

          <v-text-field
            v-model="capSearch"
            prepend-inner-icon="mdi-magnify"
            placeholder="Filter capabilities…"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            rounded="lg"
            class="mb-3"
          />

          <div class="rb-editor-groups">
            <div v-for="group in editorGroups" :key="group.name" class="rb-group">
              <div class="rb-group-head">
                <button type="button" class="rb-group-toggle" @click="toggleGroup(group)">
                  <v-icon size="15">
                    {{ groupAllOn(group) ? 'mdi-checkbox-marked' : groupAnyOn(group) ? 'mdi-minus-box-outline' : 'mdi-checkbox-blank-outline' }}
                  </v-icon>
                  <span>{{ group.name }}</span>
                  <span class="rb-group-count">{{ groupOnCount(group) }}/{{ group.capabilities.length }}</span>
                </button>
              </div>
              <div class="rb-group-body">
                <label
                  v-for="cap in group.capabilities"
                  :key="cap.key"
                  class="rb-cap"
                  :class="{
                    'is-on': selectedCaps.includes(cap.key),
                    'is-locked': isProtected(cap.key),
                  }"
                >
                  <input
                    type="checkbox"
                    :checked="selectedCaps.includes(cap.key)"
                    :disabled="isProtected(cap.key)"
                    @change="toggleCap(cap.key)"
                  >
                  <span class="rb-cap-body">
                    <span class="rb-cap-label">
                      {{ cap.label }}
                      <v-icon v-if="isProtected(cap.key)" size="11">mdi-lock</v-icon>
                    </span>
                    <span class="rb-cap-desc">{{ cap.description }}</span>
                  </span>
                </label>
              </div>
            </div>
            <div v-if="!editorGroups.length" class="rb-editor-empty">
              No capabilities match that filter.
            </div>
          </div>
        </v-card-text>

        <v-divider />
        <div class="rb-dialog-foot">
          <span class="rb-foot-note">
            Changes apply immediately to everyone holding this role.
          </span>
          <button type="button" class="rb-btn is-quiet" @click="editorOpen = false">
            Cancel
          </button>
          <button
            type="button"
            class="rb-btn is-primary"
            :disabled="saving || !editorValid"
            @click="saveEditor"
          >
            <v-icon size="16">{{ saving ? 'mdi-loading' : 'mdi-content-save-outline' }}</v-icon>
            <span>{{ saving ? 'Saving…' : editor.isCustom ? (editor.id ? 'Save role' : 'Create role') : 'Save access' }}</span>
          </button>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Capability preview ═══════════════ -->
    <v-dialog v-model="previewOpen" max-width="640" scrollable>
      <v-card rounded="xl" class="rb-dialog" :style="dialogTheme">
        <BrandDialogHeader
          icon="mdi-view-list-outline"
          :title="previewRole?.label || 'Role'"
          :subtitle="`${previewRole?.capability_count || 0} of ${totalCapabilities} capabilities`"
          @close="previewOpen = false"
        />
        <v-card-text class="pa-5">
          <p class="rb-preview-desc">{{ previewRole?.description }}</p>
          <div v-for="group in previewGroups" :key="group.name" class="rb-preview-group">
            <div class="rb-preview-group-name">
              <v-icon size="13">mdi-folder-outline</v-icon>
              {{ group.name }}
            </div>
            <div class="rb-preview-list">
              <span
                v-for="cap in group.capabilities"
                :key="cap.key"
                class="rb-preview-cap"
                :class="group.granted.has(cap.key) ? 'is-on' : 'is-off'"
              >
                <v-icon size="12">
                  {{ group.granted.has(cap.key) ? 'mdi-check-circle' : 'mdi-close-circle-outline' }}
                </v-icon>
                {{ cap.label }}
              </span>
            </div>
          </div>
        </v-card-text>
        <v-divider />
        <div class="rb-dialog-foot">
          <button type="button" class="rb-btn is-quiet" @click="previewOpen = false">
            Close
          </button>
          <button
            v-if="canManage && previewRole?.editable"
            type="button"
            class="rb-btn is-primary"
            @click="editFromPreview"
          >
            <v-icon size="16">mdi-pencil-outline</v-icon>
            <span>Adjust access</span>
          </button>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Change member role ═══════════════ -->
    <v-dialog v-model="changeOpen" max-width="480">
      <v-card rounded="xl" class="rb-dialog" :style="dialogTheme">
        <BrandDialogHeader
          icon="mdi-account-switch-outline"
          title="Change role"
          :subtitle="changeTarget?.name || ''"
          @close="changeOpen = false"
        />
        <v-card-text class="pa-5">
          <div class="rb-change-current">
            <span class="rb-form-label mb-0">Currently</span>
            <span class="rb-role-chip" :style="{ '--tone': roleToneFor(changeTarget?.role) }">
              {{ roleLabelFor(changeTarget?.role) }}
            </span>
          </div>
          <div class="rb-form-label mt-4">New role</div>
          <v-select
            v-model="changeRole"
            :items="assignableOptions"
            item-title="label"
            item-value="value"
            placeholder="Pick a role"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            hide-details
          >
            <template #item="{ props: ip, item }">
              <v-list-item v-bind="ip">
                <template #prepend>
                  <v-icon size="19">{{ item.raw.icon }}</v-icon>
                </template>
                <template #subtitle>
                  <span class="rb-opt-sub">{{ item.raw.tier_label }} · {{ item.raw.capability_count }} capabilities</span>
                </template>
              </v-list-item>
            </template>
          </v-select>
          <div v-if="changeImpact" class="rb-change-impact" :class="'is-' + changeImpact.tone">
            <v-icon size="15">{{ changeImpact.icon }}</v-icon>
            <span>{{ changeImpact.text }}</span>
          </div>
        </v-card-text>
        <v-divider />
        <div class="rb-dialog-foot">
          <button type="button" class="rb-btn is-quiet" @click="changeOpen = false">
            Cancel
          </button>
          <button
            type="button"
            class="rb-btn is-primary"
            :disabled="!changeRole || saving || changeRole === changeTarget?.role"
            @click="saveChangeRole"
          >
            <v-icon size="16">{{ saving ? 'mdi-loading' : 'mdi-check' }}</v-icon>
            <span>{{ saving ? 'Applying…' : 'Apply role' }}</span>
          </button>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Delete role ═══════════════ -->
    <v-dialog v-model="deleteOpen" max-width="440">
      <v-card rounded="xl" class="rb-dialog" :style="dialogTheme">
        <BrandDialogHeader
          icon="mdi-trash-can-outline"
          title="Delete this role?"
          :subtitle="deleteTarget?.label || ''"
          @close="deleteOpen = false"
        />
        <v-card-text class="pa-5">
          <p class="rb-confirm">
            Deleting <b>{{ deleteTarget?.label }}</b> cannot be undone. Anyone
            still holding it must be reassigned first.
          </p>
        </v-card-text>
        <v-divider />
        <div class="rb-dialog-foot">
          <button type="button" class="rb-btn is-quiet" @click="deleteOpen = false">
            Keep role
          </button>
          <button type="button" class="rb-btn is-danger" :disabled="saving" @click="deleteRole">
            <v-icon size="16">{{ saving ? 'mdi-loading' : 'mdi-trash-can-outline' }}</v-icon>
            <span>{{ saving ? 'Deleting…' : 'Delete role' }}</span>
          </button>
        </div>
      </v-card>
    </v-dialog>

    <!-- Toast -->
    <v-snackbar
      v-model="toast.open"
      :color="toast.tone"
      location="top right"
      rounded="lg"
      timeout="3800"
    >
      {{ toast.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
/**
 * Clinic Roles & Access.
 *
 * A clinic's access model is about the patient record: who may open it, who may
 * add to it, and who may only handle the money. This page shows that grid three
 * ways — role cards (who holds what), the people table (who is which role), and
 * the capability matrix (what each role may do) — and lets an administrator
 * reshape any non-owner role.
 */
const { $api } = useNuxtApp()
const brand = useBranding()
const auth = useAuthStore()

const loading = ref(false)
const saving = ref(false)
/** True when the API refused the matrix for this user's role. */
const accessDenied = ref(false)

const roles = ref([])
const capabilityGroups = ref([])
const tiers = ref({})
const protectedCaps = ref([])
const criticalCaps = ref([])
const sensitiveCaps = ref([])
const assignableRoles = ref([])
const canManage = ref(false)
const myRole = ref('')
const myCapabilities = ref([])
const totalCapabilities = ref(0)

const tierFilter = ref('all')
const roleSearch = ref('')
const expandedRole = ref(null)

const memberSearch = ref('')
const memberRoleFilter = ref(null)

/** Matrix can show platform defaults or this clinic's live capabilities. */
const matrixLive = ref(true)

const toast = reactive({ open: false, text: '', tone: 'success' })

const myUserId = computed(() => auth.user?.id)

/* ── Brand bridge (dialogs teleport outside .rb-page) ─────────────────── */
const heroTheme = computed(() => ({
  '--rb-deep': brand.secondary.value,
  '--rb-main': brand.primary.value,
  '--rb-accent': brand.gradientStops.value[2],
  '--rb-ink': brand.ink.value,
  '--rb-on': brand.onPrimary.value,
  '--rb-glow': brand.tint('primary', 0.3),
  '--rb-glow-2': brand.tint('accent', 0.18),
}))

const dialogTheme = computed(() => ({
  '--rb-line': 'rgba(var(--v-theme-on-surface), 0.09)',
  '--rb-line-soft': 'rgba(var(--v-theme-on-surface), 0.06)',
  '--rb-ink-text': 'rgba(var(--v-theme-on-surface), 0.94)',
  '--rb-muted': 'rgba(var(--v-theme-on-surface), 0.55)',
  '--rb-faint': 'rgba(var(--v-theme-on-surface), 0.4)',
  '--rb-main': brand.primary.value,
  '--rb-accent': brand.gradientStops.value[2],
  '--rb-on': brand.onPrimary.value,
  '--rb-glow': brand.tint('primary', 0.3),
  '--rb-glow-2': brand.tint('accent', 0.18),
}))

/* ── Derived lists ────────────────────────────────────────────────────── */
const members = computed(() => {
  const out = []
  for (const role of roles.value) {
    for (const user of role.users || []) out.push(user)
  }
  return out
})

const highRiskCount = computed(
  () => roles.value.filter(r => ['high', 'critical'].includes(r.risk?.level)).length,
)

const myRoleLabel = computed(() => {
  const match = roles.value.find(r => r.key === myRole.value)
  return match?.label || myRole.value || 'your role'
})

const myCapabilityCount = computed(() => myCapabilities.value.length)

const myAccessPct = computed(() => {
  if (!totalCapabilities.value) return 0
  return Math.round(myCapabilityCount.value / totalCapabilities.value * 100)
})

const myRisk = computed(() => rateCaps(myCapabilities.value))

/** Per-group coverage of the signed-in user, for the "your access" bars. */
const myGroupCoverage = computed(() => {
  const mine = new Set(myCapabilities.value)
  return capabilityGroups.value.map(group => {
    const granted = group.capabilities.filter(c => mine.has(c.key)).length
    const total = group.capabilities.length || 1
    return {
      name: group.name,
      granted,
      total: group.capabilities.length,
      pct: Math.round(granted / total * 100),
    }
  })
})

const tierFilters = computed(() => {
  const counts = {}
  for (const role of roles.value) counts[role.tier] = (counts[role.tier] || 0) + 1
  const out = [{ value: 'all', label: 'All roles', count: roles.value.length }]
  for (const [key, meta] of Object.entries(tiers.value)) {
    if (!counts[key]) continue
    out.push({ value: key, label: meta.label, count: counts[key] })
  }
  return out
})

const visibleRoles = computed(() => {
  const needle = roleSearch.value.trim().toLowerCase()
  return roles.value.filter(role => {
    if (tierFilter.value !== 'all' && role.tier !== tierFilter.value) return false
    if (!needle) return true
    return `${role.label} ${role.description}`.toLowerCase().includes(needle)
  })
})

const filteredMembers = computed(() => {
  const needle = memberSearch.value.trim().toLowerCase()
  return members.value.filter(member => {
    if (memberRoleFilter.value && member.role !== memberRoleFilter.value) return false
    if (!needle) return true
    return `${member.name} ${member.email}`.toLowerCase().includes(needle)
  })
})

const memberRoleOptions = computed(() => {
  const seen = new Map()
  for (const role of roles.value) {
    if (role.user_count) seen.set(role.key, role.label)
  }
  if (roles.value.some(r => r.key === myRole.value)) {
    seen.set(myRole.value, myRoleLabel.value)
  }
  return [...seen.entries()].map(([value, title]) => ({ value, title }))
})

/** Columns of the matrix — custom roles are endless; keep it readable. */
const matrixRoles = computed(() => roles.value)

/* ── Helpers ──────────────────────────────────────────────────────────── */
function capLabel(key) {
  for (const group of capabilityGroups.value) {
    const match = group.capabilities.find(c => c.key === key)
    if (match) return match.label
  }
  return key
}

function tierColor(role) {
  const palette = {
    admin: '#dc2626',
    clinical: '#2f6dff',
    nursing: '#0891b2',
    specialist: '#d97706',
    front_office: '#16a34a',
    custom: '#7c3aed',
  }
  return palette[role.tier] || '#64748b'
}

function roleLabelFor(key) {
  const match = roles.value.find(r => r.key === key)
  return match?.label || key || 'Unknown'
}

function roleToneFor(key) {
  const match = roles.value.find(r => r.key === key)
  return match ? tierColor(match) : '#94a3b8'
}

function roleExists(key) {
  return roles.value.some(r => r.key === key)
}

function roleCaps(key) {
  const match = roles.value.find(r => r.key === key)
  if (match) return match.capability_count
  if (key === myRole.value) return myCapabilityCount.value
  return 0
}

/**
 * Does a role hold a capability?
 *
 * "Live" mode reads the resolved capability list returned by the API, which
 * includes this clinic's overrides. The platform-default view uses the
 * `roles` annotation on each catalogue entry instead.
 */
function roleHasCap(role, capKey) {
  if (matrixLive.value) return (role.capabilities || []).includes(capKey)
  const entry = capabilityGroups.value
    .flatMap(g => g.capabilities)
    .find(c => c.key === capKey)
  return !!entry?.roles?.includes(role.key)
}

function toggleRole(key) {
  expandedRole.value = expandedRole.value === key ? null : key
}

function notify(text, tone = 'success') {
  toast.text = text
  toast.tone = tone
  toast.open = true
}

/* ── Load ─────────────────────────────────────────────────────────────── */
async function load() {
  loading.value = true
  accessDenied.value = false
  try {
    const { data } = await $api.get('/clinic-rbac/matrix/')
    roles.value = data.roles || []
    capabilityGroups.value = data.capability_groups || []
    tiers.value = data.tiers || {}
    protectedCaps.value = data.protected_caps || []
    criticalCaps.value = data.critical_caps || []
    sensitiveCaps.value = data.sensitive_caps || []
    assignableRoles.value = data.assignable_roles || []
    canManage.value = !!data.can_manage
    myRole.value = data.my_role || ''
    myCapabilities.value = data.my_capabilities || []
    totalCapabilities.value = data.total_capabilities || 0
  } catch (error) {
    // 403 means this user's role is not allowed to see the matrix at all —
    // that is a permission outcome, not a failure worth a red toast.
    if (error?.response?.status === 403) {
      accessDenied.value = true
    } else {
      notify('Could not load roles and access.', 'error')
    }
  }
  loading.value = false
}

/* ── Editor state ─────────────────────────────────────────────────────── */
const editorOpen = ref(false)
const editorErrors = reactive({ label: '' })
const capSearch = ref('')
const selectedCaps = ref([])

const editor = reactive({
  id: null,
  key: '',
  label: '',
  description: '',
  icon: 'mdi-badge-account-horizontal-outline',
  isCustom: false,
  isBuiltin: false,
})

const ICON_OPTIONS = [
  { value: 'mdi-badge-account-horizontal-outline', label: 'Staff' },
  { value: 'mdi-shield-crown-outline', label: 'Manager' },
  { value: 'mdi-stethoscope', label: 'Clinician' },
  { value: 'mdi-hand-heart', label: 'Nursing' },
  { value: 'mdi-test-tube', label: 'Laboratory' },
  { value: 'mdi-radiobox-marked', label: 'Radiology' },
  { value: 'mdi-pill', label: 'Pharmacy' },
  { value: 'mdi-cash-register', label: 'Cashier' },
  { value: 'mdi-deskphone', label: 'Reception' },
  { value: 'mdi-file-document-edit-outline', label: 'Records' },
]

const editorTitle = computed(() => {
  if (editor.isCustom) return editor.id ? 'Edit role' : 'New clinic role'
  return `Adjust ${editor.label}`
})

const editorSub = computed(() => {
  if (editor.isCustom) {
    return 'A role this clinic invented. It appears in the role picker for staff.'
  }
  return 'Tailor what this built-in role may do. Reset it any time to restore the platform default.'
})

const editorRisk = computed(() => rateCaps(selectedCaps.value))

/**
 * Mirror of the server's `role_risk_summary`, fed by the weights the API
 * sends, so the live preview and the saved rating can never disagree.
 */
function rateCaps(caps) {
  const set = new Set(caps || [])
  const critical = criticalCaps.value.filter(k => set.has(k)).length
  const sensitive = sensitiveCaps.value.filter(k => set.has(k)).length
  const breadth = totalCapabilities.value ? set.size / totalCapabilities.value : 0

  let score = critical * 5 + sensitive
  if (breadth >= 0.9) score += 6
  else if (breadth >= 0.75) score += 4
  else if (breadth >= 0.5) score += 1

  const level = score >= 14 ? 'critical'
    : score >= 8 ? 'high'
      : score >= 3 ? 'medium'
        : 'low'
  return { level, score, breadthPct: Math.round(breadth * 100) }
}

const editorValid = computed(() => {
  if (!selectedCaps.value.length) return false
  if (editor.isCustom) return editor.label.trim().length >= 2
  return true
})

const editorGroups = computed(() => {
  const needle = capSearch.value.trim().toLowerCase()
  if (!needle) return capabilityGroups.value
  return capabilityGroups.value
    .map(group => ({
      ...group,
      capabilities: group.capabilities.filter(c =>
        `${c.label} ${c.description} ${c.key}`.toLowerCase().includes(needle),
      ),
    }))
    .filter(group => group.capabilities.length)
})

function isProtected(key) {
  return protectedCaps.value.includes(key)
}

function toggleCap(key) {
  if (isProtected(key)) return
  const at = selectedCaps.value.indexOf(key)
  if (at === -1) selectedCaps.value.push(key)
  else selectedCaps.value.splice(at, 1)
}

function groupOnCount(group) {
  return group.capabilities.filter(c => selectedCaps.value.includes(c.key)).length
}

function groupAllOn(group) {
  return groupOnCount(group) === group.capabilities.length
}

function groupAnyOn(group) {
  return groupOnCount(group) > 0
}

/** Toggle a whole group. Protected capabilities are never removed. */
function toggleGroup(group) {
  const shouldAdd = !groupAllOn(group)
  const keys = group.capabilities.map(c => c.key)
  if (shouldAdd) {
    const next = new Set(selectedCaps.value)
    keys.forEach(k => next.add(k))
    selectedCaps.value = [...next]
    return
  }
  selectedCaps.value = selectedCaps.value.filter(
    k => !keys.includes(k) || isProtected(k),
  )
}

function grantAll() {
  const next = new Set(selectedCaps.value)
  for (const group of capabilityGroups.value) {
    for (const cap of group.capabilities) next.add(cap.key)
  }
  for (const key of protectedCaps.value) next.add(key)
  selectedCaps.value = [...next]
}

function grantNone() {
  selectedCaps.value = [...protectedCaps.value]
}

function grantReadOnly() {
  const next = new Set(protectedCaps.value)
  for (const group of capabilityGroups.value) {
    for (const cap of group.capabilities) {
      if (cap.key.endsWith('.view')) next.add(cap.key)
    }
  }
  selectedCaps.value = [...next]
}

function openCreate() {
  editor.id = null
  editor.key = ''
  editor.label = ''
  editor.description = ''
  editor.icon = 'mdi-badge-account-horizontal-outline'
  editor.isCustom = true
  editor.isBuiltin = false
  editorErrors.label = ''
  capSearch.value = ''
  selectedCaps.value = ['patient.view']
  editorOpen.value = true
}

function openEdit(role) {
  editor.id = role.id || null
  editor.key = role.key
  editor.label = role.label
  editor.description = role.description || ''
  editor.icon = role.icon || 'mdi-badge-account-horizontal-outline'
  editor.isCustom = !!role.is_custom
  editor.isBuiltin = !role.is_custom
  editorErrors.label = ''
  capSearch.value = ''
  selectedCaps.value = [...(role.capabilities || [])]
  editorOpen.value = true
}

async function saveEditor() {
  if (!editorValid.value || saving.value) return
  if (editor.isCustom && editor.label.trim().length < 2) {
    editorErrors.label = 'Give the role a name.'
    return
  }
  saving.value = true
  try {
    const payload = {
      label: editor.label.trim(),
      description: editor.description.trim(),
      icon: editor.icon,
      capabilities: [...selectedCaps.value],
    }
    if (editor.isCustom) {
      if (editor.id) {
        await $api.patch(`/clinic-rbac/roles/${editor.id}/`, payload)
        notify(`Updated "${payload.label}".`)
      } else {
        await $api.post('/clinic-rbac/roles/', payload)
        notify(`Created "${payload.label}".`)
      }
    } else {
      await $api.patch(`/clinic-rbac/builtin-roles/${editor.key}/`, {
        capabilities: payload.capabilities,
      })
      notify(`Access updated for ${editor.label}.`)
    }
    editorOpen.value = false
    await load()
  } catch (error) {
    const detail = error?.response?.data?.detail
      || error?.response?.data?.capabilities?.[0]
      || 'Could not save that role.'
    notify(detail, 'error')
  }
  saving.value = false
}

async function resetBuiltin(role) {
  saving.value = true
  try {
    await $api.delete(`/clinic-rbac/builtin-roles/${role.key}/`)
    notify(`${role.label} restored to the platform default.`)
    await load()
  } catch {
    notify('Could not reset that role.', 'error')
  }
  saving.value = false
}

/* ── Capability preview ───────────────────────────────────────────────── */
const previewOpen = ref(false)
const previewRole = ref(null)

const previewGroups = computed(() => {
  if (!previewRole.value) return []
  const granted = new Set(previewRole.value.capabilities || [])
  return capabilityGroups.value.map(group => ({ ...group, granted }))
})

function openCapabilities(role) {
  previewRole.value = role
  previewOpen.value = true
}

function editFromPreview() {
  const role = previewRole.value
  previewOpen.value = false
  if (role) openEdit(role)
}

/* ── Change a member's role ───────────────────────────────────────────── */
const changeOpen = ref(false)
const changeTarget = ref(null)
const changeRole = ref(null)

const assignableOptions = computed(() =>
  roles.value
    .filter(role => assignableRoles.value.includes(role.key))
    .map(role => ({
      value: role.key,
      label: role.label,
      icon: role.icon,
      tier_label: role.tier_label,
      capability_count: role.capability_count,
    })),
)

const changeImpact = computed(() => {
  if (!changeRole.value || !changeTarget.value) return null
  const next = roles.value.find(r => r.key === changeRole.value)
  const current = roles.value.find(r => r.key === changeTarget.value.role)
  if (!next || !current) return null
  const delta = next.capability_count - current.capability_count
  if (delta === 0) {
    return { tone: 'info', icon: 'mdi-information-outline', text: 'Same number of capabilities, different scope.' }
  }
  if (delta > 0) {
    return {
      tone: 'warning',
      icon: 'mdi-arrow-up-bold-outline',
      text: `This grants ${delta} more capabilit${delta === 1 ? 'y' : 'ies'} than their current role.`,
    }
  }
  return {
    tone: 'success',
    icon: 'mdi-arrow-down-bold-outline',
    text: `This removes ${Math.abs(delta)} capabilit${Math.abs(delta) === 1 ? 'y' : 'ies'} from their current role.`,
  }
})

function openChangeRole(member) {
  changeTarget.value = member
  changeRole.value = null
  changeOpen.value = true
}

async function saveChangeRole() {
  if (!changeTarget.value || !changeRole.value || saving.value) return
  saving.value = true
  try {
    await $api.patch(`/clinic-rbac/users/${changeTarget.value.id}/role/`, {
      role: changeRole.value,
    })
    await load()
    notify(`${changeTarget.value.name} is now ${roleLabelFor(changeRole.value)}.`)
    changeOpen.value = false
  } catch (error) {
    notify(error?.response?.data?.detail || 'Could not change that role.', 'error')
  }
  saving.value = false
}

/* ── Delete a custom role ─────────────────────────────────────────────── */
const deleteOpen = ref(false)
const deleteTarget = ref(null)

function confirmDeleteRole(role) {
  deleteTarget.value = role
  deleteOpen.value = true
}

async function deleteRole() {
  if (!deleteTarget.value || saving.value) return
  saving.value = true
  try {
    await $api.delete(`/clinic-rbac/roles/${deleteTarget.value.id}/`)
    await load()
    notify(`Deleted "${deleteTarget.value.label}".`)
    deleteOpen.value = false
  } catch (error) {
    notify(error?.response?.data?.detail || 'Could not delete that role.', 'error')
  }
  saving.value = false
}

onMounted(async () => {
  if (!brand.isLoaded.value) await brand.load()
  await load()
})
</script>

<style scoped>
/* ══ Page shell ══ */
.rb-page {
  --rb-line: rgba(var(--v-theme-on-surface), 0.09);
  --rb-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --rb-ink-text: rgba(var(--v-theme-on-surface), 0.94);
  --rb-muted: rgba(var(--v-theme-on-surface), 0.55);
  --rb-faint: rgba(var(--v-theme-on-surface), 0.4);
  --rb-surface: rgb(var(--v-theme-surface));
  --rb-raise: 0 1px 2px rgba(15, 23, 42, 0.04), 0 20px 44px -30px rgba(15, 23, 42, 0.4);
}

/* ══ Hero ══ */
.rb-hero {
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  flex-wrap: wrap;
  padding: 22px 24px 20px;
  border-radius: 20px;
  color: #fff;
  background: linear-gradient(120deg, var(--rb-deep) 0%, var(--rb-main) 54%, var(--rb-accent) 100%);
  box-shadow: var(--rb-raise);
}
.rb-hero::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(120deg, rgba(6, 12, 30, 0.05), rgba(6, 12, 30, 0.22) 58%, rgba(6, 12, 30, 0.4));
  pointer-events: none;
}
.rb-hero :deep(.v-icon) { color: currentColor; }
.rb-hero-glow {
  position: absolute;
  width: 320px; height: 320px;
  border-radius: 50%;
  filter: blur(66px);
  background: var(--rb-glow);
  top: -150px; right: -70px;
  pointer-events: none;
  z-index: 0;
}
.rb-hero-glow-2 {
  width: 240px; height: 240px;
  left: -100px; bottom: -150px; top: auto; right: auto;
  background: var(--rb-glow-2);
}
.rb-hero-main { position: relative; z-index: 1; flex: 1 1 460px; min-width: 0; }
.rb-hero-kicker {
  display: inline-block;
  margin-bottom: 9px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  opacity: 0.8;
}
.rb-hero-title { display: flex; align-items: center; gap: 13px; }
.rb-hero-ico {
  width: 46px; height: 46px;
  border-radius: 14px;
  flex-shrink: 0;
  display: grid; place-items: center;
  color: #fff;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
}
.rb-hero-ico :deep(.v-icon) { color: #fff; }
.rb-hero-title h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.5px;
  line-height: 1.2;
}
.rb-hero-title p {
  margin: 4px 0 0;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.5;
  opacity: 0.88;
  max-width: 72ch;
}
.rb-hero-stats { display: flex; gap: 24px; margin-top: 18px; flex-wrap: wrap; }
.rb-hero-stat { display: flex; flex-direction: column; line-height: 1.15; }
.rb-hero-stat b { font-size: 20px; font-weight: 800; font-variant-numeric: tabular-nums; }
.rb-hero-stat span {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  opacity: 0.72;
}
.rb-hero-actions {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

/* ══ Buttons ══ */
.rb-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 9px 15px;
  border: 0;
  border-radius: 11px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.1px;
  white-space: nowrap;
  transition: transform 0.14s ease, box-shadow 0.14s ease, background 0.14s ease;
}
.rb-btn :deep(.v-icon) { color: currentColor; }
.rb-btn:disabled { opacity: 0.55; cursor: default; }
.rb-btn.is-ghost {
  color: #fff;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.26);
}
.rb-btn.is-ghost:hover:not(:disabled) { background: rgba(255, 255, 255, 0.26); }
.rb-btn.is-primary {
  color: var(--rb-on);
  background: #fff;
  box-shadow: 0 10px 22px -14px rgba(15, 23, 42, 0.6);
}
.rb-hero .rb-btn.is-primary { color: var(--rb-ink, #0b1220); }
.rb-btn.is-primary:hover:not(:disabled) { transform: translateY(-1px); }
.rb-dialog .rb-btn.is-primary {
  color: var(--rb-on);
  background: var(--rb-main);
  box-shadow: 0 10px 22px -14px color-mix(in srgb, var(--rb-main) 80%, transparent);
}
.rb-btn.is-quiet {
  color: var(--rb-muted);
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.rb-btn.is-quiet:hover:not(:disabled) { background: rgba(var(--v-theme-on-surface), 0.1); }
.rb-btn.is-danger {
  color: #fff;
  background: #dc2626;
  box-shadow: 0 10px 22px -14px rgba(220, 38, 38, 0.8);
}

/* ══ Read-only banner ══ */
.rb-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  line-height: 1.5;
  color: var(--rb-muted);
  border: 1px solid rgba(var(--v-theme-info), 0.22) !important;
  background: rgba(var(--v-theme-info), 0.06) !important;
}

/* ══ Your access ══ */
.rb-mine {
  border: 1px solid var(--rb-line) !important;
  padding: 16px 18px;
  box-shadow: var(--rb-raise);
}
.rb-mine-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
}
.rb-mine-lead { display: flex; align-items: center; gap: 11px; min-width: 0; }
.rb-mine-ico {
  width: 38px; height: 38px;
  flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 11px;
  color: var(--rb-main);
  background: color-mix(in srgb, var(--rb-main) 11%, transparent);
}
.rb-mine-title { font-size: 13px; font-weight: 600; color: var(--rb-ink-text); }
.rb-mine-title b { font-weight: 800; }
.rb-mine-sub { font-size: 11.5px; color: var(--rb-muted); }
.rb-chip { font-weight: 800 !important; text-transform: capitalize; }
.rb-mine-groups {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 10px 18px;
  margin-top: 14px;
  padding-top: 13px;
  border-top: 1px solid var(--rb-line-soft);
}
.rb-mine-group-top {
  display: flex; align-items: baseline; justify-content: space-between;
  gap: 8px;
  margin-bottom: 4px;
  font-size: 10.5px;
  font-weight: 650;
  color: var(--rb-muted);
}
.rb-mine-group-top b { color: var(--rb-ink-text); font-variant-numeric: tabular-nums; }
.rb-bar {
  height: 5px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.rb-bar-fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--rb-main);
  transition: width 0.3s ease;
}

/* ══ Toolbar ══ */
.rb-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.rb-seg {
  display: inline-flex;
  gap: 4px;
  padding: 4px;
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.05);
  overflow-x: auto;
}
.rb-seg-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 13px;
  border: 0;
  border-radius: 9px;
  background: transparent;
  cursor: pointer;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.6);
  transition: background 0.16s ease, color 0.16s ease;
}
.rb-seg-btn.is-on {
  background: var(--rb-surface);
  color: var(--rb-main);
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.1);
}
.rb-seg-count {
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.09);
}
.rb-seg-btn.is-on .rb-seg-count {
  background: color-mix(in srgb, var(--rb-main) 14%, transparent);
  color: var(--rb-main);
}
.rb-toolbar-right { display: flex; align-items: center; gap: 8px; }
.rb-search { max-width: 250px; min-width: 180px; }
.rb-select { max-width: 190px; min-width: 150px; }

/* ══ Role cards ══ */
.rb-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(290px, 1fr));
  gap: 12px;
  align-items: start;
}
.rb-card {
  border: 1px solid var(--rb-line);
  border-radius: 16px;
  background: var(--rb-surface);
  overflow: hidden;
  transition: border-color 0.18s ease, box-shadow 0.18s ease;
}
.rb-card:hover { border-color: color-mix(in srgb, var(--rb-main) 32%, transparent); }
.rb-card.is-open {
  border-color: color-mix(in srgb, var(--rb-main) 42%, transparent);
  box-shadow: 0 14px 34px -24px rgba(15, 23, 42, 0.5);
  grid-row: span 2;
}
.rb-card-head {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 13px 14px 10px;
  cursor: pointer;
}
.rb-card-ico {
  width: 36px; height: 36px;
  flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 11px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.rb-card-id { min-width: 0; flex: 1 1 auto; }
.rb-card-name {
  display: flex; align-items: center; gap: 6px; flex-wrap: wrap;
  font-size: 13px;
  font-weight: 750;
  color: var(--rb-ink-text);
}
.rb-card-tier {
  font-size: 10.5px;
  font-weight: 600;
  color: var(--rb-faint);
}
.rb-card-caret {
  color: var(--rb-faint);
  transition: transform 0.2s ease;
}
.rb-card.is-open .rb-card-caret { transform: rotate(180deg); }
.rb-flag {
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
}
.rb-flag.is-custom {
  color: #7c3aed;
  background: rgba(124, 58, 237, 0.13);
}
.rb-flag.is-edited {
  color: #b45309;
  background: rgba(180, 83, 9, 0.13);
}
.rb-flag.is-warn {
  color: #b91c1c;
  background: rgba(185, 28, 28, 0.12);
}
.rb-card-facts {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  padding: 0 14px 9px;
}
.rb-fact {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 10.5px;
  font-weight: 650;
  color: var(--rb-muted);
  font-variant-numeric: tabular-nums;
}
.rb-risk { text-transform: capitalize; }
.rb-risk.is-critical { color: #b91c1c; }
.rb-risk.is-high { color: #b45309; }
.rb-risk.is-medium { color: #0369a1; }
.rb-risk.is-low { color: #15803d; }
.rb-card-bar {
  height: 3px;
  margin: 0 14px 12px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.rb-card-bar .rb-bar-fill { background: color-mix(in srgb, var(--rb-main) 80%, transparent); }
.rb-card-body {
  padding: 0 14px 14px;
  border-top: 1px solid var(--rb-line-soft);
}
.rb-card-desc {
  margin: 12px 0 0;
  font-size: 11.5px;
  line-height: 1.55;
  color: var(--rb-muted);
}
.rb-card-warn {
  display: flex;
  gap: 7px;
  margin-top: 10px;
  padding: 8px 10px;
  border-radius: 9px;
  font-size: 10.5px;
  line-height: 1.45;
  color: #92400e;
  background: rgba(180, 83, 9, 0.09);
  border: 1px solid rgba(180, 83, 9, 0.2);
}
.rb-card-people {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 11px;
}
.rb-person {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 9px 3px 3px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 650;
  color: var(--rb-ink-text);
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px solid var(--rb-line-soft);
}
.rb-person-av {
  width: 18px; height: 18px;
  display: grid; place-items: center;
  border-radius: 50%;
  font-size: 8.5px;
  font-weight: 800;
  color: #fff;
  background: var(--rb-main);
  flex-shrink: 0;
}
.rb-person-av.is-lg { width: 26px; height: 26px; font-size: 10px; }
.rb-person-more { font-size: 10.5px; color: var(--rb-faint); align-self: center; }
.rb-card-empty {
  margin-top: 10px;
  font-size: 10.5px;
  font-style: italic;
  color: var(--rb-faint);
}
.rb-card-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 12px;
}
.rb-mini {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 5px 10px;
  border: 1px solid var(--rb-line);
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--rb-muted);
  transition: border-color 0.14s ease, color 0.14s ease, background 0.14s ease;
}
.rb-mini:hover {
  color: var(--rb-main);
  border-color: color-mix(in srgb, var(--rb-main) 40%, transparent);
  background: color-mix(in srgb, var(--rb-main) 6%, transparent);
}
.rb-mini.is-accent { color: var(--rb-main); border-color: color-mix(in srgb, var(--rb-main) 32%, transparent); }
.rb-mini.is-danger { color: #b91c1c; border-color: rgba(185, 28, 28, 0.28); }
.rb-mini.is-danger:hover { color: #fff; background: #b91c1c; border-color: #b91c1c; }
.rb-empty {
  border: 1px dashed var(--rb-line);
  border-radius: 16px;
  background: var(--rb-surface);
}

/* ══ Access denied ══ */
.rb-denied {
  border: 1px solid var(--rb-line) !important;
  background: var(--rb-surface);
  max-width: 560px;
  margin: 40px auto;
}
.rb-denied-ico {
  display: inline-grid;
  place-items: center;
  width: 58px;
  height: 58px;
  border-radius: 18px;
  color: #b91c1c;
  background: rgba(185, 28, 28, 0.1);
}
.rb-denied-text {
  max-width: 44ch;
  margin: 8px auto 16px;
  font-size: 12.5px;
  line-height: 1.6;
  color: var(--rb-muted);
}
.rb-denied-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  color: var(--rb-main);
  text-decoration: none;
}
.rb-denied-link:hover { text-decoration: underline; }
.rb-skel {
  height: 118px;
  background: linear-gradient(100deg, rgba(var(--v-theme-on-surface), 0.03), rgba(var(--v-theme-on-surface), 0.07), rgba(var(--v-theme-on-surface), 0.03));
  background-size: 220% 100%;
  animation: rb-shimmer 1.5s infinite linear;
  border: 0;
}
@keyframes rb-shimmer {
  from { background-position: 120% 0; }
  to { background-position: -60% 0; }
}

/* ══ Panels ══ */
.rb-panel {
  border: 1px solid var(--rb-line);
  border-radius: 16px;
  background: var(--rb-surface);
  overflow: hidden;
  box-shadow: var(--rb-raise);
}
.rb-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  padding: 14px 16px;
  border-bottom: 1px solid var(--rb-line-soft);
}
.rb-panel-title {
  display: flex; align-items: center; gap: 7px;
  font-size: 13px;
  font-weight: 750;
  color: var(--rb-ink-text);
}
.rb-panel-sub { font-size: 11px; color: var(--rb-muted); margin-top: 2px; }
.rb-panel-tools { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.rb-panel-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 38px 16px;
  font-size: 12px;
  color: var(--rb-muted);
}
.rb-switch { max-width: 190px; }
.rb-switch :deep(.v-label) { font-size: 11.5px; }

/* ══ Members table ══ */
.rb-table-wrap { overflow-x: auto; }
.rb-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}
.rb-table thead th {
  padding: 9px 14px;
  text-align: left;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: var(--rb-faint);
  background: rgba(var(--v-theme-on-surface), 0.025);
  border-bottom: 1px solid var(--rb-line-soft);
  white-space: nowrap;
}
.rb-th-num, .rb-td-num { text-align: right; width: 68px; }
.rb-th-actions, .rb-td-actions { text-align: right; width: 130px; }
.rb-table tbody td {
  padding: 9px 14px;
  border-bottom: 1px solid var(--rb-line-soft);
  vertical-align: middle;
}
.rb-table tbody tr:hover td { background: rgba(var(--v-theme-on-surface), 0.025); }
.rb-table tbody tr:last-child td { border-bottom: 0; }
.rb-td-num {
  font-variant-numeric: tabular-nums;
  font-weight: 700;
  color: var(--rb-faint);
}
.rb-member { display: flex; align-items: center; gap: 9px; }
.rb-member-id { display: flex; flex-direction: column; line-height: 1.25; min-width: 0; }
.rb-member-name { font-weight: 700; color: var(--rb-ink-text); }
.rb-member-mail { font-size: 10.5px; color: var(--rb-faint); }
.rb-role-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 750;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 11%, transparent);
  border: 1px solid color-mix(in srgb, var(--tone) 24%, transparent);
}
.rb-locked {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10px;
  font-weight: 700;
  color: var(--rb-faint);
  text-transform: uppercase;
  letter-spacing: 0.4px;
}

/* ══ Matrix ══ */
.rb-matrix-scroll { overflow: auto; max-height: 680px; }
.rb-matrix {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 11.5px;
}
.rb-matrix thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  padding: 9px 8px;
  background: rgb(var(--v-theme-surface));
  border-bottom: 1px solid var(--rb-line);
}
.rb-matrix thead th.rb-mx-cap {
  left: 0;
  z-index: 3;
  text-align: left;
  padding-left: 16px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: var(--rb-faint);
  min-width: 260px;
}
.rb-mx-role {
  width: 62px;
  text-align: center;
  color: var(--tone);
  font-size: 9px;
  font-weight: 800;
  vertical-align: bottom;
}
.rb-mx-role span {
  display: block;
  margin-top: 3px;
  max-width: 62px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--rb-muted);
  font-size: 8.5px;
  font-weight: 700;
}
.rb-mx-group td {
  padding: 7px 16px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: var(--rb-main);
  background: color-mix(in srgb, var(--rb-main) 5%, transparent);
  border-bottom: 1px solid var(--rb-line-soft);
  position: sticky;
  left: 0;
}
.rb-mx-group-count {
  margin-left: 6px;
  padding: 0 5px;
  border-radius: 999px;
  font-size: 9px;
  color: var(--rb-faint);
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.rb-mx-row td { border-bottom: 1px solid var(--rb-line-soft); }
.rb-mx-row:hover td { background: rgba(var(--v-theme-on-surface), 0.022); }
.rb-mx-row td.rb-mx-cap {
  position: sticky;
  left: 0;
  z-index: 1;
  padding: 8px 16px;
  background: rgb(var(--v-theme-surface));
  max-width: 320px;
}
.rb-mx-row:hover td.rb-mx-cap { background: rgb(var(--v-theme-surface)); }
.rb-mx-label {
  display: block;
  font-weight: 650;
  color: var(--rb-ink-text);
  font-size: 11.5px;
}
.rb-mx-desc {
  display: block;
  margin-top: 1px;
  font-size: 10px;
  color: var(--rb-faint);
  line-height: 1.35;
}
.rb-mx-cell {
  text-align: center;
  color: var(--rb-faint);
}
.rb-mx-cell.is-on { color: #0d9488; }
.rb-mx-dash { opacity: 0.35; }

/* ══ Dialogs ══ */
.rb-dialog { background: rgb(var(--v-theme-surface)); }
.rb-dlg-pills {
  position: relative;
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 9px;
}
.rb-dlg-pill {
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: #fff;
  background: rgba(255, 255, 255, 0.2);
}
.rb-dlg-pill.is-high { background: rgba(251, 191, 36, 0.32); }
.rb-dlg-pill.is-critical { background: rgba(248, 113, 113, 0.36); }
.rb-dialog-foot {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid var(--rb-line-soft);
  flex-wrap: wrap;
}
.rb-foot-note {
  margin-right: auto;
  font-size: 10.5px;
  color: var(--rb-faint);
  max-width: 40ch;
  line-height: 1.4;
}
.rb-form-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.9px;
  text-transform: uppercase;
  color: var(--rb-faint);
  margin-bottom: 7px;
}
.rb-form-block { margin-bottom: 16px; }

/* ══ Editor ══ */
.rb-editor-tools {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 9px;
  padding-top: 14px;
  border-top: 1px solid var(--rb-line-soft);
}
.rb-editor-quick { display: flex; gap: 6px; flex-wrap: wrap; }
.rb-editor-groups { display: flex; flex-direction: column; gap: 10px; }
.rb-group {
  border: 1px solid var(--rb-line-soft);
  border-radius: 12px;
  overflow: hidden;
}
.rb-group-head {
  background: rgba(var(--v-theme-on-surface), 0.028);
  border-bottom: 1px solid var(--rb-line-soft);
}
.rb-group-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 8px 12px;
  border: 0;
  background: transparent;
  cursor: pointer;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.3px;
  color: var(--rb-ink-text);
}
.rb-group-toggle:hover { color: var(--rb-main); }
.rb-group-count {
  margin-left: auto;
  font-size: 10px;
  font-weight: 700;
  color: var(--rb-faint);
  font-variant-numeric: tabular-nums;
}
.rb-group-body {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 2px;
  padding: 8px;
}
.rb-cap {
  display: flex;
  gap: 8px;
  padding: 7px 9px;
  border-radius: 9px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: background 0.14s ease, border-color 0.14s ease;
}
.rb-cap:hover { background: rgba(var(--v-theme-on-surface), 0.035); }
.rb-cap.is-on {
  background: color-mix(in srgb, var(--rb-main) 7%, transparent);
  border-color: color-mix(in srgb, var(--rb-main) 22%, transparent);
}
.rb-cap.is-locked { opacity: 0.72; cursor: not-allowed; }
.rb-cap input {
  margin-top: 2px;
  accent-color: var(--rb-main);
  flex-shrink: 0;
  cursor: inherit;
}
.rb-cap-body { display: flex; flex-direction: column; line-height: 1.35; min-width: 0; }
.rb-cap-label {
  display: flex; align-items: center; gap: 4px;
  font-size: 11.5px;
  font-weight: 650;
  color: var(--rb-ink-text);
}
.rb-cap-desc { font-size: 10px; color: var(--rb-faint); }
.rb-editor-empty {
  padding: 26px;
  text-align: center;
  font-size: 12px;
  color: var(--rb-faint);
}

/* ══ Preview ══ */
.rb-preview-desc {
  margin: 0 0 14px;
  font-size: 12px;
  line-height: 1.55;
  color: var(--rb-muted);
}
.rb-preview-group { margin-bottom: 12px; }
.rb-preview-group-name {
  display: flex; align-items: center; gap: 6px;
  margin-bottom: 5px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: var(--rb-main);
}
.rb-preview-list { display: flex; flex-wrap: wrap; gap: 5px; }
.rb-preview-cap {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 650;
  border: 1px solid transparent;
}
.rb-preview-cap.is-on {
  color: #0f766e;
  background: rgba(13, 148, 136, 0.1);
  border-color: rgba(13, 148, 136, 0.22);
}
.rb-preview-cap.is-off {
  color: var(--rb-faint);
  background: rgba(var(--v-theme-on-surface), 0.03);
  text-decoration: line-through;
  text-decoration-color: rgba(var(--v-theme-on-surface), 0.2);
}

/* ══ Change role ══ */
.rb-change-current {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 9px 12px;
  border-radius: 10px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid var(--rb-line-soft);
}
.rb-opt-sub { font-size: 10px; color: var(--rb-faint); }
.rb-change-impact {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 12px;
  padding: 9px 11px;
  border-radius: 10px;
  font-size: 11.5px;
  line-height: 1.45;
}
.rb-change-impact.is-warning {
  color: #92400e;
  background: rgba(180, 83, 9, 0.09);
  border: 1px solid rgba(180, 83, 9, 0.2);
}
.rb-change-impact.is-success {
  color: #166534;
  background: rgba(22, 163, 74, 0.08);
  border: 1px solid rgba(22, 163, 74, 0.2);
}
.rb-change-impact.is-info {
  color: #0369a1;
  background: rgba(3, 105, 161, 0.08);
  border: 1px solid rgba(3, 105, 161, 0.2);
}
.rb-confirm {
  margin: 0;
  font-size: 12.5px;
  line-height: 1.55;
  color: var(--rb-muted);
}
.rb-confirm b { color: var(--rb-ink-text); }

@media (max-width: 700px) {
  .rb-grid { grid-template-columns: 1fr; }
  .rb-search, .rb-select { max-width: none; width: 100%; }
  .rb-panel-tools { width: 100%; }
}
</style>
