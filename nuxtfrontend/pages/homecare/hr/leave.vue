<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Leave Management"
      subtitle="Track leave balances, approve requests, and maintain a shared team leave calendar."
      eyebrow="HR · LEAVE"
      icon="mdi-calendar-remove-outline"
      :chips="[
        { icon: 'mdi-clock-outline', label: `${pendingRequests} pending` },
        { icon: 'mdi-calendar-remove', label: `${onLeaveToday} on leave today` },
        { icon: 'mdi-calendar-check', label: `${approvedThisMonth} approved` },
        { icon: 'mdi-beach', label: `${upcomingLeave} upcoming` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-calendar-plus"
               class="text-none" @click="openRequestDialog">
          <span class="text-teal-darken-2 font-weight-bold">New request</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Pending" :value="pendingRequests" icon="mdi-clock-outline" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="On Leave Today" :value="onLeaveToday" icon="mdi-calendar-remove" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Approved (month)" :value="approvedThisMonth" icon="mdi-calendar-check" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Upcoming" :value="upcomingLeave" icon="mdi-beach" color="#8b5cf6" /></v-col>
    </v-row>

    <v-row dense>
      <!-- Requests -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Leave Requests" subtitle="Review and approve time-off" icon="mdi-calendar-clock" color="#0d9488">
          <template #actions>
            <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                      density="compact" variant="outlined" hide-details clearable
                      placeholder="Status" style="max-width:160px;" />
          </template>
          <v-data-table :headers="headers" :items="filteredRequests" :loading="loading" item-value="id" class="hc-table">
            <template #[`item.employee_name`]="{ item }">
              <div class="d-flex align-center">
                <v-avatar size="28" :color="avatarColor(item.employee_name)" variant="tonal" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(item.employee_name) }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium text-body-2">{{ item.employee_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.department }}</div>
                </div>
              </div>
            </template>
            <template #[`item.leave_type`]="{ item }">
              <v-chip size="small" variant="tonal" :prepend-icon="leaveIcon(item.leave_type)" :color="leaveColor(item.leave_type)">
                {{ leaveLabel(item.leave_type) }}
              </v-chip>
            </template>
            <template #[`item.dates`]="{ item }">
              {{ formatDate(item.start_date) }} – {{ formatDate(item.end_date) }}
              <div class="text-caption text-medium-emphasis">{{ item.days }} day(s)</div>
            </template>
            <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
            <template #[`item.actions`]="{ item }">
              <template v-if="item.status === 'pending'">
                <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check" class="mr-1" @click="approve(item)">Approve</v-btn>
                <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-close" @click="reject(item)">Reject</v-btn>
              </template>
              <v-btn v-else size="small" variant="text" prepend-icon="mdi-eye" @click="viewRequest(item)">View</v-btn>
            </template>
          </v-data-table>
        </HomecarePanel>
      </v-col>

      <!-- Balances & calendar -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Leave Balances" subtitle="Entitlement vs. used" icon="mdi-scale-balance" color="#7c3aed">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="b in balances" :key="b.employee_id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="28" :color="avatarColor(b.employee_name)" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ initials(b.employee_name) }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium text-body-2">{{ b.employee_name }}</v-list-item-title>
              <v-progress-linear :model-value="balancePct(b)" :color="balanceColor(b)" height="5" rounded class="mt-1" />
              <div class="text-caption text-medium-emphasis mt-1">
                {{ b.annual_used }}/{{ b.annual_total }} annual · {{ b.sick_used }}/{{ b.sick_total }} sick
              </div>
            </v-list-item>
            <EmptyState v-if="!balances.length" icon="mdi-scale-balance" title="No balances" dense />
          </v-list>
        </HomecarePanel>

        <HomecarePanel title="Team Calendar" subtitle="Who's off" icon="mdi-calendar-month" color="#0ea5e9" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="c in calendar" :key="c.id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" :color="leaveColor(c.leave_type)" variant="tonal">
                  <v-icon :icon="leaveIcon(c.leave_type)" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium text-body-2">{{ c.employee_name }}</v-list-item-title>
              <v-list-item-subtitle>{{ formatDate(c.start_date) }} – {{ formatDate(c.end_date) }}</v-list-item-subtitle>
            </v-list-item>
            <EmptyState v-if="!calendar.length" icon="mdi-calendar-blank" title="No upcoming leave" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Request dialog -->
    <v-dialog v-model="requestDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-calendar-plus" class="mr-2" />Leave Request</v-card-title>
        <v-divider />
        <v-card-text>
          <v-select v-model="requestForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Employee *" density="comfortable" variant="outlined" />
          <v-select v-model="requestForm.leave_type" :items="leaveTypes" item-title="label" item-value="value"
                    label="Leave type *" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="requestForm.start_date" label="Start *" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6"><v-text-field v-model="requestForm.end_date" label="End *" type="date" density="comfortable" variant="outlined" /></v-col>
          </v-row>
          <v-textarea v-model="requestForm.reason" label="Reason" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="requestDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="submitRequest">Submit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- View dialog -->
    <v-dialog v-model="viewDialog" max-width="460">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-calendar-eye" class="mr-2" />Leave Details</v-card-title>
        <v-divider />
        <v-card-text v-if="viewItem">
          <v-row dense>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Employee</div><div class="font-weight-medium">{{ viewItem.employee_name }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Type</div><div class="font-weight-medium">{{ leaveLabel(viewItem.leave_type) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">From</div><div class="font-weight-medium">{{ formatDate(viewItem.start_date) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">To</div><div class="font-weight-medium">{{ formatDate(viewItem.end_date) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Days</div><div class="font-weight-medium">{{ viewItem.days }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Status</div><div><StatusChip :status="viewItem.status" /></div></v-col>
            <v-col v-if="viewItem.reason" cols="12"><div class="text-caption text-medium-emphasis">Reason</div><div>{{ viewItem.reason }}</div></v-col>
            <v-col v-if="viewItem.approver_name" cols="12"><div class="text-caption text-medium-emphasis">Approved by</div><div>{{ viewItem.approver_name }}</div></v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="viewDialog = false">Close</v-btn>
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

const requests = ref([])
const balances = ref([])
const calendar = ref([])
const employees = ref([])
const loading = ref(false)
const saving = ref(false)
const statusFilter = ref(null)
const requestDialog = ref(false)
const viewDialog = ref(false)
const viewItem = ref(null)

const requestForm = reactive({ employee: null, leave_type: 'annual', start_date: '', end_date: '', reason: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const statusOptions = [
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'cancelled', label: 'Cancelled' },
]
const leaveTypes = [
  { value: 'annual', label: 'Annual Leave' },
  { value: 'sick', label: 'Sick Leave' },
  { value: 'maternity', label: 'Maternity' },
  { value: 'paternity', label: 'Paternity' },
  { value: 'compassionate', label: 'Compassionate' },
  { value: 'unpaid', label: 'Unpaid' },
]

const headers = [
  { title: 'Employee', key: 'employee_name' },
  { title: 'Type', key: 'leave_type' },
  { title: 'Dates', key: 'dates', sortable: false },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false },
]

const filteredRequests = computed(() => {
  if (!statusFilter.value) return requests.value
  return requests.value.filter(r => r.status === statusFilter.value)
})
const pendingRequests = computed(() => requests.value.filter(r => r.status === 'pending').length)
const onLeaveToday = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return requests.value.filter(r => r.status === 'approved' && r.start_date <= today && r.end_date >= today).length
})
const approvedThisMonth = computed(() => {
  const m = new Date().toISOString().slice(0, 7)
  return requests.value.filter(r => r.status === 'approved' && r.start_date?.startsWith(m)).length
})
const upcomingLeave = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return requests.value.filter(r => r.status === 'approved' && r.start_date > today).length
})

function leaveLabel(t) { return leaveTypes.find(l => l.value === t)?.label || t }
function leaveIcon(t) {
  const map = { annual: 'mdi-beach', sick: 'mdi-thermometer', maternity: 'mdi-baby-carriage', paternity: 'mdi-baby', compassionate: 'mdi-heart-broken', unpaid: 'mdi-calendar-minus' }
  return map[t] || 'mdi-calendar'
}
function leaveColor(t) {
  const map = { annual: 'teal', sick: 'error', maternity: 'pink', paternity: 'blue', compassionate: 'purple', unpaid: 'grey' }
  return map[t] || 'teal'
}
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function balancePct(b) {
  if (!b.annual_total) return 0
  return Math.round(b.annual_used / b.annual_total * 100)
}
function balanceColor(b) {
  const pct = balancePct(b)
  if (pct >= 90) return 'error'
  if (pct >= 75) return 'warning'
  return 'success'
}

async function load() {
  loading.value = true
  try {
    const [req, bal, cal, emp] = await Promise.all([
      $api.get('/homecare/hr/leave-requests/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/leave-balances/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/leave-calendar/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/employees/', { params: { page_size: 500, status: 'active' } }).catch(() => ({ data: [] })),
    ])
    requests.value = req.data?.results || req.data || []
    balances.value = bal.data?.results || bal.data || []
    calendar.value = cal.data?.results || cal.data || []
    employees.value = (emp.data?.results || emp.data || []).map(e => ({ id: e.id, name: e.name || `${e.first_name || ''} ${e.last_name || ''}`.trim() }))
  } catch (e) {
    console.warn('load leave failed', e)
  } finally { loading.value = false }
}

function openRequestDialog() {
  Object.assign(requestForm, { employee: null, leave_type: 'annual', start_date: '', end_date: '', reason: '' })
  requestDialog.value = true
}
async function submitRequest() {
  if (!requestForm.employee || !requestForm.start_date || !requestForm.end_date) { notify('All fields required.', 'error'); return }
  saving.value = true
  try {
    await $api.post('/homecare/hr/leave-requests/', { ...requestForm })
    notify('Leave request submitted.')
    requestDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to submit.', 'error')
  } finally { saving.value = false }
}

async function approve(item) {
  try {
    await $api.post(`/homecare/hr/leave-requests/${item.id}/approve/`, {})
    notify('Leave approved.')
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  }
}
async function reject(item) {
  try {
    await $api.post(`/homecare/hr/leave-requests/${item.id}/reject/`, {})
    notify('Leave rejected.')
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  }
}
function viewRequest(item) { viewItem.value = item; viewDialog.value = true }

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
