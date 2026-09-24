<template>
  <v-container fluid class="pa-3 pa-md-5" style="max-width: 1240px;">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="deep-purple-lighten-5" size="48" class="mr-3">
          <v-icon color="deep-purple-darken-2" size="28">mdi-shield-key</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Roles &amp; Access Control</h1>
          <div class="text-body-2 text-medium-emphasis">
            Manage who can do what across your {{ isInventory ? 'warehouse' : 'pharmacy' }} — live capability matrix &amp; staff role assignment
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
               prepend-icon="mdi-account-plus" :to="p('/staff')">Add Staff</v-btn>
      </div>
    </div>

    <v-alert v-if="!canChange" type="info" variant="tonal" density="compact" rounded="lg" class="mb-4">
      You have view-only access. Only tenant admins can change staff roles.
    </v-alert>

    <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" rounded="lg" class="mb-4">
      {{ errorMsg }}
    </v-alert>

    <!-- Tier legend -->
    <v-card flat rounded="xl" border class="pa-3 mb-4">
      <div class="d-flex align-center flex-wrap ga-3">
        <span class="text-caption text-medium-emphasis mr-1">Access tiers cascade downward:</span>
        <v-chip v-for="t in tierLegend" :key="t.key" size="small" variant="tonal" :color="t.color"
                :prepend-icon="t.icon">
          {{ t.label }} — <span class="text-caption">{{ t.desc }}</span>
        </v-chip>
      </div>
    </v-card>

    <!-- Staff by role -->
    <div class="text-subtitle-1 font-weight-bold mb-3">
      <v-icon size="20" class="mr-1" color="primary">mdi-account-group</v-icon>
      Staff &amp; their roles
    </div>
    <v-row dense class="mb-6">
      <v-col v-for="role in roles" :key="role.key" cols="12" md="6" lg="4">
        <v-card flat rounded="xl" border class="h-100 role-card" :class="`role-card--${role.tier}`">
          <div class="pa-4 pb-2 d-flex align-center">
            <v-avatar :color="tierMeta(role.tier).color" variant="tonal" size="42" class="mr-3">
              <v-icon size="22">{{ role.icon }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1 text-truncate">
              <div class="text-body-1 font-weight-bold">
                {{ role.label }}
                <v-chip v-if="role.is_override" size="x-small" color="pink" variant="tonal"
                        class="ml-1">customized</v-chip>
              </div>
              <v-chip size="x-small" variant="tonal" :color="tierMeta(role.tier).color" class="text-none">
                {{ tierMeta(role.tier).label }} tier
              </v-chip>
            </div>
            <v-tooltip v-if="canChange && canRoleEdit(role)" location="top"
                       :text="role.is_override ? 'View / reset capabilities' : 'Edit capabilities'">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-shield-edit" variant="text" size="small"
                       color="primary" @click="openRoleDialog(role)" />
              </template>
            </v-tooltip>
            <v-tooltip v-else-if="canChange" location="top" text="Owner role — managed by the platform">
              <template #activator="{ props }">
                <v-icon v-bind="props" size="16" class="mx-1" color="grey">mdi-lock</v-icon>
              </template>
            </v-tooltip>
            <v-chip size="small" :color="role.user_count ? tierMeta(role.tier).color : 'grey'"
                    variant="tonal" class="ml-1">{{ role.user_count }}</v-chip>
          </div>
          <v-card-text class="pt-0">
            <div class="text-caption text-medium-emphasis mb-2">{{ role.description }}</div>
            <v-list density="compact" class="bg-transparent pa-0" lines="two">
              <v-list-item v-for="u in role.users" :key="u.id" class="px-0" density="compact">
                <template #prepend>
                  <v-avatar size="30" :color="avatarColor(u.name)" variant="tonal" class="mr-2">
                    <span class="text-caption font-weight-bold">{{ initials(u.name) }}</span>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">{{ u.name }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ u.email }}<template v-if="u.branch_name"> · {{ u.branch_name }}</template>
                </v-list-item-subtitle>
                <template #append>
                  <v-tooltip v-if="canChange && assignable(role.key, u)" location="top" text="Change role">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-shield-edit" variant="text" size="small"
                             color="primary" @click="openChangeRole(u, role)" />
                    </template>
                  </v-tooltip>
                  <v-tooltip v-else-if="canChange" location="top" text="Owner role — managed by the platform">
                    <template #activator="{ props }">
                      <v-icon v-bind="props" size="16" class="ml-2" color="grey">mdi-lock</v-icon>
                    </template>
                  </v-tooltip>
                </template>
              </v-list-item>
              <v-list-item v-if="!role.users.length" density="compact" class="px-0">
                <v-list-item-title class="text-caption text-medium-emphasis">
                  No members with this role
                </v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Custom roles management -->
    <div class="d-flex align-center mb-3 mt-2">
      <div class="text-subtitle-1 font-weight-bold">
        <v-icon size="20" class="mr-1" color="primary">mdi-badge-account-horizontal-outline</v-icon>
        Custom roles
        <span class="text-caption text-medium-emphasis font-weight-regular ml-1">
          add roles tailored to your operation — enforced like the built-ins
        </span>
      </div>
      <v-spacer />
      <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
             prepend-icon="mdi-plus" @click="openRoleDialog()">Add role</v-btn>
    </div>
    <v-row dense class="mb-6">
      <v-col v-for="role in customRoles" :key="role.id" cols="12" md="6" lg="4">
        <v-card flat rounded="xl" border class="h-100 role-card role-card--custom">
          <div class="pa-4 pb-2 d-flex align-center">
            <v-avatar color="pink" variant="tonal" size="42" class="mr-3">
              <v-icon size="22">{{ role.icon }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1 text-truncate">
              <div class="text-body-1 font-weight-bold">{{ role.label }}</div>
              <div class="text-caption text-medium-emphasis">custom · key: <code>{{ role.key }}</code></div>
            </div>
            <v-tooltip text="Edit role" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil" variant="text" size="small" @click="openRoleDialog(role)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Remove role" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-delete" variant="text" size="small" color="error"
                       @click="confirmDeleteRole(role)" />
              </template>
            </v-tooltip>
          </div>
          <v-card-text class="pt-0">
            <div class="text-caption text-medium-emphasis mb-2">
              {{ role.description || 'No description' }} · <strong>{{ role.user_count }}</strong> member(s)
            </div>
            <div class="d-flex flex-wrap ga-1">
              <v-chip v-for="cap in role.capabilities" :key="cap" size="x-small" variant="tonal"
                      color="pink">{{ capLabel(cap) }}</v-chip>
              <span v-if="!role.capabilities.length" class="text-caption text-medium-emphasis">
                No capabilities granted
              </span>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col v-if="!customRoles.length" cols="12">
        <v-card flat rounded="xl" border class="pa-5 text-center">
          <v-icon size="36" color="grey-lighten-1">mdi-badge-account-alert-outline</v-icon>
          <div class="text-body-2 text-medium-emphasis mt-2">
            No custom roles yet — create one to match how your team really works
            (e.g. "Dispatch Clerk", "Receiving Officer").
          </div>
          <v-btn color="primary" variant="tonal" class="mt-3 text-none" prepend-icon="mdi-plus"
                 @click="openRoleDialog()">Create a custom role</v-btn>
        </v-card>
      </v-col>
    </v-row>

    <!-- Capability matrix -->
    <div class="text-subtitle-1 font-weight-bold mb-3">
      <v-icon size="20" class="mr-1" color="primary">mdi-view-grid-outline</v-icon>
      Capability matrix
    </div>
    <v-card flat rounded="xl" border class="overflow-hidden mb-4">
      <div class="matrix-wrap">
        <table class="matrix-table">
          <thead>
            <tr>
              <th class="matrix-cap">Capability</th>
              <th v-for="role in roles" :key="role.key" class="text-center">
                <div class="d-flex flex-column align-center">
                  <v-icon size="16" :color="tierMeta(role.tier).color">{{ role.icon }}</v-icon>
                  <span class="text-caption font-weight-bold mt-1">{{ role.label }}</span>
                </div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="cap in capabilities" :key="cap.key">
              <td class="matrix-cap">{{ cap.label }}</td>
              <td v-for="role in roles" :key="role.key" class="text-center">
                <v-icon v-if="roleHasCap(cap, role)" size="18" color="success">mdi-check-circle</v-icon>
                <v-icon v-else size="16" color="grey-lighten-1">mdi-close</v-icon>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="pa-2 text-caption text-medium-emphasis text-center">
        Enforced server-side on every API request — custom roles take effect immediately.
      </div>
    </v-card>

    <!-- Change role dialog -->
    <v-dialog v-model="changeDialog" max-width="480">
      <v-card v-if="target" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-shield-edit</v-icon>Change role
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="d-flex align-center mb-4">
            <v-avatar size="40" :color="avatarColor(target.user.name)" variant="tonal" class="mr-3">
              <span class="text-body-2 font-weight-bold">{{ initials(target.user.name) }}</span>
            </v-avatar>
            <div>
              <div class="text-body-1 font-weight-medium">{{ target.user.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ target.user.email }}</div>
            </div>
          </div>
          <v-select v-model="newRole" :items="assignableOptions" item-title="label" item-value="key"
                    label="New role *" variant="outlined" density="comfortable"
                    :hint="`Currently: ${target.role.label}`" persistent-hint />
          <v-alert v-if="newRole !== target.role.key" type="warning" variant="tonal" density="compact"
                   rounded="lg" class="mt-4">
            <strong>{{ target.user.name }}</strong> will immediately gain / lose the permissions shown in
            the matrix for <strong>{{ assignableOptions.find(o => o.key === newRole)?.label }}</strong>.
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="changeDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" :disabled="newRole === target.role.key"
                 prepend-icon="mdi-check" @click="confirmChangeRole">Save role</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Role editor dialog (create / edit custom role / edit built-in role) -->
    <v-dialog v-model="roleDialog" max-width="640" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon :color="editingRole?.is_custom === false ? 'pink' : 'primary'" class="mr-2">
            {{ editingRole?.is_custom === false ? 'mdi-shield-edit' : 'mdi-badge-account-horizontal-outline' }}
          </v-icon>
          <template v-if="roleDialogMode === 'builtin'">Edit role — {{ editingRole?.label }}</template>
          <template v-else-if="roleDialogMode === 'edit'">Edit role</template>
          <template v-else>Add custom role</template>
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="roleDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-alert v-if="roleDialogMode === 'builtin'" type="info" variant="tonal" density="compact"
                   rounded="lg" class="mb-4">
            You are customizing the built-in <strong>{{ editingRole?.label }}</strong> role for your
            organization{{ editingRole?.is_override ? '' : ' (currently on platform defaults)' }}.
            Changes apply immediately to every member holding this role.
          </v-alert>
          <v-text-field v-if="roleDialogMode !== 'builtin'" v-model="roleForm.label" label="Role name *"
                        variant="outlined" density="comfortable" :rules="req"
                        hint="e.g. Dispatch Clerk, Receiving Officer" persistent-hint class="mb-3" />
          <v-text-field v-if="roleDialogMode !== 'builtin'" v-model="roleForm.description" label="Description"
                        variant="outlined" density="comfortable" class="mb-3" hide-details />
          <v-select v-if="roleDialogMode === 'create'" v-model="roleForm.icon" :items="ICON_CHOICES" label="Icon"
                    variant="outlined" density="comfortable" class="mb-4" hide-details>
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :prepend-icon="item.raw">
                <v-list-item-subtitle class="text-caption">{{ item.title }}</v-list-item-subtitle>
              </v-list-item>
            </template>
          </v-select>

          <div class="text-subtitle-2 font-weight-bold mb-1">Capabilities</div>
          <div class="text-caption text-medium-emphasis mb-2">
            Grant exactly what this role needs — enforced server-side immediately.
          </div>
          <v-expansion-panels variant="accordion" flat class="cap-panels">
            <v-expansion-panel v-for="(caps, group) in capabilitiesByGroup" :key="group">
              <v-expansion-panel-title class="text-body-2 font-weight-medium">
                <v-icon size="16" class="mr-2" color="primary">mdi-{{ groupIcon(group) }}</v-icon>
                {{ group }}
                <v-spacer />
                <v-chip size="x-small" variant="tonal" color="primary" class="mr-n2">
                  {{ caps.filter(c => roleForm.capabilities.includes(c.key)).length }}/{{ caps.length }}
                </v-chip>
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-checkbox v-for="c in caps" :key="c.key" v-model="roleForm.capabilities"
                            :value="c.key" density="compact" hide-details class="cap-check"
                            :disabled="roleDialogMode === 'builtin' && protectedCaps.includes(c.key)">
                  <template #label>
                    <div>
                      <div class="text-body-2">
                        {{ c.label }}
                        <v-chip v-if="roleDialogMode === 'builtin' && protectedCaps.includes(c.key)"
                                size="x-small" variant="tonal" color="grey" class="ml-1">required</v-chip>
                      </div>
                      <div class="text-caption text-medium-emphasis">{{ c.description }}</div>
                    </div>
                  </template>
                </v-checkbox>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="roleDialogMode === 'builtin' && editingRole?.is_override" variant="text" color="warning"
                 class="text-none" :loading="roleSaving" prepend-icon="mdi-restore" @click="resetBuiltinRole">
            Reset to defaults
          </v-btn>
          <v-spacer />
          <v-btn variant="text" @click="roleDialog = false">Cancel</v-btn>
          <v-btn v-if="roleDialogMode !== 'builtin'" color="primary" variant="flat" :loading="roleSaving"
                 :disabled="roleDialogMode === 'edit' ? false : !roleForm.label"
                 prepend-icon="mdi-check" @click="saveRole">
            {{ roleDialogMode === 'edit' ? 'Save changes' : 'Create role' }}
          </v-btn>
          <v-btn v-else color="primary" variant="flat" :loading="roleSaving"
                 :disabled="!builtinCapsChanged" prepend-icon="mdi-check" @click="saveBuiltinRole">
            Save capabilities
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Remove role confirm -->
    <v-dialog v-model="deleteRoleDialog" max-width="440">
      <v-card v-if="deletingRole" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-delete-alert-outline</v-icon>Remove role?
        </v-card-title>
        <v-card-text>
          <strong>{{ deletingRole.label }}</strong> will be removed.
          <span v-if="deletingRole.user_count">It still has <strong>{{ deletingRole.user_count }}</strong>
            member(s) — reassign them first.</span>
          <span v-else>Members cannot be assigned to it again.</span>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteRoleDialog = false">Keep it</v-btn>
          <v-btn color="error" variant="flat" :loading="roleSaving" :disabled="!!deletingRole.user_count"
                 @click="doDeleteRole">Remove role</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()

// Pharmacy tenants reuse this page under /pharmacy, inventory/warehouse
// tenants under /ims — the sub-paths are identical after the prefix.
const { isInventory } = useTenantEndpoints()
const base = computed(() => isInventory.value ? '/ims' : '/pharmacy')
const p = (suffix) => `${base.value}${suffix}`

const loading = ref(false)
const saving = ref(false)
const data = ref(null)
const errorMsg = ref('')

const TIERS = {
  admin: { label: 'Admin', color: 'deep-purple', icon: 'mdi-shield-account' },
  supervisor: { label: 'Supervisor', color: 'indigo', icon: 'mdi-source-branch' },
  stock_ops: { label: 'Warehouse ops', color: 'teal', icon: 'mdi-warehouse' },
  staff: { label: 'Staff', color: 'blue-grey', icon: 'mdi-account' },
}
const tierLegend = [
  { key: 'admin', label: 'Admin', desc: 'everything incl. destructive ops', color: 'deep-purple', icon: 'mdi-shield-account' },
  { key: 'supervisor', label: 'Supervisor', desc: 'admin + warehouse managers', color: 'indigo', icon: 'mdi-source-branch' },
  { key: 'stock_ops', label: 'Warehouse ops', desc: 'supervisor + storekeepers', color: 'teal', icon: 'mdi-warehouse' },
  { key: 'staff', label: 'Staff', desc: 'read-only (costs hidden)', color: 'blue-grey', icon: 'mdi-account' },
]

const roles = computed(() => data.value?.roles || [])
const capabilities = computed(() => data.value?.capabilities || [])
const customRoles = computed(() => data.value?.custom_roles || [])
const canChange = computed(() => !!data.value?.can_change)

const ICON_CHOICES = [
  { title: 'Badge', value: 'mdi-badge-account-horizontal-outline' },
  { title: 'Truck / Dispatch', value: 'mdi-truck-delivery-outline' },
  { title: 'Clipboard / Counting', value: 'mdi-clipboard-list-outline' },
  { title: 'Cart / Procurement', value: 'mdi-cart-outline' },
  { title: 'Package / Goods-in', value: 'mdi-package-variant-closed' },
  { title: 'Shield / Compliance', value: 'mdi-shield-check-outline' },
  { title: 'Eye / Audit', value: 'mdi-eye-check-outline' },
  { title: 'Wrench / Maintenance', value: 'mdi-wrench-outline' },
]
const GROUP_ICONS = {
  Stock: 'package-variant-closed',
  Adjustments: 'tune',
  'Stock take': 'clipboard-list-outline',
  Transfers: 'truck-delivery-outline',
  Controlled: 'shield-lock-outline',
  Administration: 'cog-outline',
}

const capabilitiesByGroup = computed(() => {
  const groups = {}
  for (const cap of capabilities.value) {
    (groups[cap.group] = groups[cap.group] || []).push(cap)
  }
  return groups
})
function groupIcon(group) { return GROUP_ICONS[group] || 'circle-outline' }
function capLabel(key) {
  return capabilities.value.find(c => c.key === key)?.label || key
}

function roleHasCap(cap, role) {
  // role.capabilities holds the *effective* list for both built-in roles
  // (platform defaults or the tenant override) and custom roles.
  if (Array.isArray(role.capabilities) && role.capabilities.length) {
    return role.capabilities.includes(cap.key)
  }
  return (cap.roles || []).includes(role.key)
}

const assignableOptions = computed(() =>
  (data.value?.assignable_roles || [])
    .map(key => roles.value.find(r => r.key === key))
    .filter(Boolean)
    .map(r => ({ key: r.key, label: r.label })))

function assignable(roleKey, user) {
  // Tenant owner is locked; you can't change your own role here.
  return (data.value?.assignable_roles || []).includes(roleKey)
}

function canRoleEdit(role) {
  // Custom roles are always editable. Built-ins are editable per the
  // backend flag — with a safe fallback (everything except the owner role)
  // when the flag is missing (e.g. an older backend build).
  if (role.is_custom) return true
  return role.editable ?? (role.key && role.key !== 'tenant_admin')
}

function tierMeta(tier) { return TIERS[tier] || TIERS.staff }

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const { data: d } = await $api.get('/inventory/rbac/')
    data.value = d
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to load roles & access.'
    data.value = null
  } finally {
    loading.value = false
  }
}

// ── Change role ─────────────────────────────────────────────────────────
const changeDialog = ref(false)
const target = ref(null)   // { user, role }
const newRole = ref(null)

function openChangeRole(user, role) {
  target.value = { user, role }
  newRole.value = role.key
  changeDialog.value = true
}

async function confirmChangeRole() {
  if (!target.value || newRole.value === target.value.role.key) return
  saving.value = true
  try {
    const { data: d } = await $api.patch(
      `/inventory/rbac/users/${target.value.user.id}/role/`,
      { role: newRole.value },
    )
    showSnack(d?.detail || 'Role updated', 'success')
    changeDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to change role', 'error')
  } finally {
    saving.value = false }
}

// ── Custom role CRUD (add / edit / remove) + built-in overrides ──────────
const req = [v => !!v || 'Required']
const roleDialog = ref(false)
const roleSaving = ref(false)
const editingRole = ref(null)
const roleForm = reactive({ label: '', description: '', icon: '', capabilities: [] })
const deleteRoleDialog = ref(false)
const deletingRole = ref(null)
const PROTECTED_BUILTIN_CAP_KEYS = ['stock.view']
const protectedCaps = PROTECTED_BUILTIN_CAP_KEYS

// 'create' | 'edit' (custom) | 'builtin' (built-in override)
const roleDialogMode = ref('create')
const builtinCapsChanged = computed(() => {
  if (roleDialogMode.value !== 'builtin') return false
  const current = [...(roleForm.capabilities || [])].sort().join(',')
  const original = [...(editingRole.value?.capabilities || [])].sort().join(',')
  return current !== original
})

function openRoleDialog(role = null) {
  editingRole.value = role
  if (role && role.is_custom !== undefined && !role.is_custom) {
    // built-in role — capability override editor
    roleDialogMode.value = 'builtin'
    roleForm.capabilities = [...(role.capabilities || [])]
  } else if (role) {
    // existing custom role
    roleDialogMode.value = 'edit'
    roleForm.label = role.label
    roleForm.description = role.description || ''
    roleForm.icon = role.icon || 'mdi-badge-account-horizontal-outline'
    roleForm.capabilities = [...(role.capabilities || [])]
  } else {
    // new custom role
    roleDialogMode.value = 'create'
    roleForm.label = ''
    roleForm.description = ''
    roleForm.icon = 'mdi-badge-account-horizontal-outline'
    roleForm.capabilities = ['stock.view']
  }
  roleDialog.value = true
}

async function saveRole() {
  if (!roleForm.label) return
  roleSaving.value = true
  try {
    const payload = {
      label: roleForm.label,
      description: roleForm.description || '',
      icon: roleForm.icon || 'mdi-badge-account-horizontal-outline',
      capabilities: roleForm.capabilities,
    }
    if (roleDialogMode.value === 'edit') {
      await $api.patch(`/inventory/rbac/roles/${editingRole.value.id}/`, payload)
      showSnack(`Role "${payload.label}" updated`, 'success')
    } else {
      await $api.post('/inventory/rbac/roles/', payload)
      showSnack(`Role "${payload.label}" created`, 'success')
    }
    roleDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    const msg = Array.isArray(d?.label) ? d.label[0]
      : Array.isArray(d?.capabilities) ? d.capabilities[0]
      : d?.detail || 'Failed to save role'
    showSnack(msg, 'error')
  } finally {
    roleSaving.value = false
  }
}

async function saveBuiltinRole() {
  if (!editingRole.value) return
  roleSaving.value = true
  try {
    const { data: d } = await $api.patch(
      `/inventory/rbac/builtin-roles/${editingRole.value.key}/`,
      { capabilities: roleForm.capabilities },
    )
    showSnack(d?.detail || 'Capabilities updated', 'success')
    roleDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to update capabilities', 'error')
  } finally {
    roleSaving.value = false
  }
}

async function resetBuiltinRole() {
  if (!editingRole.value) return
  roleSaving.value = true
  try {
    const { data: d } = await $api.delete(
      `/inventory/rbac/builtin-roles/${editingRole.value.key}/`,
    )
    showSnack(d?.detail || 'Platform defaults restored', 'success')
    roleDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to reset', 'error')
  } finally {
    roleSaving.value = false
  }
}

function confirmDeleteRole(role) {
  deletingRole.value = role
  deleteRoleDialog.value = true
}

async function doDeleteRole() {
  if (!deletingRole.value) return
  roleSaving.value = true
  try {
    const { data: d } = await $api.delete(`/inventory/rbac/roles/${deletingRole.value.id}/`)
    showSnack(d?.detail || 'Role removed', 'success')
    deleteRoleDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to remove role', 'error')
  } finally {
    roleSaving.value = false
  }
}

// ── Presentation helpers ────────────────────────────────────────────────
function avatarColor(name) {
  const colors = ['primary', 'secondary', 'success', 'info', 'warning', 'error', 'indigo', 'teal']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function initials(name) {
  return (name || '?').split(' ').slice(0, 2).map(w => w[0]?.toUpperCase() || '').join('')
}
const snack = reactive({ show: false, color: 'success', text: '' })
function showSnack(text, color = 'success') { Object.assign(snack, { show: true, color, text }) }

onMounted(load)
</script>

<style scoped>
.role-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border-top: 3px solid transparent; }
.role-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.07); }
.role-card--admin { border-top-color: #673ab7; }
.role-card--supervisor { border-top-color: #3f51b5; }
.role-card--stock_ops { border-top-color: #009688; }
.role-card--staff { border-top-color: #78909c; }
.role-card--custom { border-top-color: #e91e63; }

.cap-panels { border: 1px solid rgba(var(--v-theme-on-surface), 0.1); border-radius: 12px; }
.cap-check { padding-top: 4px; padding-bottom: 4px; }

.matrix-wrap { overflow-x: auto; }
.matrix-table { width: 100%; border-collapse: collapse; min-width: 860px; }
.matrix-table thead th {
  position: sticky; top: 0; background: rgba(var(--v-theme-primary), 0.06);
  padding: 10px 12px; border-bottom: 2px solid rgba(var(--v-theme-primary), 0.25);
  vertical-align: bottom; white-space: nowrap;
}
.matrix-table tbody td {
  padding: 8px 12px; border-bottom: 1px solid rgba(0,0,0,0.05);
  font-size: 13px; vertical-align: middle;
}
.matrix-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.03); }
.matrix-cap { font-weight: 500; text-align: left; }
</style>
