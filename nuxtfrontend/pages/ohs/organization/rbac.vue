<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-shield-key-outline"
      eyebrow="Security & settings · Governance"
      title="Roles & Access"
      subtitle="Who can do what across the safety management system — a live capability matrix enforced on every API request."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportMatrix">Export</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn v-if="canManage" class="ohs-btn-strong text-none" rounded="lg" size="small"
               prepend-icon="mdi-plus" @click="openCreateRole">Add role</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-shield-account</v-icon>
        <b>{{ roles.length }}</b> roles</span>
      <span class="ohs-chip"><v-icon size="12">mdi-account-multiple</v-icon>
        <b>{{ memberCount }}</b> members</span>
      <span class="ohs-chip"><v-icon size="12">mdi-key-variant</v-icon>
        <b>{{ totalCapabilities }}</b> capabilities</span>
      <span v-if="overPrivileged.length" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-shield-alert-outline</v-icon>
        <b>{{ overPrivileged.length }}</b> broad roles</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Roles" :value="roles.length" icon="mdi-shield-account-outline" tone="primary"
              :sub="`${customRoles.length} custom`" />
      <OhsKpi label="Members" :value="memberCount" icon="mdi-account-multiple-outline" tone="info"
              :sub="`${unassigned.length} unassigned`" />
      <OhsKpi label="Capabilities" :value="totalCapabilities" icon="mdi-key-variant"
              tone="primary" :sub="`${capabilityGroups.length} families`" />
      <OhsKpi label="Customised" :value="overrideCount" icon="mdi-tune-variant"
              :tone="overrideCount ? 'warn' : 'ok'" sub="roles with tenant overrides" />
      <OhsKpi label="Your access" :value="`${myCapabilityCount}/${totalCapabilities}`"
              icon="mdi-account-key-outline" tone="info" :sub="titleCase(myRole)" />
      <OhsKpi label="High-impact" :value="highImpactCount" icon="mdi-shield-alert-outline"
              :tone="highImpactCount ? 'warn' : 'ok'" sub="destructive capabilities" />
    </div>

    <v-alert v-if="!canManage" type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
      You have view-only access to roles. Only tenant administrators can change
      capabilities or reassign members.
    </v-alert>

    <!-- ═══════════ ROLE CARDS ═══════════ -->
    <OhsPanel title="Roles" subtitle="Access tiers cascade downward — each role inherits nothing from the one above"
              icon="mdi-account-switch-outline" flush>
      <template #actions>
        <v-chip-group v-model="tierFilter" mandatory selected-class="text-primary">
          <v-chip v-for="t in tierFilters" :key="t.value" :value="t.value" size="small"
                  variant="tonal" :color="t.color">{{ t.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="role-grid">
        <div v-for="r in filteredRoles" :key="r.key" class="role-card"
             :style="{ '--tier': tierColor(r) }">
          <div class="role-head">
            <span class="role-icon"><v-icon size="18">{{ r.icon }}</v-icon></span>
            <div class="role-title">
              <span class="role-name">{{ r.label }}</span>
              <span class="role-sub">
                {{ r.tier_label }}
                <span v-if="r.is_custom" class="role-flag role-flag--custom">custom</span>
                <span v-else-if="r.is_override" class="role-flag role-flag--override">customised</span>
              </span>
            </div>
            <v-menu v-if="canManage && (r.editable || r.is_custom)" location="bottom end">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="x-small"
                       density="comfortable" />
              </template>
              <v-list density="compact" class="py-1">
                <v-list-item prepend-icon="mdi-shield-edit-outline" title="Edit capabilities"
                             @click="openRoleEditor(r)" />
                <v-list-item v-if="r.is_override" prepend-icon="mdi-restore" title="Reset to defaults"
                             @click="resetRole(r)" />
                <v-divider v-if="r.is_custom" class="my-1" />
                <v-list-item v-if="r.is_custom" prepend-icon="mdi-delete-outline"
                             base-color="error" title="Delete role"
                             :disabled="r.user_count > 0" @click="confirmDeleteRole(r)" />
              </v-list>
            </v-menu>
            <v-icon v-else-if="!r.editable" size="15" color="grey" title="Platform-managed">
              mdi-lock-outline
            </v-icon>
          </div>

          <div class="role-desc">{{ r.description || 'No description.' }}</div>

          <div class="role-stats">
            <div class="rs-item">
              <span class="rs-label">Capabilities</span>
              <span class="rs-value">{{ r.capability_count }}</span>
            </div>
            <div class="rs-item">
              <span class="rs-label">Members</span>
              <span class="rs-value">{{ r.user_count }}</span>
            </div>
            <div class="rs-item">
              <span class="rs-label">Exposure</span>
              <span class="rs-value" :style="{ color: riskColor(r.risk.level) }">
                {{ titleCase(r.risk.level) }}
              </span>
            </div>
          </div>

          <div class="ohs-meter" :style="{ color: tierColor(r) }">
            <div class="ohs-meter-fill"
                 :style="{ width: Math.round(r.capability_count / totalCapabilities * 100) + '%' }" />
          </div>

          <div class="role-members">
            <span v-for="m in r.users.slice(0, 5)" :key="m.id" class="member-chip"
                  :title="m.email">{{ initialsOf(m.name) }}</span>
            <span v-if="r.user_count > 5" class="member-chip member-chip--more">
              +{{ r.user_count - 5 }}
            </span>
            <span v-if="!r.user_count" class="text-caption text-medium-emphasis">
              No members
            </span>
          </div>

          <div class="role-actions">
            <v-btn v-if="canManage" size="x-small" variant="text" class="text-none"
                   prepend-icon="mdi-account-plus-outline" @click="openAssign(r)">Assign</v-btn>
            <v-btn v-if="r.editable || r.is_custom" size="x-small" variant="text"
                   class="text-none" prepend-icon="mdi-eye-outline" @click="openRoleEditor(r, true)">
              View
            </v-btn>
          </div>
        </div>
        <div v-if="!filteredRoles.length" class="ohs-empty" style="grid-column:1/-1">
          No roles match this tier filter.
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ COVERAGE + YOUR ACCESS ═══════════ -->
    <v-row dense class="mt-1">
      <v-col cols="12" md="7">
        <OhsPanel title="Capability coverage" subtitle="How much of the platform each role can reach"
                  icon="mdi-chart-bar" class="h-100">
          <div v-for="r in coverageRows" :key="r.key" class="cov-row">
            <span class="cov-name">{{ r.label }}</span>
            <div class="ohs-meter cov-meter" :style="{ color: tierColor(r) }">
              <div class="ohs-meter-fill" :style="{ width: r.pct + '%' }" />
            </div>
            <span class="cov-count">{{ r.capability_count }}</span>
            <span class="cov-risk" :style="{ color: riskColor(r.risk.level) }">
              {{ titleCase(r.risk.level) }}
            </span>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="5">
        <OhsPanel title="Your access" :subtitle="`Signed in as ${titleCase(myRole)}`"
                  icon="mdi-account-key-outline" class="h-100">
          <div class="access-head">
            <div class="access-meter">
              <div class="ohs-meter" style="color: var(--brand-primary)">
                <div class="ohs-meter-fill" :style="{ width: myPct + '%' }" />
              </div>
            </div>
            <span class="access-figure">{{ myCapabilityCount }} / {{ totalCapabilities }}</span>
          </div>

          <div v-for="g in myGroups" :key="g.name" class="access-group">
            <div class="ag-head">
              <v-icon size="13">{{ g.icon }}</v-icon>
              <span>{{ g.name }}</span>
              <span class="ag-count">{{ g.granted }}/{{ g.total }}</span>
            </div>
            <div class="ag-meter">
              <div class="ohs-meter" :style="{ color: g.color }">
                <div class="ohs-meter-fill" :style="{ width: g.pct + '%' }" />
              </div>
            </div>
          </div>

          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            <v-icon size="13" class="mr-1">mdi-information-outline</v-icon>
            Capabilities are checked server-side on every request, so a change takes
            effect on the member's next action — no re-login needed.
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- ═══════════ MEMBER DIRECTORY ═══════════ -->
    <OhsPanel title="Member directory" :subtitle="`${filteredMembers.length} of ${memberCount} members`"
              icon="mdi-account-group-outline" flush class="mt-1">
      <div class="ohs-toolbar">
        <v-text-field v-model="memberSearch" placeholder="Search name, email…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                      rounded="lg" hide-details single-line clearable style="max-width:280px" />
        <v-select v-model="memberRoleFilter" :items="roleFilterOptions" item-title="label"
                  item-value="value" placeholder="All roles" density="compact"
                  variant="outlined" rounded="lg" hide-details clearable style="max-width:230px" />
        <v-checkbox v-model="onlyUnassigned" label="Unassigned only" density="compact"
                    hide-details class="ml-2" color="primary" />
      </div>

      <div class="ohs-scroll" style="max-height:52vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th>Member</th>
              <th style="width:230px">Role</th>
              <th style="width:150px">Tier</th>
              <th style="width:110px">Access</th>
              <th style="width:78px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in filteredMembers" :key="m.id">
              <td>
                <div class="d-flex align-center" style="gap:9px">
                  <span class="mem-avatar" :style="avatarStyle(m)">{{ initialsOf(m.name) }}</span>
                  <span class="mem-id">
                    <span class="mem-name">{{ m.name }}</span>
                    <span class="mem-mail">{{ m.email }}</span>
                  </span>
                </div>
              </td>
              <td>
                <span class="ohs-badge" :class="roleBadge(m.role)">
                  {{ roleLabel(m.role) }}
                </span>
                <span v-if="!roleKnown(m.role)" class="text-caption ml-1" style="color:#b45309">
                  unmapped
                </span>
              </td>
              <td class="text-caption">{{ tierLabelFor(m.role) }}</td>
              <td>
                <span class="cap-pill">{{ capsFor(m.role) }} caps</span>
              </td>
              <td class="text-right">
                <v-btn v-if="canManage && m.role !== 'tenant_admin' && m.role !== 'super_admin'"
                       size="x-small" variant="tonal" color="primary" rounded="lg"
                       class="text-none" @click="openChangeRole(m)">Change</v-btn>
                <v-icon v-else-if="canManage" size="14" color="grey">mdi-lock-outline</v-icon>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filteredMembers.length" class="ohs-empty">No members match these filters.</div>
      </div>
    </OhsPanel>

    <!-- ═══════════ CAPABILITY MATRIX ═══════════ -->
    <OhsPanel title="Capability matrix" subtitle="Every capability, every role — click a cell to jump to that role"
              icon="mdi-table-large" flush class="mt-1">
      <template #actions>
        <v-text-field v-model="capSearch" placeholder="Filter capabilities…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                      rounded="lg" hide-details single-line clearable
                      style="max-width:240px" />
      </template>

      <div class="ohs-scroll" style="max-height:66vh">
        <table class="matrix-table">
          <thead>
            <tr>
              <th class="mx-cap">Capability</th>
              <th v-for="r in roles" :key="r.key" class="mx-role"
                  :title="`${r.label} — ${r.capability_count} capabilities`">
                <span class="mx-role-label">{{ r.label }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="g in visibleGroups" :key="g.name">
              <tr class="mx-group">
                <td :colspan="roles.length + 1">
                  <v-icon size="13" class="mr-1">{{ groupIcon(g.name) }}</v-icon>
                  {{ g.name }}
                  <span class="mx-group-count">{{ g.grantedByGroup }}/{{ g.capabilities.length * roles.length }}</span>
                </td>
              </tr>
              <tr v-for="c in g.capabilities" :key="c.key">
                <td class="mx-cap">
                  <div class="mx-cap-label">{{ c.label }}</div>
                  <div class="mx-cap-desc">{{ c.description }}</div>
                </td>
                <td v-for="r in roles" :key="r.key" class="mx-cell"
                    :class="{ 'mx-cell--on': hasCap(r, c.key) }"
                    @click="scrollToRole(r.key)">
                  <v-icon v-if="hasCap(r, c.key)" size="15" class="mx-check">
                    mdi-check-circle
                  </v-icon>
                  <span v-else class="mx-dash">—</span>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
        <div v-if="!visibleGroups.length" class="ohs-empty">
          No capabilities match "{{ capSearch }}".
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ ROLE EDITOR ═══════════ -->
    <v-dialog v-model="editorDialog" max-width="880" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editorMode === 'create' ? 'mdi-shield-plus-outline' : 'mdi-shield-edit-outline'"
          :title="editorMode === 'create' ? 'Create a role' : `Edit ${editorRole?.label}`"
          :subtitle="editorReadOnly
            ? 'Read-only — you do not have permission to change capabilities.'
            : `${editorForm.capabilities.length} of ${totalCapabilities} capabilities selected`" />

        <v-card-text>
          <v-row v-if="editorMode === 'create'" dense class="mb-2">
            <v-col cols="12" sm="7">
              <v-text-field v-model="editorForm.label" label="Role name" variant="outlined"
                            density="compact" rounded="lg"
                            hint="Max 20 characters for the key" persistent-hint
                            :disabled="editorReadOnly" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-select v-model="editorForm.icon" :items="ICON_OPTIONS" item-title="label"
                        item-value="value" label="Icon" variant="outlined"
                        density="compact" rounded="lg" :disabled="editorReadOnly" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="editorForm.description" label="Description"
                            variant="outlined" density="compact" rounded="lg"
                            :disabled="editorReadOnly" />
            </v-col>
          </v-row>

          <div class="editor-toolbar">
            <v-text-field v-model="editorSearch" placeholder="Filter capabilities…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                          rounded="lg" hide-details single-line clearable
                          style="max-width:250px" />
            <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-check-all"
                   :disabled="editorReadOnly" @click="selectAllVisible">Select visible</v-btn>
            <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-close-box-outline"
                   :disabled="editorReadOnly" @click="editorForm.capabilities = []">Clear all</v-btn>
            <v-spacer />
            <v-chip v-if="editorRisk" size="small" variant="tonal"
                    :color="riskChip(editorRisk.level)">
              {{ titleCase(editorRisk.level) }} exposure
            </v-chip>
          </div>

          <div class="editor-groups">
            <div v-for="g in editorGroups" :key="g.name" class="egroup">
              <div class="egroup-head">
                <v-icon size="14" class="mr-1">{{ groupIcon(g.name) }}</v-icon>
                <span class="egroup-name">{{ g.name }}</span>
                <span class="egroup-count">{{ g.selected }}/{{ g.capabilities.length }}</span>
                <v-spacer />
                <v-btn size="x-small" variant="text" class="text-none"
                       :disabled="editorReadOnly" @click="toggleGroup(g)">
                  {{ g.selected === g.capabilities.length ? 'None' : 'All' }}
                </v-btn>
              </div>
              <div class="egroup-body">
                <label v-for="c in g.capabilities" :key="c.key" class="cap-item"
                       :class="{ 'cap-item--on': editorForm.capabilities.includes(c.key) }">
                  <v-checkbox-btn :model-value="editorForm.capabilities.includes(c.key)"
                                  :disabled="editorReadOnly || editorLocked(c.key)"
                                  color="primary" density="compact"
                                  @update:model-value="toggleCap(c.key)" />
                  <span class="cap-text">
                    <span class="cap-label">{{ c.label }}</span>
                    <span class="cap-desc">{{ c.description }}</span>
                  </span>
                  <v-icon v-if="editorLocked(c.key)" size="13" color="grey"
                          title="Required — cannot be removed">mdi-lock-outline</v-icon>
                </label>
              </div>
            </div>
          </div>

          <v-alert v-if="editorError" type="error" variant="tonal" density="compact"
                   rounded="lg" class="mt-3">{{ editorError }}</v-alert>
        </v-card-text>

        <v-card-actions class="px-4 pb-4">
          <span v-if="editorRole?.is_override" class="text-caption text-medium-emphasis">
            This role has a tenant override — reset it to return to platform defaults.
          </span>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="editorDialog = false">
            {{ editorReadOnly ? 'Close' : 'Cancel' }}
          </v-btn>
          <v-btn v-if="!editorReadOnly" color="primary" rounded="lg" class="text-none"
                 :loading="saving" :disabled="!editorValid" @click="saveRole">
            {{ editorMode === 'create' ? 'Create role' : 'Save capabilities' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ CHANGE MEMBER ROLE ═══════════ -->
    <v-dialog v-model="assignDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-switch-outline" title="Change member role"
                           :subtitle="assignTarget?.name || ''" />
        <v-card-text>
          <div class="current-role mb-3">
            <span class="text-caption text-medium-emphasis">Current role</span>
            <span class="ohs-badge" :class="roleBadge(assignTarget?.role)">
              {{ roleLabel(assignTarget?.role) }}
            </span>
          </div>
          <v-select v-model="newRole" :items="roleFilterOptions" item-title="label"
                    item-value="value" label="New role" variant="outlined"
                    density="compact" rounded="lg" />
          <v-alert v-if="newRole && newRole === assignTarget?.role" type="info" variant="tonal"
                   density="compact" rounded="lg" class="mt-2">
            That is already this member's role.
          </v-alert>
          <v-alert type="warning" variant="tonal" density="compact" rounded="lg" class="mt-2">
            The change applies to their next request. Their current session stays signed in.
          </v-alert>
          <v-alert v-if="assignError" type="error" variant="tonal" density="compact"
                   rounded="lg" class="mt-2">{{ assignError }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 :disabled="!newRole || newRole === assignTarget?.role" @click="saveAssign">
            Update role
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ DELETE ROLE ═══════════ -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-shield-remove-outline" title="Delete role"
                           :subtitle="deleteTarget?.label || ''" />
        <v-card-text>
          <div class="text-body-2">
            <b>{{ deleteTarget?.label }}</b> will be removed and its capability grants
            discarded. Members who held it must be reassigned first.
          </div>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="saving"
                 @click="deleteRole">Delete role</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2800">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Roles & Access · OHSMS' })

const { $api } = useNuxtApp()

const data = ref({
  roles: [], custom_roles: [], capability_groups: [], assignable_roles: [],
  members: [], unassigned: [], can_manage: false, my_role: '', my_capabilities: [],
  my_capability_count: 0, total_capabilities: 0, protected_caps: [], tiers: {},
})

const loading = ref(false)
const saving = ref(false)
const tierFilter = ref('all')
const memberSearch = ref('')
const memberRoleFilter = ref(null)
const onlyUnassigned = ref(false)
const capSearch = ref('')

const editorDialog = ref(false)
const editorMode = ref('edit')
const editorRole = ref(null)
const editorReadOnly = ref(false)
const editorSearch = ref('')
const editorError = ref('')
const editorForm = reactive({ label: '', description: '', icon: '', capabilities: [] })

const assignDialog = ref(false)
const assignTarget = ref(null)
const newRole = ref(null)
const assignError = ref('')

const deleteDialog = ref(false)
const deleteTarget = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })

const ICON_OPTIONS = [
  { value: 'mdi-shield-account', label: 'Shield (admin)' },
  { value: 'mdi-shield-crown-outline', label: 'Crown shield (lead)' },
  { value: 'mdi-shield-check', label: 'Shield check (officer)' },
  { value: 'mdi-shield-half-full', label: 'Shield half (partial)' },
  { value: 'mdi-medical-bag', label: 'Medical bag (health)' },
  { value: 'mdi-account-tie-outline', label: 'Tie (supervisor)' },
  { value: 'mdi-hard-hat', label: 'Hard hat (field)' },
  { value: 'mdi-clipboard-check-outline', label: 'Clipboard (inspector)' },
  { value: 'mdi-flask-outline', label: 'Flask (hygiene)' },
  { value: 'mdi-badge-account-horizontal-outline', label: 'Badge (generic)' },
]

const GROUP_ICONS = {
  'Hazards & risk': 'mdi-alert-outline',
  Incidents: 'mdi-alert-circle-outline',
  'Inspections & permits': 'mdi-clipboard-check-outline',
  'Safety equipment': 'mdi-fire-extinguisher',
  'Observations & drills': 'mdi-eye-check-outline',
  'Health & exposure': 'mdi-heart-pulse',
  'Training & PPE': 'mdi-school-outline',
  Documents: 'mdi-file-document-multiple-outline',
  Contractors: 'mdi-account-hard-hat',
  Governance: 'mdi-gavel',
  Administration: 'mdi-cog-outline',
}
const GROUP_COLORS = {
  'Hazards & risk': '#dc2626',
  Incidents: '#ea580c',
  'Inspections & permits': '#0284c7',
  'Safety equipment': '#f43f5e',
  'Observations & drills': '#65a30d',
  'Health & exposure': '#be123c',
  'Training & PPE': '#0d9488',
  Documents: '#6366f1',
  Contractors: '#b45309',
  Governance: '#475569',
  Administration: '#7c3aed',
}

const TIER_HEX = {
  admin: '#dc2626', officer: '#f59e0b', specialist: '#0284c7',
  field: '#16a34a', custom: '#6366f1',
}

// ── derived ─────────────────────────────────────────────────────────────
const roles = computed(() => data.value.roles || [])
const customRoles = computed(() => data.value.custom_roles || [])
const capabilityGroups = computed(() => data.value.capability_groups || [])
const canManage = computed(() => !!data.value.can_manage)
const myRole = computed(() => data.value.my_role || '')
const myCapabilities = computed(() => data.value.my_capabilities || [])
const myCapabilityCount = computed(() => data.value.my_capability_count || 0)
const totalCapabilities = computed(() => data.value.total_capabilities || 1)
const protectedCaps = computed(() => new Set(data.value.protected_caps || []))
const unassigned = computed(() => data.value.unassigned || [])
const myPct = computed(() => Math.round(myCapabilityCount.value / totalCapabilities.value * 100))

const allMembers = computed(() => {
  const out = []
  for (const r of roles.value) out.push(...(r.users || []))
  return out
})
const memberCount = computed(() => allMembers.value.length)
const overrideCount = computed(() => roles.value.filter((r) => r.is_override).length)
const overPrivileged = computed(() =>
  roles.value.filter((r) => ['critical', 'high'].includes(r.risk?.level)))
const highImpactCount = computed(() =>
  capabilityGroups.value
    .flatMap((g) => g.capabilities)
    .filter((c) => /delete|approve|manage/.test(c.key)).length)

const tierFilters = computed(() => [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Administrator', value: 'admin', color: 'error' },
  { label: 'Officer', value: 'officer', color: 'warning' },
  { label: 'Specialist', value: 'specialist', color: 'info' },
  { label: 'Field', value: 'field', color: 'success' },
  { label: 'Custom', value: 'custom', color: 'primary' },
])

const filteredRoles = computed(() => roles.value.filter((r) =>
  tierFilter.value === 'all' || r.tier === tierFilter.value))

const coverageRows = computed(() =>
  [...roles.value].sort((a, b) => b.capability_count - a.capability_count)
    .map((r) => ({ ...r, pct: Math.round(r.capability_count / totalCapabilities.value * 100) })))

const roleFilterOptions = computed(() =>
  roles.value.map((r) => ({ value: r.key, label: r.label })))

const filteredMembers = computed(() => allMembers.value.filter((m) => {
  if (onlyUnassigned.value && roleKnown(m.role)) return false
  if (memberRoleFilter.value && m.role !== memberRoleFilter.value) return false
  const q = memberSearch.value.trim().toLowerCase()
  if (q && !`${m.name} ${m.email} ${m.role}`.toLowerCase().includes(q)) return false
  return true
}))

const myGroups = computed(() =>
  capabilityGroups.value.map((g) => {
    const granted = g.capabilities.filter((c) => myCapabilities.value.includes(c.key)).length
    const total = g.capabilities.length || 1
    return {
      name: g.name,
      granted,
      total: g.capabilities.length,
      pct: Math.round(granted / total * 100),
      color: GROUP_COLORS[g.name] || '#64748b',
      icon: GROUP_ICONS[g.name] || 'mdi-circle-outline',
    }
  }).filter((g) => g.total > 0))

const visibleGroups = computed(() => {
  const q = capSearch.value.trim().toLowerCase()
  return capabilityGroups.value
    .map((g) => {
      const caps = q
        ? g.capabilities.filter((c) =>
            `${c.label} ${c.description} ${c.key}`.toLowerCase().includes(q))
        : g.capabilities
      const grantedByGroup = caps.reduce((sum, c) =>
        sum + roles.value.filter((r) => hasCap(r, c.key)).length, 0)
      return { ...g, capabilities: caps, grantedByGroup }
    })
    .filter((g) => g.capabilities.length)
})

const editorGroups = computed(() => {
  const q = editorSearch.value.trim().toLowerCase()
  return capabilityGroups.value
    .map((g) => {
      const caps = q
        ? g.capabilities.filter((c) =>
            `${c.label} ${c.description} ${c.key}`.toLowerCase().includes(q))
        : g.capabilities
      return {
        ...g,
        capabilities: caps,
        selected: caps.filter((c) => editorForm.capabilities.includes(c.key)).length,
      }
    })
    .filter((g) => g.capabilities.length)
})

const editorRisk = computed(() => {
  const caps = new Set(editorForm.capabilities)
  const critical = ['hazard.delete', 'rbac.manage', 'org.manage', 'health.manage',
    'document.approve', 'risk.approve', 'incident.close']
  const hits = [...caps].filter((c) => critical.includes(c)).length
  const breadth = caps.size / totalCapabilities.value
  if (hits >= 4 || breadth >= 0.9) return { level: 'critical' }
  if (hits || breadth >= 0.6) return { level: 'high' }
  if (breadth >= 0.35) return { level: 'medium' }
  return { level: 'low' }
})

const editorValid = computed(() => {
  if (!editorForm.capabilities.length) return false
  if (editorMode.value === 'create' && !editorForm.label.trim()) return false
  return true
})

// ── helpers ─────────────────────────────────────────────────────────────
function hasCap(role, key) {
  return (role.capabilities || []).includes(key)
}
function roleKnown(key) {
  return roles.value.some((r) => r.key === key)
}
function roleLabel(key) {
  return roles.value.find((r) => r.key === key)?.label || titleCase(key)
}
function roleBadge(key) {
  const tier = roles.value.find((r) => r.key === key)?.tier
  return {
    admin: 'ohs-badge--err', officer: 'ohs-badge--warn', specialist: 'ohs-badge--info',
    field: 'ohs-badge--ok', custom: 'ohs-badge--info',
  }[tier] || 'ohs-badge--muted'
}
function tierLabelFor(key) {
  return roles.value.find((r) => r.key === key)?.tier_label || '—'
}
function tierColor(r) {
  return TIER_HEX[r?.tier] || '#64748b'
}
function capsFor(key) {
  return roles.value.find((r) => r.key === key)?.capability_count ?? 0
}
function riskColor(level) {
  return { critical: '#dc2626', high: '#ea580c', medium: '#b45309', low: '#16a34a' }[level]
    || '#64748b'
}
function riskChip(level) {
  return { critical: 'error', high: 'deep-orange', medium: 'warning', low: 'success' }[level]
    || 'grey'
}
function groupIcon(name) {
  return GROUP_ICONS[name] || 'mdi-circle-outline'
}
function avatarStyle(m) {
  const tier = roles.value.find((r) => r.key === m.role)?.tier || 'custom'
  const color = TIER_HEX[tier] || '#64748b'
  return { background: `${color}22`, color }
}
function scrollToRole(key) {
  const el = document.querySelector(`[data-role-key="${key}"]`)
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

// ── data ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data: d } = await $api.get('/ohs/rbac/')
    data.value = d
  } catch (e) {
    snack.value = {
      show: true, color: 'error',
      text: e?.response?.data?.detail || 'Could not load roles & access.',
    }
  } finally {
    loading.value = false
  }
}

function openCreateRole() {
  editorMode.value = 'create'
  editorRole.value = null
  editorReadOnly.value = false
  editorError.value = ''
  editorSearch.value = ''
  Object.assign(editorForm, {
    label: '', description: '', icon: 'mdi-shield-half-full', capabilities: [],
  })
  editorDialog.value = true
}

function openRoleEditor(role, readOnly = false) {
  editorMode.value = 'edit'
  editorRole.value = role
  editorReadOnly.value = readOnly || !canManage.value
  editorError.value = ''
  editorSearch.value = ''
  Object.assign(editorForm, {
    label: role.label,
    description: role.description || '',
    icon: role.icon,
    capabilities: [...(role.capabilities || [])],
  })
  editorDialog.value = true
}

function editorLocked(key) {
  return roleKnown(editorRole.value?.key) && protectedCaps.value.has(key)
    && editorForm.capabilities.includes(key)
}

function toggleCap(key) {
  if (editorReadOnly.value) return
  if (editorLocked(key)) return
  const i = editorForm.capabilities.indexOf(key)
  if (i >= 0) editorForm.capabilities.splice(i, 1)
  else editorForm.capabilities.push(key)
}

function toggleGroup(g) {
  if (editorReadOnly.value) return
  const all = g.selected === g.capabilities.length
  for (const c of g.capabilities) {
    if (editorLocked(c.key)) continue
    const i = editorForm.capabilities.indexOf(c.key)
    if (all && i >= 0) editorForm.capabilities.splice(i, 1)
    if (!all && i < 0) editorForm.capabilities.push(c.key)
  }
}

function selectAllVisible() {
  if (editorReadOnly.value) return
  for (const g of editorGroups.value) {
    for (const c of g.capabilities) {
      if (!editorForm.capabilities.includes(c.key)) editorForm.capabilities.push(c.key)
    }
  }
}

async function saveRole() {
  editorError.value = ''
  saving.value = true
  try {
    if (editorMode.value === 'create') {
      await $api.post('/ohs/rbac/roles/', {
        label: editorForm.label,
        description: editorForm.description,
        icon: editorForm.icon,
        capabilities: editorForm.capabilities,
      })
      snack.value = { show: true, color: 'success', text: 'Role created.' }
    } else if (editorRole.value.is_custom) {
      await $api.patch(`/ohs/rbac/roles/${editorRole.value.id}/`, {
        label: editorForm.label,
        description: editorForm.description,
        icon: editorForm.icon,
        capabilities: editorForm.capabilities,
      })
      snack.value = { show: true, color: 'success', text: 'Role updated.' }
    } else {
      await $api.patch(`/ohs/rbac/builtin-roles/${editorRole.value.key}/`, {
        capabilities: editorForm.capabilities,
      })
      snack.value = {
        show: true, color: 'success',
        text: `${editorRole.value.label} capabilities updated.`,
      }
    }
    editorDialog.value = false
    await load()
  } catch (e) {
    editorError.value = apiMessage(e)
  } finally {
    saving.value = false
  }
}

async function resetRole(role) {
  try {
    await $api.delete(`/ohs/rbac/builtin-roles/${role.key}/`)
    snack.value = {
      show: true, color: 'success',
      text: `${role.label} reset to platform defaults.`,
    }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: apiMessage(e) }
  }
}

function confirmDeleteRole(role) {
  deleteTarget.value = role
  deleteDialog.value = true
}

async function deleteRole() {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    await $api.delete(`/ohs/rbac/roles/${deleteTarget.value.id}/`)
    deleteDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Role deleted.' }
    await load()
  } catch (e) {
    deleteDialog.value = false
    snack.value = { show: true, color: 'error', text: apiMessage(e) }
  } finally {
    saving.value = false
  }
}

function openAssign(role) {
  const member = (role.users || [])[0]
  if (member) openChangeRole(member)
  else snack.value = {
    show: true, color: 'info',
    text: 'Pick a member from the directory to assign this role.',
  }
}

function openChangeRole(member) {
  assignTarget.value = member
  newRole.value = member.role
  assignError.value = ''
  assignDialog.value = true
}

async function saveAssign() {
  if (!assignTarget.value || !newRole.value) return
  assignError.value = ''
  saving.value = true
  try {
    await $api.patch(`/ohs/rbac/users/${assignTarget.value.id}/role/`, {
      role: newRole.value,
    })
    assignDialog.value = false
    snack.value = {
      show: true, color: 'success',
      text: `${assignTarget.value.name} is now ${roleLabel(newRole.value)}.`,
    }
    await load()
  } catch (e) {
    assignError.value = apiMessage(e)
  } finally {
    saving.value = false
  }
}

function apiMessage(e) {
  const d = e?.response?.data
  if (d && typeof d === 'object' && !d.detail) {
    return Object.entries(d)
      .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`)
      .join(' | ')
  }
  return d?.detail || e?.message || 'Request failed.'
}

function exportMatrix() {
  const rows = []
  for (const g of capabilityGroups.value) {
    for (const c of g.capabilities) {
      const row = { Group: g.name, Capability: c.label, Key: c.key }
      for (const r of roles.value) row[r.label] = hasCap(r, c.key) ? 'Yes' : ''
      rows.push(row)
    }
  }
  const cols = [
    { key: 'Group', label: 'Group' },
    { key: 'Capability', label: 'Capability' },
    { key: 'Key', label: 'Key' },
    ...roles.value.map((r) => ({ key: r.label, label: r.label })),
  ]
  exportCsv(`ohsms_rbac_matrix_${new Date().toISOString().slice(0, 10)}.csv`, rows, cols)
}

onMounted(load)
</script>

<style scoped>
/* ── role cards ────────────────────────────────────────────────────── */
.role-grid {
  display: grid; gap: 10px; padding: 12px;
  grid-template-columns: repeat(auto-fill, minmax(272px, 1fr));
}
.role-card {
  position: relative; padding: 12px 13px 10px; border-radius: 13px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-top: 3px solid var(--tier, #64748b);
  transition: box-shadow .16s ease, transform .16s ease;
}
.role-card:hover { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(15, 23, 42, .08); }
.role-head { display: flex; align-items: flex-start; gap: 9px; }
.role-icon {
  width: 30px; height: 30px; border-radius: 9px; flex: 0 0 auto;
  display: grid; place-items: center;
  background: color-mix(in srgb, var(--tier, #64748b) 14%, transparent);
  color: var(--tier, #64748b);
}
.role-title { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.role-name {
  font-size: 12.5px; font-weight: 700; line-height: 1.2;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.role-sub {
  font-size: 10px; color: rgba(var(--v-theme-on-surface), .55);
  display: flex; align-items: center; gap: 5px;
}
.role-flag {
  font-size: 8.5px; font-weight: 800; letter-spacing: .4px;
  text-transform: uppercase; padding: 1px 5px; border-radius: 4px;
}
.role-flag--custom { background: rgba(99, 102, 241, .16); color: #4338ca; }
.role-flag--override { background: rgba(245, 158, 11, .18); color: #b45309; }
.role-desc {
  font-size: 10.5px; line-height: 1.35; color: rgba(var(--v-theme-on-surface), .6);
  margin: 7px 0 9px; min-height: 42px;
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;
}
.role-stats { display: flex; gap: 10px; margin-bottom: 7px; }
.rs-item { display: flex; flex-direction: column; gap: 0; }
.rs-label {
  font-size: 8.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.rs-value { font-size: 12px; font-weight: 800; font-variant-numeric: tabular-nums; }
.role-members {
  display: flex; align-items: center; gap: 3px; flex-wrap: wrap;
  margin-top: 8px; min-height: 24px;
}
.member-chip {
  width: 23px; height: 23px; border-radius: 7px;
  display: grid; place-items: center;
  font-size: 9px; font-weight: 800;
  background: rgba(15, 23, 42, .06);
  color: rgba(var(--v-theme-on-surface), .7);
}
.member-chip--more { background: rgba(15, 23, 42, .1); }
.role-actions {
  display: flex; gap: 2px; margin-top: 6px;
  border-top: 1px solid rgba(15, 23, 42, .06); padding-top: 4px;
}

/* ── coverage ──────────────────────────────────────────────────────── */
.cov-row { display: flex; align-items: center; gap: 9px; padding: 4px 0; }
.cov-name {
  flex: 0 0 158px; font-size: 11.5px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cov-meter { flex: 1 1 auto; }
.cov-count {
  font-size: 11.5px; font-weight: 800; min-width: 22px; text-align: right;
  font-variant-numeric: tabular-nums;
}
.cov-risk {
  font-size: 10px; font-weight: 700; min-width: 52px; text-align: right;
  text-transform: uppercase; letter-spacing: .3px;
}

/* ── your access ───────────────────────────────────────────────────── */
.access-head { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.access-meter { flex: 1; }
.access-figure {
  font-size: 13px; font-weight: 800; font-variant-numeric: tabular-nums;
}
.access-group { margin-bottom: 7px; }
.ag-head {
  display: flex; align-items: center; gap: 5px;
  font-size: 10.5px; font-weight: 600; margin-bottom: 3px;
  color: rgba(var(--v-theme-on-surface), .72);
}
.ag-count {
  margin-left: auto; font-size: 10px; font-weight: 700;
  color: rgba(var(--v-theme-on-surface), .5);
  font-variant-numeric: tabular-nums;
}

/* ── member directory ──────────────────────────────────────────────── */
.mem-avatar {
  width: 28px; height: 28px; border-radius: 8px;
  display: grid; place-items: center; flex: 0 0 auto;
  font-size: 10px; font-weight: 800;
}
.mem-id { display: flex; flex-direction: column; min-width: 0; }
.mem-name {
  font-size: 12.5px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 240px;
}
.mem-mail {
  font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 240px;
}
.cap-pill {
  display: inline-block; padding: 1px 7px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700;
  background: rgba(15, 23, 42, .06); color: rgba(var(--v-theme-on-surface), .65);
}

/* ── capability matrix ─────────────────────────────────────────────── */
.matrix-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 11.5px; }
.matrix-table thead th {
  position: sticky; top: 0; z-index: 2;
  padding: 7px 6px; text-align: left;
  background: rgb(var(--v-theme-surface));
  border-bottom: 1px solid rgba(15, 23, 42, .1);
  font-size: 10px; font-weight: 800; letter-spacing: .3px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55);
}
.matrix-table thead th.mx-role {
  text-align: center; width: 74px; vertical-align: bottom;
}
.mx-role-label {
  display: block; font-size: 9px; line-height: 1.15;
  writing-mode: vertical-rl; transform: rotate(180deg);
  height: 84px; margin: 0 auto; white-space: nowrap;
}
.mx-group td {
  padding: 6px 8px; background: rgba(15, 23, 42, .035);
  font-size: 9.5px; font-weight: 800; letter-spacing: .5px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .6);
}
.mx-group-count { float: right; font-weight: 700; }
.mx-cap { padding: 5px 8px; border-bottom: 1px solid rgba(15, 23, 42, .05); }
.mx-cap-label { font-size: 11.5px; font-weight: 600; }
.mx-cap-desc {
  font-size: 9.5px; line-height: 1.25; color: rgba(var(--v-theme-on-surface), .5);
  max-width: 420px;
}
.mx-cell {
  text-align: center; cursor: pointer; padding: 5px 4px;
  border-bottom: 1px solid rgba(15, 23, 42, .05);
  transition: background .12s ease;
}
.mx-cell--on { background: rgba(22, 163, 74, .06); }
.mx-cell:hover { background: rgba(var(--v-theme-primary), .1); }
.mx-check { color: #16a34a; }
.mx-dash { color: rgba(var(--v-theme-on-surface), .18); font-size: 12px; }

/* ── role editor ───────────────────────────────────────────────────── */
.editor-toolbar {
  display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 10px;
}
.editor-groups { display: flex; flex-direction: column; gap: 9px; }
.egroup {
  border: 1px solid rgba(15, 23, 42, .08); border-radius: 11px; overflow: hidden;
}
.egroup-head {
  display: flex; align-items: center; gap: 6px; padding: 6px 9px;
  background: rgba(15, 23, 42, .035);
  font-size: 10px; font-weight: 800; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .62);
}
.egroup-name { flex: 0 0 auto; }
.egroup-count { font-weight: 700; }
.egroup-body {
  display: grid; gap: 2px; padding: 5px 8px 7px;
  grid-template-columns: repeat(auto-fill, minmax(258px, 1fr));
}
.cap-item {
  display: flex; align-items: flex-start; gap: 4px;
  padding: 4px 6px; border-radius: 8px; cursor: pointer;
  transition: background .12s ease;
}
.cap-item:hover { background: rgba(15, 23, 42, .03); }
.cap-item--on { background: rgba(22, 163, 74, .055); }
.cap-text { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.cap-label { font-size: 11.5px; font-weight: 600; line-height: 1.25; }
.cap-desc {
  font-size: 9.5px; line-height: 1.25; color: rgba(var(--v-theme-on-surface), .5);
}
.current-role { display: flex; align-items: center; gap: 8px; }
</style>
