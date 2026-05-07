<template>
  <v-container fluid class="pa-4 pa-md-6 staff-module">
    <!-- ───────────────────────── Hero ───────────────────────── -->
    <v-card flat rounded="xl" class="hero mb-5 text-white pa-5 pa-md-6">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center mb-2">
            <v-avatar color="white" size="44" class="mr-3">
              <v-icon color="indigo-darken-2" size="26">mdi-badge-account-horizontal</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 font-weight-bold">Pharmacy Staff</div>
              <div class="text-caption opacity-80">Manage team members, specializations &amp; schedules</div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0">
          <v-btn color="white" variant="elevated" class="text-indigo-darken-3 mr-2"
                 prepend-icon="mdi-account-plus" @click="openStaffDialog()">Add Staff</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="reloadAll">Refresh</v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="card in statCards" :key="card.key" cols="6" md="3">
          <v-card flat rounded="lg" class="stat-card pa-3"
                  @click="card.tab && (tab = card.tab)">
            <div class="d-flex align-center">
              <v-avatar :color="card.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ card.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
                <div class="text-h6 font-weight-bold">{{ card.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- ───────────────────────── Tabs ───────────────────────── -->
    <v-card flat rounded="xl" class="mb-4">
      <v-tabs v-model="tab" color="indigo-darken-2" align-tabs="start" show-arrows>
        <v-tab value="team" prepend-icon="mdi-account-group">Team</v-tab>
        <v-tab value="specializations" prepend-icon="mdi-school">Specializations</v-tab>
        <v-tab value="schedule" prepend-icon="mdi-calendar-week">Weekly Schedule</v-tab>
      </v-tabs>
    </v-card>

    <!-- ───────────────────── Team tab ───────────────────── -->
    <template v-if="tab === 'team'">
      <v-card flat rounded="xl" class="pa-3 mb-3">
        <v-row dense align="center">
          <v-col cols="12" md="4">
            <v-text-field v-model="staffSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search by name, email…" density="comfortable" hide-details
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
                   @click="bulkDelete">Delete</v-btn>
          </v-col>
          <v-spacer />
          <v-col cols="auto">
            <v-btn size="small" variant="text" prepend-icon="mdi-download" @click="exportStaffCsv">
              Export CSV
            </v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl">
        <v-data-table-server v-model="selectedStaff" :headers="staffHeaders" :items="staff"
                             :items-length="staffTotal" :loading="loading" item-value="id" show-select
                             :items-per-page="staffPageSize" :page="staffPage"
                             :items-per-page-options="[25, 50, 100, 200]"
                             class="staff-table" hover
                             @update:page="(p) => { staffPage = p; loadStaff() }"
                             @update:items-per-page="(n) => { staffPageSize = n; staffPage = 1; loadStaff() }">

          <template #item.user_name="{ item }">
            <div class="d-flex align-center py-1">
              <v-avatar :color="avatarColor(item.user_name)" size="36" class="mr-3 text-white">
                <span class="text-caption font-weight-bold">{{ initials(item.user_name) }}</span>
              </v-avatar>
              <div>
                <div class="font-weight-medium">{{ item.user_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ item.user_email }}</div>
              </div>
            </div>
          </template>

          <template #item.user_role="{ item }">
            <v-chip size="small" :color="roleColor(item.user_role)" variant="tonal" class="font-weight-medium">
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

          <template #item.years_of_experience="{ item }">
            <v-chip size="x-small" variant="outlined">{{ item.years_of_experience || 0 }} yr</v-chip>
          </template>

          <template #item.is_available="{ item }">
            <v-switch :model-value="item.is_available" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleAvailability(item, v)" />
          </template>

          <template #item.actions="{ item }">
            <v-btn icon size="small" variant="text" @click="quickResetPassword(item)">
              <v-icon size="20">mdi-lock-reset</v-icon>
              <v-tooltip activator="parent" location="top">Reset password</v-tooltip>
            </v-btn>
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
              <v-btn class="mt-3" color="primary" variant="text" prepend-icon="mdi-account-plus"
                     @click="openStaffDialog()">Add your first staff member</v-btn>
            </div>
          </template>
        </v-data-table-server>
      </v-card>
    </template>

    <!-- ───────────────── Specializations tab ───────────────── -->
    <template v-if="tab === 'specializations'">
      <v-card flat rounded="xl" class="pa-3 mb-3">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="specSearch" prepend-inner-icon="mdi-magnify" placeholder="Search specializations…"
                          density="comfortable" hide-details variant="solo-filled" flat clearable
                          @update:model-value="loadSpecs" />
          </v-col>
          <v-spacer />
          <v-col cols="auto">
            <v-btn color="primary" prepend-icon="mdi-plus" @click="openSpecDialog()">New Specialization</v-btn>
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

    <!-- ───────────────── Schedule tab ───────────────── -->
    <template v-if="tab === 'schedule'">
      <v-card flat rounded="xl" class="pa-4">
        <div class="d-flex align-center mb-3">
          <v-icon color="indigo" class="mr-2">mdi-calendar-week</v-icon>
          <div class="text-h6">Weekly Schedule Overview</div>
          <v-spacer />
          <v-chip size="small" variant="tonal" color="indigo">
            {{ scheduledCount }} of {{ allStaff.length }} staff scheduled
          </v-chip>
        </div>

        <v-row>
          <v-col v-for="d in weekdays" :key="d.key" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="schedule-day pa-3 h-100" border>
              <div class="d-flex align-center mb-2">
                <v-icon size="18" color="indigo" class="mr-2">mdi-calendar</v-icon>
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
                <div class="flex-grow-1 text-body-2">
                  <div class="font-weight-medium">{{ entry.user_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ entry.shift }}</div>
                </div>
              </div>
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
          <v-btn variant="text" @click="staffDialog = false">Cancel</v-btn>
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
          <v-btn variant="text" @click="specDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="elevated" :loading="saving" @click="saveSpec">Save</v-btn>
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
          <v-btn variant="text" @click="confirmDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="elevated" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()

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

const snack = reactive({ show: false, color: 'success', message: '' })

const ROLE_LABELS = {
  pharmacist: 'Pharmacist',
  pharmacy_tech: 'Pharmacy Tech',
  cashier: 'Cashier',
}
const ROLE_COLORS = {
  pharmacist: 'primary',
  pharmacy_tech: 'teal',
  cashier: 'amber-darken-2',
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
const statCards = computed(() => {
  const counts = roleCounts(allStaff.value)
  return [
    { key: 'total', tab: 'team', label: 'Total Staff', value: allStaff.value.length, icon: 'mdi-account-group', color: 'indigo' },
    { key: 'pharm', tab: 'team', label: 'Pharmacists', value: counts.pharmacist, icon: 'mdi-pill', color: 'blue' },
    { key: 'tech', tab: 'team', label: 'Pharmacy Techs', value: counts.pharmacy_tech, icon: 'mdi-medical-bag', color: 'teal' },
    { key: 'cash', tab: 'team', label: 'Cashiers', value: counts.cashier, icon: 'mdi-cash-register', color: 'amber-darken-2' },
  ]
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
function roleCounts(list) {
  const c = { pharmacist: 0, pharmacy_tech: 0, cashier: 0 }
  for (const s of list) if (c[s.user_role] != null) c[s.user_role]++
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

async function quickResetPassword(item) {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lower = 'abcdefghjkmnpqrstuvwxyz'
  const digits = '23456789'
  const symbols = '!@#$%&*?'
  const all = upper + lower + digits + symbols
  const pick = s => s[Math.floor(Math.random() * s.length)]
  let pw = pick(upper) + pick(lower) + pick(digits) + pick(symbols)
  for (let i = 0; i < 8; i++) pw += pick(all)
  pw = pw.split('').sort(() => Math.random() - 0.5).join('')
  if (!confirm(`Reset password for ${item.user_name}?\n\nNew password will be:\n${pw}\n\nMake sure to copy and share it securely.`)) return
  try {
    await $api.patch(`/staff/${item.id}/`, { password: pw })
    try { await navigator.clipboard.writeText(pw); notify('Password reset and copied to clipboard') }
    catch { notify('Password reset (copy from prompt)') }
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
  a.href = url; a.download = `pharmacy-staff-${new Date().toISOString().slice(0, 10)}.csv`
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
.hero {
  background: linear-gradient(135deg, #4338ca 0%, #6d28d9 50%, #2563eb 100%);
}
.hero .stat-card {
  background: rgba(255, 255, 255, 0.96);
  color: rgb(33, 33, 33);
  cursor: pointer;
  transition: transform .15s ease, box-shadow .15s ease;
}
.hero .stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.12);
}
.staff-table :deep(tbody tr) {
  transition: background-color .15s ease;
}
.staff-table :deep(tbody tr:hover) {
  background-color: rgba(99, 102, 241, 0.06);
}
.schedule-day { background: rgba(99, 102, 241, 0.03); }
.schedule-entry { background: rgba(99, 102, 241, 0.07); }
</style>
