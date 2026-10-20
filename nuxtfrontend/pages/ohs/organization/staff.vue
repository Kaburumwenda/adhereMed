<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-account-hard-hat"
      eyebrow="Security & settings · Team"
      title="Staff & Access"
      subtitle="Everyone with a login to this safety system — their HSE role, competence credentials and access state."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn v-if="canEdit" class="ohs-btn-strong text-none" rounded="lg" size="small"
               prepend-icon="mdi-account-plus" @click="openCreate">Add member</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-account-multiple</v-icon>
        <b>{{ members.length }}</b> members</span>
      <span class="ohs-chip"><v-icon size="12">mdi-shield-account</v-icon>
        <b>{{ stats.leaders }}</b> HSE leadership</span>
      <span class="ohs-chip"><v-icon size="12">mdi-check-circle-outline</v-icon>
        <b>{{ stats.active }}</b> active</span>
      <span v-if="stats.inactive" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-account-off-outline</v-icon>
        <b>{{ stats.inactive }}</b> suspended</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Team size" :value="members.length" icon="mdi-account-multiple-outline"
              tone="primary" :sub="`${stats.roles} distinct roles`" />
      <OhsKpi label="HSE leadership" :value="stats.leaders" icon="mdi-shield-account-outline"
              tone="info" sub="manager & officer" />
      <OhsKpi label="Available now" :value="stats.available" icon="mdi-account-check-outline"
              :tone="stats.available ? 'ok' : 'warn'" sub="marked available" />
      <OhsKpi label="Active logins" :value="stats.active" icon="mdi-login-variant"
              :tone="stats.inactive ? 'warn' : 'ok'" :sub="`${stats.inactive} suspended`" />
      <OhsKpi label="Avg experience" :value="`${stats.avgExp} yrs`" icon="mdi-briefcase-clock-outline"
              tone="primary" sub="across the team" />
      <OhsKpi label="Credentials" :value="stats.credentials" icon="mdi-certificate-outline"
              tone="info" sub="licence or qualification" />
    </div>

    <v-row dense class="mb-3">
      <v-col cols="12" md="7">
        <OhsPanel title="Role coverage" subtitle="Who holds which safety responsibility"
                  icon="mdi-account-switch-outline" class="h-100">
          <div v-for="r in roleBreakdown" :key="r.value" class="role-row">
            <span class="role-icon" :style="{ color: r.color, background: r.soft }">
              <v-icon size="15">{{ r.icon }}</v-icon>
            </span>
            <span class="role-name">{{ r.label }}</span>
            <div class="ohs-meter role-meter" :style="{ color: r.color }">
              <div class="ohs-meter-fill" :style="{ width: r.pct + '%' }" />
            </div>
            <span class="role-count">{{ r.count }}</span>
          </div>
          <div v-if="!roleBreakdown.length" class="ohs-empty">No team members yet.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" md="5">
        <OhsPanel title="Access posture" subtitle="Login state and editing rights" icon="mdi-shield-lock-outline"
                  class="h-100">
          <div class="posture-grid">
            <div class="posture-item">
              <span class="posture-label">Active</span>
              <span class="posture-value" style="color:#16a34a">{{ stats.active }}</span>
            </div>
            <div class="posture-item">
              <span class="posture-label">Suspended</span>
              <span class="posture-value" :style="{ color: stats.inactive ? '#dc2626' : '#16a34a' }">
                {{ stats.inactive }}
              </span>
            </div>
            <div class="posture-item">
              <span class="posture-label">Admins</span>
              <span class="posture-value">{{ stats.admins }}</span>
            </div>
            <div class="posture-item">
              <span class="posture-label">Field roles</span>
              <span class="posture-value">{{ stats.field }}</span>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="text-caption text-medium-emphasis">
            <v-icon size="13" class="mr-1">mdi-information-outline</v-icon>
            Suspended members keep their history but cannot sign in. Passwords are reset
            from the row menu — the member is never emailed a plaintext credential.
          </div>
          <div v-if="!canEdit" class="mt-3">
            <v-alert type="info" variant="tonal" density="compact" rounded="lg">
              Your role has view-only access to the team directory.
            </v-alert>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <OhsPanel title="Team directory" :subtitle="`${filtered.length} of ${members.length} members`"
              icon="mdi-format-list-bulleted" flush>
      <template #actions>
        <v-chip-group v-model="stateFilter" mandatory selected-class="text-primary">
          <v-chip v-for="f in stateFilters" :key="f.value" :value="f.value" size="small"
                  variant="tonal" :color="f.color">{{ f.label }}</v-chip>
        </v-chip-group>
      </template>

      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search name, email, licence…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined"
                      rounded="lg" hide-details single-line clearable style="max-width:280px" />
        <v-select v-model="roleFilter" :items="roleOptions" item-title="label" item-value="value"
                  placeholder="All roles" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:210px" />
        <v-select v-model="availFilter" :items="availabilityOptions" item-title="label"
                  item-value="value" placeholder="Any availability" density="compact"
                  variant="outlined" rounded="lg" hide-details clearable style="max-width:190px" />
      </div>

      <v-progress-linear v-if="loading" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:64vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th>Member</th>
              <th style="width:180px">Role</th>
              <th style="width:190px">Qualification</th>
              <th style="width:140px">Licence</th>
              <th style="width:80px" class="num">Exp.</th>
              <th style="width:120px">Availability</th>
              <th style="width:110px">Access</th>
              <th style="width:56px" />
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in filtered" :key="m.id">
              <td>
                <div class="d-flex align-center" style="gap:9px">
                  <span class="member-avatar" :style="avatarStyle(m)">
                    {{ initialsOf(m.user_name) }}
                  </span>
                  <span class="member-id">
                    <span class="member-name">{{ m.user_name || '—' }}</span>
                    <span class="member-mail">{{ m.user_email }}</span>
                  </span>
                </div>
              </td>
              <td>
                <span class="ohs-badge" :class="roleBadge(m.user_role)">
                  {{ roleLabel(m.user_role) }}
                </span>
              </td>
              <td class="text-caption">{{ m.qualification || '—' }}</td>
              <td class="ohs-mono text-caption">{{ m.license_number || '—' }}</td>
              <td class="ohs-tabular text-caption">
                {{ m.years_of_experience ? `${m.years_of_experience}y` : '—' }}
              </td>
              <td>
                <span class="ohs-badge" :class="m.is_available ? 'ohs-badge--ok' : 'ohs-badge--muted'">
                  {{ m.is_available ? 'Available' : 'Unavailable' }}
                </span>
              </td>
              <td>
                <span class="ohs-badge" :class="m.is_user_active ? 'ohs-badge--ok' : 'ohs-badge--err'">
                  {{ m.is_user_active ? 'Active' : 'Suspended' }}
                </span>
              </td>
              <td class="text-right">
                <v-menu location="bottom end">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="x-small"
                           density="comfortable" />
                  </template>
                  <v-list density="compact" class="py-1">
                    <v-list-item prepend-icon="mdi-pencil-outline" title="Edit member"
                                 :disabled="!canEdit" @click="openEdit(m)" />
                    <v-list-item prepend-icon="mdi-key-variant" title="Reset password"
                                 :disabled="!canEdit" @click="openPassword(m)" />
                    <v-list-item :prepend-icon="m.is_available ? 'mdi-account-off-outline' : 'mdi-account-check-outline'"
                                 :title="m.is_available ? 'Mark unavailable' : 'Mark available'"
                                 :disabled="!canEdit" @click="toggleAvailability(m)" />
                    <v-list-item :prepend-icon="m.is_user_active ? 'mdi-lock-outline' : 'mdi-lock-open-variant-outline'"
                                 :title="m.is_user_active ? 'Suspend access' : 'Restore access'"
                                 :disabled="!canEdit" @click="toggleActive(m)" />
                    <v-divider class="my-1" />
                    <v-list-item prepend-icon="mdi-delete-outline" title="Remove from team"
                                 base-color="error" :disabled="!canEdit" @click="confirmRemove(m)" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !loading" class="ohs-empty">
          No team members match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- ═══════════ CREATE / EDIT MEMBER ═══════════ -->
    <v-dialog v-model="formDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader :icon="editing ? 'mdi-account-edit-outline' : 'mdi-account-plus-outline'"
                           :title="editing ? 'Edit team member' : 'Add a team member'"
                           subtitle="Roles decide what each person can see and approve." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.first_name" label="First name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.last_name" label="Last name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.email" label="Email" type="email" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.phone" label="Phone" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.role" :items="roleOptions" item-title="label"
                        item-value="value" label="HSE role" variant="outlined"
                        density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-if="!editing" v-model="form.password" label="Temporary password"
                            type="password" variant="outlined" density="compact" rounded="lg"
                            hint="Minimum 8 characters" persistent-hint />
              <v-text-field v-else v-model="form.password" label="New password (optional)"
                            type="password" variant="outlined" density="compact" rounded="lg"
                            hint="Leave blank to keep the current password" persistent-hint />
            </v-col>
            <v-col cols="12" sm="7">
              <v-text-field v-model="form.qualification" label="Qualification / position"
                            variant="outlined" density="compact" rounded="lg"
                            placeholder="e.g. NEBOSH IGC, BSc Env. Health" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-text-field v-model="form.license_number" label="Licence / registration"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.years_of_experience" type="number" min="0"
                            label="Years of experience" variant="outlined" density="compact"
                            rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-switch v-model="form.is_available" label="Available" color="primary"
                        density="compact" hide-details class="mt-1" />
            </v-col>
            <v-col v-if="editing" cols="12" sm="4">
              <v-switch v-model="form.is_user_active" label="Login active" color="primary"
                        density="compact" hide-details class="mt-1" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.bio" label="Notes" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 :disabled="!canSubmit" @click="save">
            {{ editing ? 'Save changes' : 'Add member' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ RESET PASSWORD ═══════════ -->
    <v-dialog v-model="passwordDialog" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-key-variant" title="Reset password"
                           :subtitle="target?.user_name || ''" />
        <v-card-text>
          <v-text-field v-model="newPassword" label="New password" type="password"
                        variant="outlined" density="compact" rounded="lg"
                        hint="Minimum 8 characters" persistent-hint />
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="passwordDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 :disabled="newPassword.length < 8" @click="savePassword">Reset password</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════ REMOVE MEMBER ═══════════ -->
    <v-dialog v-model="removeDialog" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-remove-outline" title="Remove from team"
                           :subtitle="target?.user_name || ''" />
        <v-card-text>
          <div class="text-body-2">
            This deletes <b>{{ target?.user_name }}</b> and their staff profile. Records they
            created (incidents, inspections, reviews) are retained for the audit trail.
          </div>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="removeDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" :loading="saving"
                 @click="removeMember">Remove member</v-btn>
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
useHead({ title: 'Staff & Access · OHSMS' })

const auth = useAuthStore()
const { $api } = useNuxtApp()

const ADMIN_EDIT_ROLES = new Set([
  'super_admin', 'tenant_admin', 'admin', 'hse_manager',
])
const canEdit = computed(() => ADMIN_EDIT_ROLES.has(auth.role))

const members = ref([])
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const search = ref('')
const roleFilter = ref(null)
const availFilter = ref(null)
const stateFilter = ref('all')

const formDialog = ref(false)
const passwordDialog = ref(false)
const removeDialog = ref(false)
const editing = ref(null)
const target = ref(null)
const newPassword = ref('')

const form = reactive({
  first_name: '', last_name: '', email: '', phone: '', role: 'safety_officer',
  password: '', qualification: '', license_number: '', years_of_experience: 0,
  is_available: true, is_user_active: true, bio: '',
})

const ROLE_META = {
  hse_manager: { label: 'HSE Manager', icon: 'mdi-shield-account', color: '#7c3aed' },
  safety_officer: { label: 'Safety Officer', icon: 'mdi-shield-check', color: '#dc2626' },
  occ_health_nurse: { label: 'Occupational Health Nurse', icon: 'mdi-medical-bag', color: '#0891b2' },
  supervisor: { label: 'Supervisor', icon: 'mdi-account-tie-outline', color: '#0284c7' },
  tenant_admin: { label: 'Tenant Admin', icon: 'mdi-crown-outline', color: '#b45309' },
  admin: { label: 'Administrator', icon: 'mdi-crown-outline', color: '#b45309' },
  super_admin: { label: 'Super Admin', icon: 'mdi-shield-crown-outline', color: '#7c3aed' },
}

const ROLE_ORDER = [
  'hse_manager', 'safety_officer', 'occ_health_nurse', 'supervisor',
  'tenant_admin', 'admin',
]

const roleOptions = computed(() => ROLE_ORDER.map((value) => ({
  value,
  label: ROLE_META[value]?.label || titleCase(value),
})))

const availabilityOptions = [
  { value: true, label: 'Available' },
  { value: false, label: 'Unavailable' },
]

const stateFilters = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Active', value: 'active', color: 'success' },
  { label: 'Suspended', value: 'suspended', color: 'error' },
  { label: 'Unavailable', value: 'unavailable', color: 'warning' },
]

// ── derived ─────────────────────────────────────────────────────────────
const filtered = computed(() => members.value.filter((m) => {
  if (roleFilter.value && m.user_role !== roleFilter.value) return false
  if (availFilter.value !== null && availFilter.value !== undefined
      && Boolean(m.is_available) !== Boolean(availFilter.value)) return false
  if (stateFilter.value === 'active' && !m.is_user_active) return false
  if (stateFilter.value === 'suspended' && m.is_user_active) return false
  if (stateFilter.value === 'unavailable' && m.is_available) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${m.user_name} ${m.user_email} ${m.license_number} ${m.qualification} ${m.user_role}`
      .toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = members.value
  const withExp = all.filter((m) => m.years_of_experience)
  const roles = new Set(all.map((m) => m.user_role).filter(Boolean))
  return {
    active: all.filter((m) => m.is_user_active).length,
    inactive: all.filter((m) => !m.is_user_active).length,
    available: all.filter((m) => m.is_available).length,
    leaders: all.filter((m) => ['hse_manager', 'safety_officer'].includes(m.user_role)).length,
    admins: all.filter((m) => ['tenant_admin', 'admin', 'super_admin'].includes(m.user_role)).length,
    field: all.filter((m) => ['safety_officer', 'supervisor', 'occ_health_nurse'].includes(m.user_role)).length,
    roles: roles.size,
    credentials: all.filter((m) => m.license_number || m.qualification).length,
    avgExp: withExp.length
      ? Math.round(withExp.reduce((s, m) => s + Number(m.years_of_experience || 0), 0) / withExp.length)
      : 0,
  }
})

const roleBreakdown = computed(() => {
  const total = members.value.length || 1
  const counts = {}
  for (const m of members.value) {
    if (!m.user_role) continue
    counts[m.user_role] = (counts[m.user_role] || 0) + 1
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .map(([value, count]) => {
      const meta = ROLE_META[value] || { label: titleCase(value), icon: 'mdi-account', color: '#64748b' }
      return {
        value, count,
        label: meta.label, icon: meta.icon, color: meta.color,
        soft: `${meta.color}1f`,
        pct: Math.round(count / total * 100),
      }
    })
})

const canSubmit = computed(() => {
  if (!form.first_name || !form.last_name || !form.email || !form.role) return false
  if (!editing.value && form.password.length < 8) return false
  return true
})

// ── presentation helpers ────────────────────────────────────────────────
function roleLabel(role) {
  return ROLE_META[role]?.label || titleCase(role)
}
function roleBadge(role) {
  return {
    hse_manager: 'ohs-badge--crit',
    safety_officer: 'ohs-badge--err',
    occ_health_nurse: 'ohs-badge--info',
    supervisor: 'ohs-badge--info',
    tenant_admin: 'ohs-badge--warn',
    admin: 'ohs-badge--warn',
  }[role] || 'ohs-badge--muted'
}
function avatarStyle(m) {
  const color = ROLE_META[m.user_role]?.color || '#64748b'
  return { background: `${color}22`, color }
}

// ── data ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/staff/', {
      params: { page_size: 500, ordering: 'created_at' },
    })
    members.value = data?.results || data || []
  } catch (e) {
    members.value = []
    snack.value = {
      show: true, color: 'error',
      text: e?.response?.data?.detail || 'Could not load the team directory.',
    }
  } finally {
    loading.value = false
  }
}

function resetForm() {
  Object.assign(form, {
    first_name: '', last_name: '', email: '', phone: '', role: 'safety_officer',
    password: '', qualification: '', license_number: '', years_of_experience: 0,
    is_available: true, is_user_active: true, bio: '',
  })
}

function openCreate() {
  error.value = ''
  editing.value = null
  resetForm()
  formDialog.value = true
}

function openEdit(m) {
  error.value = ''
  editing.value = m
  const [first, ...rest] = String(m.user_name || '').split(' ')
  Object.assign(form, {
    first_name: first || '',
    last_name: rest.join(' '),
    email: m.user_email || '',
    phone: m.user_phone || '',
    role: m.user_role || 'safety_officer',
    password: '',
    qualification: m.qualification || '',
    license_number: m.license_number || '',
    years_of_experience: m.years_of_experience || 0,
    is_available: !!m.is_available,
    is_user_active: !!m.is_user_active,
    bio: m.bio || '',
  })
  formDialog.value = true
}

async function save() {
  error.value = ''
  saving.value = true
  try {
    if (editing.value) {
      const payload = {
        first_name: form.first_name,
        last_name: form.last_name,
        email: form.email,
        phone: form.phone,
        role: form.role,
        qualification: form.qualification,
        license_number: form.license_number,
        years_of_experience: Number(form.years_of_experience) || 0,
        is_available: form.is_available,
        is_user_active: form.is_user_active,
      }
      if (form.password) payload.password = form.password
      await $api.patch(`/staff/${editing.value.id}/`, payload)
      snack.value = { show: true, color: 'success', text: 'Team member updated.' }
    } else {
      await $api.post('/staff/', {
        email: form.email,
        first_name: form.first_name,
        last_name: form.last_name,
        phone: form.phone,
        role: form.role,
        password: form.password,
        qualification: form.qualification,
        license_number: form.license_number,
        years_of_experience: Number(form.years_of_experience) || 0,
        is_available: form.is_available,
      })
      snack.value = { show: true, color: 'success', text: 'Team member added — share the password securely.' }
    }
    formDialog.value = false
    await load()
  } catch (e) {
    error.value = apiMessage(e)
  } finally {
    saving.value = false
  }
}

function openPassword(m) {
  error.value = ''
  target.value = m
  newPassword.value = ''
  passwordDialog.value = true
}

async function savePassword() {
  if (!target.value) return
  error.value = ''
  saving.value = true
  try {
    await $api.patch(`/staff/${target.value.id}/`, { password: newPassword.value })
    passwordDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Password reset — share it securely.' }
  } catch (e) {
    error.value = apiMessage(e)
  } finally {
    saving.value = false
  }
}

async function toggleAvailability(m) {
  try {
    await $api.patch(`/staff/${m.id}/`, { is_available: !m.is_available })
    m.is_available = !m.is_available
    snack.value = {
      show: true, color: 'success',
      text: m.is_available ? 'Marked available.' : 'Marked unavailable.',
    }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: apiMessage(e) }
  }
}

async function toggleActive(m) {
  try {
    await $api.patch(`/staff/${m.id}/`, { is_user_active: !m.is_user_active })
    m.is_user_active = !m.is_user_active
    snack.value = {
      show: true, color: 'success',
      text: m.is_user_active ? 'Access restored.' : 'Access suspended.',
    }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: apiMessage(e) }
  }
}

function confirmRemove(m) {
  error.value = ''
  target.value = m
  removeDialog.value = true
}

async function removeMember() {
  if (!target.value) return
  saving.value = true
  try {
    await $api.delete(`/staff/${target.value.id}/`)
    removeDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Member removed from the team.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: apiMessage(e) }
  } finally {
    saving.value = false
  }
}

function apiMessage(e) {
  const data = e?.response?.data
  if (data && typeof data === 'object' && !data.detail) {
    return Object.entries(data)
      .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`)
      .join(' | ')
  }
  return data?.detail || e?.message || 'Request failed.'
}

function exportData() {
  exportCsv(`ohsms_staff_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'user_name', label: 'Name' },
    { key: 'user_email', label: 'Email' },
    { key: 'user_phone', label: 'Phone' },
    { value: (r) => roleLabel(r.user_role), label: 'Role' },
    { key: 'qualification', label: 'Qualification' },
    { key: 'license_number', label: 'Licence' },
    { key: 'years_of_experience', label: 'Years of experience' },
    { value: (r) => (r.is_available ? 'Available' : 'Unavailable'), label: 'Availability' },
    { value: (r) => (r.is_user_active ? 'Active' : 'Suspended'), label: 'Access' },
    { key: 'created_at', label: 'Added' },
  ])
}

onMounted(load)
</script>

<style scoped>
/* ── role coverage ─────────────────────────────────────────────────── */
.role-row {
  display: flex; align-items: center; gap: 9px;
  padding: 5px 0;
}
.role-icon {
  width: 27px; height: 27px; border-radius: 8px;
  display: grid; place-items: center; flex: 0 0 auto;
}
.role-name {
  font-size: 12px; font-weight: 600; flex: 0 0 168px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.role-meter { flex: 1 1 auto; }
.role-count {
  font-size: 12px; font-weight: 800; min-width: 22px; text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ── access posture ────────────────────────────────────────────────── */
.posture-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.posture-item {
  padding: 10px 12px; border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08); background: rgba(15, 23, 42, .02);
  display: flex; flex-direction: column; gap: 2px;
}
.posture-label {
  font-size: 9.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .5);
}
.posture-value { font-size: 18px; font-weight: 800; line-height: 1.1; }

/* ── directory ─────────────────────────────────────────────────────── */
.member-avatar {
  width: 30px; height: 30px; border-radius: 9px;
  display: grid; place-items: center; flex: 0 0 auto;
  font-size: 11px; font-weight: 800; letter-spacing: .3px;
}
.member-id { display: flex; flex-direction: column; min-width: 0; }
.member-name {
  font-size: 12.5px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 230px;
}
.member-mail {
  font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .55);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 230px;
}
</style>
