<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Human Resources"
      subtitle="Manage the full employee lifecycle — recruitment, onboarding, scheduling, payroll, compliance & performance."
      eyebrow="ADMIN & MANAGEMENT · HR"
      icon="mdi-account-tie-group"
      :chips="[
        { icon: 'mdi-account-group', label: `${kpi.totalStaff} staff` },
        { icon: 'mdi-account-plus', label: `${kpi.openPositions} open roles` },
        { icon: 'mdi-calendar-check', label: `${kpi.onboarding} onboarding` },
        { icon: 'mdi-cash-multiple', label: `${money(kpi.monthlyPayroll)}/mo payroll` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-account-plus-outline"
               class="text-none" to="/homecare/hr/recruitment">
          <span class="text-teal-darken-2 font-weight-bold">Post a job</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- KPI strip -->
    <v-row dense>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Active Employees" :value="kpi.totalStaff" icon="mdi-account-group" color="#0d9488"
                         :hint="`${kpi.fullTime} full-time · ${kpi.partTime} part-time`" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Open Applications" :value="kpi.applicants" icon="mdi-account-arrow-left" color="#0ea5e9"
                         :hint="`${kpi.newApplicants} this week`" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="On Leave Today" :value="kpi.onLeave" icon="mdi-calendar-remove" color="#f59e0b"
                         :hint="`${kpi.pendingLeaves} requests pending`" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Compliance Score" :value="`${kpi.complianceScore}%`" icon="mdi-shield-check" color="#8b5cf6"
                         :trend="kpi.complianceTrend" trendLabel="vs last month" />
      </v-col>
    </v-row>

    <v-row dense class="mt-1">
      <!-- Quick actions -->
      <v-col cols="12" lg="4">
        <HomecarePanel title="Quick Actions" subtitle="Jump to a task" icon="mdi-lightning-bolt" color="#f59e0b">
          <div class="d-flex flex-wrap ga-2">
            <v-btn v-for="a in quickActions" :key="a.path" :to="a.path" variant="outlined" rounded="lg"
                   class="text-none" :prepend-icon="a.icon" size="large">
              {{ a.label }}
            </v-btn>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Department Headcount" icon="mdi-sitemap" color="#0ea5e9" class="mt-3">
          <div v-for="d in departments" :key="d.name" class="d-flex align-center mb-2">
            <v-icon :icon="d.icon" size="18" :color="d.color" class="mr-2" />
            <span class="text-body-2 flex-grow-1">{{ d.name }}</span>
            <span class="font-weight-bold mr-2">{{ d.count }}</span>
            <v-progress-linear :model-value="d.pct" :color="d.color" width="2" rounded
                               style="max-width:80px;" height="5" />
          </div>
          <EmptyState v-if="!departments.length" icon="mdi-sitemap-outline" title="No data" dense />
        </HomecarePanel>
      </v-col>

      <!-- Recruitment funnel + recent hires -->
      <v-col cols="12" lg="8">
        <HomecarePanel title="Recruitment Pipeline" subtitle="Applicants by stage" icon="mdi-account-plus-outline" color="#7c3aed">
          <v-row dense>
            <v-col v-for="s in funnel" :key="s.stage" cols="6" md="2">
              <div class="hc-funnel pa-3 rounded-lg text-center" :style="{ background: s.bg }">
                <v-icon :icon="s.icon" :color="s.color" size="22" />
                <div class="text-h5 font-weight-bold mt-1" :class="`text-${s.color}`">{{ s.count }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.stage }}</div>
              </div>
            </v-col>
          </v-row>
        </HomecarePanel>

        <HomecarePanel title="Recent Hires" subtitle="Latest additions to the team" icon="mdi-account-check" color="#10b981" class="mt-3">
          <v-table v-if="recentHires.length" density="compact">
            <thead>
              <tr><th>Name</th><th>Role</th><th>Department</th><th>Start date</th><th>Status</th></tr>
            </thead>
            <tbody>
              <tr v-for="h in recentHires" :key="h.id">
                <td>
                  <div class="d-flex align-center">
                    <v-avatar size="28" :color="avatarColor(h.name)" variant="tonal" class="mr-2">
                      <span class="text-caption font-weight-bold">{{ initials(h.name) }}</span>
                    </v-avatar>
                    {{ h.name }}
                  </div>
                </td>
                <td>{{ h.role }}</td>
                <td>{{ h.department }}</td>
                <td>{{ formatDate(h.start_date) }}</td>
                <td><StatusChip :status="h.status" /></td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-account-off" title="No recent hires" />
        </HomecarePanel>

        <HomecarePanel title="Upcoming Compliance Deadlines" subtitle="Licences, certifications & training expiry" icon="mdi-gavel" color="#ef4444" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="c in complianceItems" :key="c.id" rounded="lg" class="mb-1">
              <template #prepend>
                <v-avatar size="32" :color="daysColor(c.daysLeft)" variant="tonal">
                  <v-icon :icon="c.icon" size="16" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ c.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ c.type }} · {{ c.employee }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="tonal" :color="daysColor(c.daysLeft)">
                  <v-icon start :icon="c.daysLeft < 0 ? 'mdi-alert-octagon' : 'mdi-clock-outline'" size="14" />
                  {{ c.daysLeft < 0 ? `${Math.abs(c.daysLeft)}d overdue` : `${c.daysLeft}d left` }}
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!complianceItems.length" icon="mdi-shield-check" title="All clear" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const kpi = ref({
  totalStaff: 0, fullTime: 0, partTime: 0, openPositions: 0, applicants: 0,
  newApplicants: 0, onboarding: 0, onLeave: 0, pendingLeaves: 0,
  monthlyPayroll: 0, complianceScore: 0, complianceTrend: 0,
})
const departments = ref([])
const funnel = ref([])
const recentHires = ref([])
const complianceItems = ref([])
const snackbar = reactive({ show: false, color: 'success', text: '' })

const quickActions = [
  { label: 'Add Employee', icon: 'mdi-account-plus', path: '/homecare/hr/employees' },
  { label: 'Post Job', icon: 'mdi-briefcase-plus', path: '/homecare/hr/recruitment' },
  { label: 'Approve Leave', icon: 'mdi-calendar-check', path: '/homecare/hr/leave' },
  { label: 'Run Payroll', icon: 'mdi-cash-multiple', path: '/homecare/hr/payroll' },
  { label: 'Clock-in Report', icon: 'mdi-clock-time-eight', path: '/homecare/hr/scheduling' },
  { label: 'Compliance', icon: 'mdi-gavel', path: '/homecare/hr/compliance' },
]

function money(v) {
  if (v === null || v === undefined || v === '') return '—'
  const n = Number(v)
  if (Number.isNaN(n)) return '—'
  return 'KSh ' + n.toLocaleString(undefined, { maximumFractionDigits: 0 })
}
function formatDate(d) {
  if (!d) return ''
  try { return new Date(d).toLocaleDateString() } catch { return d }
}
function initials(name) {
  if (!name) return '?'
  return name.split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()
}
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function daysColor(days) {
  if (days < 0) return 'error'
  if (days <= 14) return 'warning'
  return 'success'
}

const funnelStages = [
  { stage: 'Applied', icon: 'mdi-email-outline', color: 'info', bg: 'rgba(14,165,233,0.08)' },
  { stage: 'Screening', icon: 'mdi-account-search', color: 'teal', bg: 'rgba(13,148,136,0.08)' },
  { stage: 'Interview', icon: 'mdi-account-question', color: 'amber', bg: 'rgba(245,158,11,0.08)' },
  { stage: 'Offer', icon: 'mdi-handshake', color: 'purple', bg: 'rgba(124,58,237,0.08)' },
  { stage: 'Hired', icon: 'mdi-account-check', color: 'success', bg: 'rgba(16,185,129,0.08)' },
  { stage: 'Declined', icon: 'mdi-account-remove', color: 'error', bg: 'rgba(239,68,68,0.08)' },
]

async function load() {
  try {
    const { data } = await $api.get('/homecare/hr/dashboard/').catch(() => ({ data: {} }))
    kpi.value = {
      totalStaff: data.total_staff ?? 0,
      fullTime: data.full_time ?? 0,
      partTime: data.part_time ?? 0,
      openPositions: data.open_positions ?? 0,
      applicants: data.applicants ?? 0,
      newApplicants: data.new_applicants ?? 0,
      onboarding: data.onboarding ?? 0,
      onLeave: data.on_leave ?? 0,
      pendingLeaves: data.pending_leaves ?? 0,
      monthlyPayroll: data.monthly_payroll ?? 0,
      complianceScore: data.compliance_score ?? 0,
      complianceTrend: data.compliance_trend ?? 0,
    }
    departments.value = (data.departments || []).map(d => ({
      name: d.name, count: d.count, pct: d.pct ?? 0,
      icon: d.icon || 'mdi-account-group', color: d.color || 'teal',
    }))
    funnel.value = funnelStages.map(s => ({
      ...s, count: (data.funnel || {})[s.stage.toLowerCase()] ?? 0
    }))
    recentHires.value = data.recent_hires || []
    complianceItems.value = (data.compliance || []).map(c => ({
      ...c, daysLeft: c.days_left ?? 0,
    }))
  } catch (e) {
    snackbar.color = 'error'
    snackbar.text = 'Failed to load HR dashboard.'
    snackbar.show = true
  }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
