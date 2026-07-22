<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Employee Records"
      subtitle="Centralized employee database with self-service portal for personal details, timesheets, and leave requests."
      eyebrow="HR · EMPLOYEES"
      icon="mdi-account-badge-horizontal"
      :chips="[
        { icon: 'mdi-account-group', label: `${items.length} employees` },
        { icon: 'mdi-check-circle', label: `${activeCount} active` },
        { icon: 'mdi-account-clock', label: `${onProbation} on probation` },
        { icon: 'mdi-account-off', label: `${inactiveCount} inactive` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-account-plus"
               class="text-none" @click="openAdd">
          <span class="text-teal-darken-2 font-weight-bold">Add employee</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Total Employees" :value="items.length" icon="mdi-account-group" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Active" :value="activeCount" icon="mdi-check-circle" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="On Probation" :value="onProbation" icon="mdi-account-clock" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Avg Tenure" :value="avgTenure" suffix="yrs" icon="mdi-calendar-month" color="#8b5cf6" /></v-col>
    </v-row>

    <HomecarePanel title="Employee Directory" subtitle="All staff records & self-service actions" icon="mdi-account-group" color="#0d9488" class="mt-3">
      <v-row dense class="mb-2">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search name, role, email…"
                        density="compact" variant="outlined" hide-details clearable />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterDept" :items="deptOptions" label="Department" density="compact" variant="outlined" hide-details clearable />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterStatus" :items="statusOptions" item-title="label" item-value="value"
                    label="Status" density="compact" variant="outlined" hide-details clearable />
        </v-col>
        <v-col cols="12" md="2">
          <v-btn variant="text" prepend-icon="mdi-download" class="text-none" @click="exportCsv">Export</v-btn>
        </v-col>
      </v-row>

      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id" class="hc-table">
        <template #[`item.name`]="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar size="36" :color="avatarColor(item.name)" variant="tonal" class="mr-2">
              <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.email }}</div>
            </div>
          </div>
        </template>
        <template #[`item.department`]="{ item }">
          <v-chip size="small" variant="tonal" :color="deptColor(item.department)">{{ item.department || '—' }}</v-chip>
        </template>
        <template #[`item.employment_type`]="{ item }">
          {{ empTypeLabel(item.employment_type) }}
        </template>
        <template #[`item.hire_date`]="{ item }">
          {{ formatDate(item.hire_date) }}
        </template>
        <template #[`item.salary`]="{ item }">
          <span v-if="item.salary">{{ money(item.salary) }}</span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #[`item.status`]="{ item }">
          <StatusChip :status="empStatusKey(item)" :label="empStatusLabel(item)" />
        </template>
        <template #[`item.actions`]="{ item }">
          <v-menu location="bottom end">
            <template #activator="{ props }">
              <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
            </template>
            <v-list density="compact" min-width="220">
              <v-list-item prepend-icon="mdi-account-details" title="View profile" @click="viewProfile(item)" />
              <v-list-item prepend-icon="mdi-pencil" title="Edit record" @click="openEdit(item)" />
              <v-list-item prepend-icon="mdi-account-cog" title="Self-service portal" @click="openSelfService(item)" />
              <v-list-item prepend-icon="mdi-file-document" title="Documents" @click="goDocuments(item)" />
              <v-divider />
              <v-list-item v-if="item.status === 'active'" prepend-icon="mdi-account-off" title="Deactivate" base-color="error" @click="toggleStatus(item)" />
              <v-list-item v-else prepend-icon="mdi-account-check" title="Activate" @click="toggleStatus(item)" />
            </v-list>
          </v-menu>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- Add / edit employee -->
    <v-dialog v-model="dialog" max-width="780" scrollable>
      <v-card rounded="xl">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon :icon="editingId ? 'mdi-pencil' : 'mdi-account-plus'" class="mr-2" />
          {{ editingId ? 'Edit employee' : 'Add employee' }}
        </v-card-title>
        <v-divider />
        <v-card-text style="max-height:72vh">
          <div class="text-overline text-medium-emphasis mt-1">Personal Information</div>
          <v-row dense>
            <v-col cols="12" sm="6"><v-text-field v-model="form.first_name" label="First name *" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.last_name" label="Last name *" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Email *" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.national_id" label="National ID / Passport" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.gender" :items="['Male','Female','Other']" label="Gender"
                        density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.date_of_birth" label="Date of birth" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.address" label="Address" density="comfortable" variant="outlined" /></v-col>
          </v-row>

          <div class="text-overline text-medium-emphasis mt-3">Employment Details</div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.department" :items="deptOptions" label="Department *"
                        density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.job_title" label="Job title *" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.employment_type" :items="empTypes" item-title="label" item-value="value"
                        label="Employment type" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.status" :items="statusOptions" item-title="label" item-value="value"
                        label="Status" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.hire_date" label="Hire date *" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.probation_end_date" label="Probation ends" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model.number="form.salary" label="Gross salary (KSh/month)" type="number" density="comfortable" variant="outlined" prefix="KSh" /></v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.bank_account" label="Bank account" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.supervisor" :items="supervisorOptions" item-title="name" item-value="id"
                        label="Supervisor" density="comfortable" variant="outlined" clearable />
            </v-col>
            <v-col cols="12" sm="6"><v-text-field v-model="form.emergency_contact" label="Emergency contact" density="comfortable" variant="outlined" /></v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Profile / Self-service dialog -->
    <v-dialog v-model="profileDialog" max-width="820" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-avatar v-if="profileItem" size="44" :color="avatarColor(profileItem.name)" variant="tonal" class="mr-3">
            <span class="font-weight-bold">{{ initials(profileItem.name) }}</span>
          </v-avatar>
          {{ profileItem?.name }}
          <v-spacer />
          <v-btn variant="text" prepend-icon="mdi-account-cog" @click="openSelfService(profileItem)">Self-service</v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text v-if="profileItem" style="max-height:72vh">
          <v-row dense>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Email</div><div class="font-weight-medium">{{ profileItem.email || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Phone</div><div class="font-weight-medium">{{ profileItem.phone || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Department</div><div class="font-weight-medium">{{ profileItem.department || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Job title</div><div class="font-weight-medium">{{ profileItem.job_title || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Employment</div><div class="font-weight-medium">{{ empTypeLabel(profileItem.employment_type) }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Hire date</div><div class="font-weight-medium">{{ formatDate(profileItem.hire_date) }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Salary</div><div class="font-weight-medium">{{ profileItem.salary ? money(profileItem.salary) : '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Supervisor</div><div class="font-weight-medium">{{ profileItem.supervisor_name || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Emergency</div><div class="font-weight-medium">{{ profileItem.emergency_contact || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">National ID</div><div class="font-weight-medium">{{ profileItem.national_id || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Bank</div><div class="font-weight-medium">{{ profileItem.bank_account || '—' }}</div></v-col>
            <v-col cols="6" sm="4"><div class="text-caption text-medium-emphasis">Address</div><div class="font-weight-medium">{{ profileItem.address || '—' }}</div></v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="profileDialog = false">Close</v-btn>
          <v-btn color="teal" variant="flat" prepend-icon="mdi-pencil" @click="openEdit(profileItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Self-service portal dialog -->
    <v-dialog v-model="selfServiceDialog" max-width="620" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-account-cog" class="mr-2" />Self-Service Portal — {{ selfItem?.name }}
        </v-card-title>
        <v-divider />
        <v-card-text v-if="selfItem" style="max-height:72vh">
          <v-tabs v-model="selfTab" color="teal" density="compact" class="mb-3">
            <v-tab value="profile">Update Details</v-tab>
            <v-tab value="timesheet">Timesheet</v-tab>
            <v-tab value="leave">Leave Request</v-tab>
          </v-tabs>

          <div v-if="selfTab === 'profile'">
            <div class="text-overline text-medium-emphasis mb-2">Editable by employee</div>
            <v-text-field v-model="selfItem.phone" label="Phone" density="comfortable" variant="outlined" class="mb-2" />
            <v-text-field v-model="selfItem.address" label="Address" density="comfortable" variant="outlined" class="mb-2" />
            <v-text-field v-model="selfItem.emergency_contact" label="Emergency contact" density="comfortable" variant="outlined" class="mb-2" />
            <v-text-field v-model="selfItem.bank_account" label="Bank account" density="comfortable" variant="outlined" />
          </div>

          <div v-if="selfTab === 'timesheet'">
            <div class="text-overline text-medium-emphasis mb-2">Log hours worked</div>
            <v-row dense>
              <v-col cols="6"><v-text-field v-model="timesheet.date" label="Date" type="date" density="comfortable" variant="outlined" /></v-col>
              <v-col cols="6"><v-text-field v-model="timesheet.hours" label="Hours" type="number" density="comfortable" variant="outlined" suffix="hrs" /></v-col>
              <v-col cols="12"><v-select v-model="timesheet.shift_type" :items="shiftTypes" item-title="label" item-value="value" label="Shift" density="comfortable" variant="outlined" /></v-col>
              <v-col cols="12"><v-textarea v-model="timesheet.notes" label="Notes" rows="2" density="comfortable" variant="outlined" /></v-col>
            </v-row>
            <v-btn color="teal" variant="flat" :loading="saving" @click="submitTimesheet">Submit timesheet</v-btn>
          </div>

          <div v-if="selfTab === 'leave'">
            <div class="text-overline text-medium-emphasis mb-2">Request time off</div>
            <v-row dense>
              <v-col cols="12"><v-select v-model="leaveForm.leave_type" :items="leaveTypes" item-title="label" item-value="value" label="Leave type" density="comfortable" variant="outlined" /></v-col>
              <v-col cols="6"><v-text-field v-model="leaveForm.start_date" label="Start" type="date" density="comfortable" variant="outlined" /></v-col>
              <v-col cols="6"><v-text-field v-model="leaveForm.end_date" label="End" type="date" density="comfortable" variant="outlined" /></v-col>
              <v-col cols="12"><v-textarea v-model="leaveForm.reason" label="Reason" rows="2" density="comfortable" variant="outlined" /></v-col>
            </v-row>
            <v-btn color="teal" variant="flat" :loading="saving" @click="submitLeave">Submit request</v-btn>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="selfServiceDialog = false">Close</v-btn>
          <v-btn v-if="selfTab === 'profile'" color="teal" variant="flat" :loading="saving" @click="saveSelfProfile">Save changes</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const items = ref([])
const search = ref('')
const filterDept = ref(null)
const filterStatus = ref(null)
const loading = ref(false)
const saving = ref(false)
const dialog = ref(false)
const profileDialog = ref(false)
const selfServiceDialog = ref(false)
const editingId = ref(null)
const profileItem = ref(null)
const selfItem = ref(null)
const selfTab = ref('profile')

const blankForm = () => ({
  first_name: '', last_name: '', email: '', phone: '', national_id: '', gender: '',
  date_of_birth: '', address: '', department: '', job_title: '', employment_type: 'full_time',
  status: 'active', hire_date: '', probation_end_date: '', salary: null,
  bank_account: '', supervisor: null, emergency_contact: '',
})
const form = reactive(blankForm())
const timesheet = reactive({ date: '', hours: null, shift_type: 'day', notes: '' })
const leaveForm = reactive({ leave_type: 'annual', start_date: '', end_date: '', reason: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const deptOptions = ['Nursing', 'Caregiving', 'Administration', 'Pharmacy', 'Laboratory', 'Radiology', 'Finance', 'IT', 'Operations']
const statusOptions = [
  { value: 'active', label: 'Active' },
  { value: 'on_probation', label: 'On Probation' },
  { value: 'on_leave', label: 'On Leave' },
  { value: 'suspended', label: 'Suspended' },
  { value: 'terminated', label: 'Terminated' },
  { value: 'resigned', label: 'Resigned' },
]
const empTypes = [
  { value: 'full_time', label: 'Full-time' },
  { value: 'part_time', label: 'Part-time' },
  { value: 'contract', label: 'Contract' },
  { value: 'internship', label: 'Internship' },
]
const shiftTypes = [
  { value: 'day', label: 'Day Shift' },
  { value: 'night', label: 'Night Shift' },
  { value: 'evening', label: 'Evening Shift' },
  { value: 'on_call', label: 'On-call' },
]
const leaveTypes = [
  { value: 'annual', label: 'Annual Leave' },
  { value: 'sick', label: 'Sick Leave' },
  { value: 'maternity', label: 'Maternity Leave' },
  { value: 'paternity', label: 'Paternity Leave' },
  { value: 'compassionate', label: 'Compassionate Leave' },
  { value: 'unpaid', label: 'Unpaid Leave' },
]

const headers = [
  { title: 'Employee', key: 'name' },
  { title: 'Department', key: 'department' },
  { title: 'Job title', key: 'job_title' },
  { title: 'Type', key: 'employment_type' },
  { title: 'Hired', key: 'hire_date' },
  { title: 'Salary', key: 'salary', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return items.value.filter(i => {
    if (filterDept.value && i.department !== filterDept.value) return false
    if (filterStatus.value && i.status !== filterStatus.value) return false
    if (q && !`${i.name} ${i.email} ${i.job_title}`.toLowerCase().includes(q)) return false
    return true
  })
})
const activeCount = computed(() => items.value.filter(i => i.status === 'active').length)
const inactiveCount = computed(() => items.value.filter(i => ['terminated', 'resigned', 'suspended'].includes(i.status)).length)
const onProbation = computed(() => items.value.filter(i => i.status === 'on_probation').length)
const avgTenure = computed(() => {
  const active = items.value.filter(i => i.hire_date)
  if (!active.length) return 0
  const years = active.map(i => (Date.now() - new Date(i.hire_date)) / 31536000000)
  return (years.reduce((a, b) => a + b, 0) / years.length).toFixed(1)
})
const supervisorOptions = computed(() => items.value.map(i => ({ id: i.id, name: i.name })))

function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function deptColor(d) {
  const map = { Nursing: 'pink', Caregiving: 'teal', Administration: 'indigo', Pharmacy: 'green', Laboratory: 'purple', Radiology: 'cyan', Finance: 'amber', IT: 'blue', Operations: 'orange' }
  return map[d] || 'teal'
}
function empTypeLabel(t) { return empTypes.find(e => e.value === t)?.label || t || '—' }
function empStatusKey(item) {
  if (item.status === 'active') return 'active'
  if (item.status === 'on_probation') return 'pending'
  if (item.status === 'on_leave') return 'scheduled'
  if (item.status === 'suspended') return 'overdue'
  if (item.status === 'terminated' || item.status === 'resigned') return 'closed'
  return 'draft'
}
function empStatusLabel(item) {
  return statusOptions.find(s => s.value === item.status)?.label || item.status
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  return 'KSh ' + Number(v).toLocaleString(undefined, { maximumFractionDigits: 0 })
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/hr/employees/', { params: { page_size: 500 } })
    items.value = (data?.results || data || []).map(e => ({ ...e, name: e.name || `${e.first_name || ''} ${e.last_name || ''}`.trim() }))
  } catch (e) {
    console.warn('load employees failed', e)
    items.value = []
  } finally { loading.value = false }
}

function openAdd() {
  editingId.value = null
  Object.assign(form, blankForm())
  dialog.value = true
}
function openEdit(item) {
  editingId.value = item.id
  Object.assign(form, blankForm(), {
    ...item,
    date_of_birth: item.date_of_birth || '',
    hire_date: item.hire_date || '',
    probation_end_date: item.probation_end_date || '',
  })
  dialog.value = true
  profileDialog.value = false
}
async function save() {
  if (!form.first_name || !form.last_name) { notify('First and last name are required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...form }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    if (editingId.value) {
      await $api.patch(`/homecare/hr/employees/${editingId.value}/`, payload)
      notify('Employee updated.')
    } else {
      await $api.post('/homecare/hr/employees/', payload)
      notify('Employee added.')
    }
    dialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save.', 'error')
  } finally { saving.value = false }
}

function viewProfile(item) {
  profileItem.value = item
  profileDialog.value = true
}
function openSelfService(item) {
  selfItem.value = { ...item }
  selfTab.value = 'profile'
  profileDialog.value = false
  selfServiceDialog.value = true
}
async function saveSelfProfile() {
  if (!selfItem.value) return
  saving.value = true
  try {
    await $api.patch(`/homecare/hr/employees/${selfItem.value.id}/self-service/`, {
      phone: selfItem.value.phone, address: selfItem.value.address,
      emergency_contact: selfItem.value.emergency_contact, bank_account: selfItem.value.bank_account,
    })
    notify('Profile updated.')
    selfServiceDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update.', 'error')
  } finally { saving.value = false }
}
async function submitTimesheet() {
  if (!timesheet.date || !timesheet.hours) { notify('Date and hours required.', 'error'); return }
  saving.value = true
  try {
    await $api.post('/homecare/hr/timesheets/', { employee: selfItem.value.id, ...timesheet })
    notify('Timesheet submitted.')
    Object.assign(timesheet, { date: '', hours: null, shift_type: 'day', notes: '' })
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to submit.', 'error')
  } finally { saving.value = false }
}
async function submitLeave() {
  if (!leaveForm.start_date || !leaveForm.end_date) { notify('Dates required.', 'error'); return }
  saving.value = true
  try {
    await $api.post('/homecare/hr/leave-requests/', { employee: selfItem.value.id, ...leaveForm })
    notify('Leave request submitted.')
    Object.assign(leaveForm, { leave_type: 'annual', start_date: '', end_date: '', reason: '' })
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to submit.', 'error')
  } finally { saving.value = false }
}

async function toggleStatus(item) {
  const newStatus = item.status === 'active' ? 'terminated' : 'active'
  try {
    await $api.patch(`/homecare/hr/employees/${item.id}/`, { status: newStatus })
    notify(`Employee ${newStatus === 'active' ? 'activated' : 'deactivated'}.`)
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  }
}

function goDocuments(item) {
  navigateTo(`/homecare/hr/documents?employee=${item.id}`)
}

function exportCsv() {
  const rows = filtered.value.map(i => ({
    Name: i.name, Email: i.email, Department: i.department, Title: i.job_title,
    Type: empTypeLabel(i.employment_type), Status: empStatusLabel(i),
    Hired: formatDate(i.hire_date), Salary: i.salary || '',
  }))
  const csv = [Object.keys(rows[0] || {}).join(','), ...rows.map(r => Object.values(r).join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = 'employees.csv'; a.click()
  URL.revokeObjectURL(url)
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
