<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-account-multiple-outline"
      eyebrow="IMS · CUSTOMER CRM · COMMAND CENTER"
      title="Customer CRM"
      subtitle="Every customer, conversation, deal and support case in one workspace — segments, loyalty, pipeline and service quality."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-glass" prepend-icon="mdi-account-plus-outline" to="/ims/crm/customers?new=1">
          Add customer
        </v-btn>
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openQuickLog">
          Log activity
        </v-btn>
      </template>
    </CrmHero>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" :hint="k.hint" flat />
      </v-col>
    </v-row>

    <v-row dense class="mb-3">
      <!-- Lifecycle funnel -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="primary">mdi-filter-variant</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Customer lifecycle</div>
                <div class="text-caption text-medium-emphasis">Where the base sits right now</div>
              </div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/crm/customers" append-icon="mdi-arrow-right">
              All customers
            </v-btn>
          </div>
          <v-divider />
          <v-card-text class="pt-4">
            <div class="crm-funnel">
              <div v-for="row in lifecycleRows" :key="row.key" class="crm-funnel-row">
                <div class="crm-funnel-label">
                  <v-icon size="15" :color="row.color">{{ row.icon }}</v-icon>
                  {{ row.label }}
                </div>
                <div class="crm-funnel-track">
                  <div class="crm-funnel-fill" :style="{ width: row.pct + '%', background: row.hex }" />
                </div>
                <div class="crm-funnel-count">{{ row.count }}</div>
                <div class="crm-funnel-pct">{{ row.share }}%</div>
              </div>
            </div>

            <v-divider class="my-4" />

            <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Loyalty tiers</div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip v-for="t in tierChips" :key="t.key" size="small" variant="tonal" :color="t.color" rounded="lg" class="text-none">
                <v-icon start size="14">{{ t.icon }}</v-icon>
                {{ t.label }}
                <span class="ml-1 font-weight-bold">{{ t.count }}</span>
              </v-chip>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- Attention -->
      <v-col cols="12" lg="4">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="error">mdi-alert-decagram-outline</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Needs attention</div>
              <div class="text-caption text-medium-emphasis">{{ attention.length }} item(s) flagged</div>
            </div>
          </div>
          <v-divider />
          <v-card-text class="pt-3">
            <div v-if="!attention.length" class="crm-empty">
              <v-icon size="38" color="success">mdi-check-decagram</v-icon>
              <div class="text-body-2 font-weight-medium mt-2">All clear</div>
              <div class="text-caption text-medium-emphasis">No overdue follow-ups or escalations.</div>
            </div>
            <div v-else class="crm-attention">
              <div v-for="a in attention" :key="a.key" class="crm-attention-row" :class="`crm-attention--${a.tone}`">
                <v-icon size="18" :color="a.tone === 'error' ? 'error' : a.tone === 'warning' ? 'amber' : 'primary'">{{ a.icon }}</v-icon>
                <div class="flex-grow-1">
                  <div class="text-body-2 font-weight-medium">{{ a.title }}</div>
                  <div class="text-caption text-medium-emphasis">{{ a.detail }}</div>
                </div>
                <v-btn :to="a.to" size="x-small" variant="text" class="text-none" :color="a.tone === 'error' ? 'error' : 'primary'">Open</v-btn>
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense class="mb-2">
      <!-- Top customers -->
      <v-col cols="12" lg="7">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="amber-darken-2">mdi-trophy-outline</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Top customers</div>
                <div class="text-caption text-medium-emphasis">By lifetime spend</div>
              </div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/crm/analytics" append-icon="mdi-arrow-right">Analytics</v-btn>
          </div>
          <v-divider />
          <v-table v-if="leaders.length" density="comfortable" class="crm-table">
            <thead>
              <tr><th>Customer</th><th>Tier</th><th class="text-right">Visits</th><th class="text-right">Spend</th></tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in leaders" :key="c.id" class="crm-row" @click="goCustomer(c.id)">
                <td>
                  <div class="d-flex align-center ga-3">
                    <v-avatar size="30" :color="avatarColor(c.name)" variant="flat" class="text-white font-weight-bold" style="font-size: 11px">
                      {{ initials(c.name) }}
                    </v-avatar>
                    <div>
                      <div class="font-weight-medium">{{ c.name }}</div>
                      <div class="text-caption text-medium-emphasis">{{ c.phone }}</div>
                    </div>
                    <v-chip v-if="i === 0" size="x-small" color="amber" variant="tonal" class="font-weight-bold">#1</v-chip>
                  </div>
                </td>
                <td>
                  <v-chip size="x-small" variant="tonal" :color="tierMeta(c.loyalty_tier).color">
                    <v-icon start size="11">{{ tierMeta(c.loyalty_tier).icon }}</v-icon>{{ tierMeta(c.loyalty_tier).label }}
                  </v-chip>
                </td>
                <td class="text-right">{{ c.visit_count }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(c.total_purchases) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="crm-empty pa-6">
            <v-icon size="40" color="medium-emphasis">mdi-account-multiple-outline</v-icon>
            <div class="text-body-2 font-weight-medium mt-2">No customers yet</div>
            <div class="text-caption text-medium-emphasis">Add your first customer to start building the CRM.</div>
          </div>
        </v-card>
      </v-col>

      <!-- Service + pipeline snapshot -->
      <v-col cols="12" lg="5">
        <v-card rounded="xl" border class="mb-3">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-lifebuoy</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Support desk</div>
              <div class="text-caption text-medium-emphasis">Open cases by status</div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-service-grid mb-3">
              <div class="crm-service-tile crm-service--bad">
                <div class="crm-service-value">{{ ticketStats.open ?? 0 }}</div>
                <div class="crm-service-label">open</div>
              </div>
              <div class="crm-service-tile crm-service--warn">
                <div class="crm-service-value">{{ ticketStats.in_progress ?? 0 }}</div>
                <div class="crm-service-label">in progress</div>
              </div>
              <div class="crm-service-tile crm-service--good">
                <div class="crm-service-value">{{ ticketStats.resolved ?? 0 }}</div>
                <div class="crm-service-label">resolved</div>
              </div>
            </div>
            <div class="crm-kv"><span>Overdue (SLA)</span><strong class="text-error">{{ ticketStats.overdue ?? 0 }}</strong></div>
            <div class="crm-kv"><span>Urgent</span><strong>{{ ticketStats.urgent ?? 0 }}</strong></div>
            <div class="crm-kv"><span>Avg resolution</span><strong>{{ ticketStats.avg_resolution_hours ?? 0 }}h</strong></div>
            <v-btn block variant="tonal" color="primary" rounded="lg" class="text-none mt-3" prepend-icon="mdi-arrow-right-circle-outline" to="/ims/crm/tickets">
              Open support desk
            </v-btn>
          </v-card-text>
        </v-card>

        <v-card rounded="xl" border>
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="success">mdi-chart-timeline-variant-shimmer</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Sales pipeline</div>
              <div class="text-caption text-medium-emphasis">Open opportunities</div>
            </div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="d-flex align-center justify-space-between mb-2">
              <span class="text-caption text-medium-emphasis">Pipeline value</span>
              <span class="text-body-1 font-weight-bold">{{ formatMoney(oppStats.pipeline_value || 0) }}</span>
            </div>
            <v-progress-linear :model-value="winRatePct" color="success" height="8" rounded bg-color="surface-variant" class="mb-1" />
            <div class="d-flex justify-space-between text-caption text-medium-emphasis mb-3">
              <span>Win rate</span><span>{{ oppStats.win_rate ?? 0 }}%</span>
            </div>
            <div class="crm-kv"><span>Open deals</span><strong>{{ oppStats.open ?? 0 }}</strong></div>
            <div class="crm-kv"><span>Won value</span><strong>{{ formatMoney(oppStats.won_value || 0) }}</strong></div>
            <v-btn block variant="tonal" color="success" rounded="lg" class="text-none mt-3" prepend-icon="mdi-kanban" to="/ims/crm/pipeline">
              Open pipeline
            </v-btn>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <!-- Recent activity -->
      <v-col cols="12" lg="7">
        <v-card rounded="xl" border class="h-100">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="primary">mdi-history</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Recent activity</div>
                <div class="text-caption text-medium-emphasis">Latest customer touchpoints</div>
              </div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/crm/activities" append-icon="mdi-arrow-right">All activity</v-btn>
          </div>
          <v-divider />
          <v-card-text v-if="recentInteractions.length" class="pt-3">
            <div v-for="i in recentInteractions" :key="i.id" class="crm-timeline-item">
              <div class="crm-timeline-dot" :style="{ background: interactionMeta(i.kind).color }">
                <v-icon size="12" color="white">{{ interactionMeta(i.kind).icon }}</v-icon>
              </div>
              <div class="flex-grow-1">
                <div class="d-flex align-center justify-space-between ga-2">
                  <span class="text-body-2 font-weight-medium">{{ i.subject }}</span>
                  <span class="text-caption text-medium-emphasis text-no-wrap">{{ rel(i.occurred_at) }}</span>
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ i.customer_name }} · {{ interactionMeta(i.kind).label }} · {{ i.created_by_name || 'System' }}
                </div>
              </div>
            </div>
          </v-card-text>
          <div v-else class="crm-empty pa-6">
            <v-icon size="40" color="medium-emphasis">mdi-history</v-icon>
            <div class="text-body-2 font-weight-medium mt-2">No activity logged yet</div>
            <div class="text-caption text-medium-emphasis">Log a call, email or meeting to build the timeline.</div>
          </div>
        </v-card>
      </v-col>

      <!-- Tasks + birthdays -->
      <v-col cols="12" lg="5">
        <v-card rounded="xl" border class="mb-3">
          <div class="d-flex align-center justify-space-between pa-4 pb-2">
            <div class="d-flex align-center" style="gap:10px">
              <v-icon color="primary">mdi-checkbox-marked-circle-outline</v-icon>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Follow-ups due</div>
                <div class="text-caption text-medium-emphasis">{{ taskStats.overdue ?? 0 }} overdue · {{ taskStats.due_today ?? 0 }} today</div>
              </div>
            </div>
            <v-btn variant="text" size="small" class="text-none" color="primary" to="/ims/crm/activities">All</v-btn>
          </div>
          <v-divider />
          <v-card-text v-if="dueTasks.length" class="pt-3">
            <div v-for="t in dueTasks" :key="t.id" class="crm-task-row">
              <v-checkbox-btn color="success" density="compact" hide-details @click="completeTask(t)" />
              <div class="flex-grow-1">
                <div class="text-body-2 font-weight-medium">{{ t.title }}</div>
                <div class="text-caption text-medium-emphasis">{{ t.customer_name || 'General' }} · due {{ dt(t.due_at) }}</div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="priorityMeta(t.priority).color">{{ priorityMeta(t.priority).label }}</v-chip>
            </div>
          </v-card-text>
          <div v-else class="crm-empty pa-5">
            <v-icon size="32" color="success">mdi-check-decagram</v-icon>
            <div class="text-caption text-medium-emphasis mt-1">No follow-ups outstanding</div>
          </div>
        </v-card>

        <v-card rounded="xl" border>
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="pink">mdi-cake-variant-outline</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Upcoming birthdays</div>
              <div class="text-caption text-medium-emphasis">Next 30 days</div>
            </div>
          </div>
          <v-divider />
          <v-card-text v-if="birthdayRows.length" class="pt-3">
            <div v-for="b in birthdayRows" :key="b.id" class="d-flex align-center justify-space-between py-1">
              <div class="d-flex align-center ga-2">
                <v-avatar size="26" :color="avatarColor(b.name)" variant="flat" class="text-white" style="font-size: 10px">
                  {{ initials(b.name) }}
                </v-avatar>
                <span class="text-body-2">{{ b.name }}</span>
              </div>
              <v-chip size="x-small" variant="tonal" color="pink">
                {{ b.in_days === 0 ? 'Today' : `in ${b.in_days}d` }}
              </v-chip>
            </div>
          </v-card-text>
          <div v-else class="crm-empty pa-5">
            <div class="text-caption text-medium-emphasis">No birthdays in the next 30 days.</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- quick activity dialog -->
    <v-dialog v-model="quickDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          title="Log customer activity"
          subtitle="Quick touchpoint capture"
          @close="quickDialog = false"
        />
        <v-card-text>
          <v-select
            v-model="quickForm.customer"
            :items="customerOptions"
            item-title="label"
            item-value="id"
            label="Customer *"
            variant="outlined"
            density="comfortable"
            class="mb-2"
            :loading="loadingOptions"
          />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="quickForm.kind" :items="interactionKinds" item-title="label" item-value="value" label="Type" variant="outlined" density="comfortable" />
            <v-select v-model="quickForm.direction" :items="directions" item-title="label" item-value="value" label="Direction" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="quickForm.subject" label="Subject *" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="quickForm.summary" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="quickForm.outcome" :items="outcomes" item-title="label" item-value="value" label="Outcome" variant="outlined" density="comfortable" class="mb-2" />
          <v-switch v-model="quickForm.follow_up_required" color="primary" density="compact" hide-details label="Schedule follow-up" class="mb-2" />
          <v-text-field v-if="quickForm.follow_up_required" v-model="quickForm.follow_up_at" type="datetime-local" label="Follow-up at" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="quickDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveQuick">Save activity</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import {
  avatarColor, crmPriority, initials, interactionMeta, lifecycleMeta,
  stageMeta, tierMeta, useCrm,
} from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const {
  customers, customerStats, leaderboard, birthdays, interactions, interactionStats,
  tasks, taskStats: fetchTaskStats, tickets: fetchTickets, ticketStats: fetchTicketStats,
  opportunities: fetchOpportunities, opportunityStats: fetchOpportunityStats,
  completeTask: completeTaskApi, unpack,
} = useCrm()

const priorityMeta = crmPriority

const loading = ref(false)
const saving = ref(false)
const loadingOptions = ref(false)
const stats = ref({})
const leaders = ref([])
const birthdayRows = ref([])
const recentInteractions = ref([])
const dueTasks = ref([])
const taskStatsData = ref({})
const ticketStatsData = ref({})
const oppStatsData = ref({})
const interactionStatsData = ref({})
const customerOptions = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const quickDialog = ref(false)

const quickForm = reactive({
  customer: null, kind: 'call', direction: 'outbound', subject: '',
  summary: '', outcome: 'connected', follow_up_required: false, follow_up_at: '',
})

const interactionKinds = Object.entries({
  call: 'Phone call', email: 'Email', sms: 'SMS', whatsapp: 'WhatsApp',
  meeting: 'Meeting', visit: 'Site visit', note: 'Note', complaint: 'Complaint',
}).map(([value, label]) => ({ value, label }))

const directions = [
  { value: 'inbound', label: 'Inbound' },
  { value: 'outbound', label: 'Outbound' },
  { value: 'internal', label: 'Internal' },
]

const outcomes = [
  { value: 'connected', label: 'Connected' },
  { value: 'no_answer', label: 'No answer' },
  { value: 'left_message', label: 'Left message' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'follow_up', label: 'Follow-up required' },
  { value: 'no_action', label: 'No action' },
]

const ticketStats = computed(() => ticketStatsData.value || {})
const taskStats = computed(() => taskStatsData.value || {})
const oppStats = computed(() => oppStatsData.value || {})
const interStats = computed(() => interactionStatsData.value || {})

const heroFacts = computed(() => [
  { value: stats.value.total_customers ?? 0, label: 'customers' },
  { value: stats.value.vip ?? 0, label: 'VIP' },
  { value: formatMoney(stats.value.lifetime_value || 0), label: 'lifetime value' },
  { value: stats.value.at_risk ?? 0, label: 'at risk' },
])

const kpis = computed(() => [
  {
    title: 'Total customers', value: stats.value.total_customers ?? 0,
    sub: `${stats.value.new_30_days ?? 0} new in 30 days`,
    icon: 'mdi-account-multiple-outline', color: 'primary', hint: 'Active + inactive',
  },
  {
    title: 'Lifetime value', value: formatMoney(stats.value.lifetime_value || 0),
    sub: 'all-time spend',
    icon: 'mdi-cash-multiple', color: 'success', hint: 'Sum of customer purchases',
  },
  {
    title: 'Open tickets', value: stats.value.open_tickets ?? 0,
    sub: `${ticketStats.value.overdue ?? 0} overdue`,
    icon: 'mdi-lifebuoy', color: 'error', hint: 'Support cases in flight',
  },
  {
    title: 'Pipeline', value: formatMoney(stats.value.pipeline_value || 0),
    sub: `${stats.value.open_opportunities ?? 0} open deals`,
    icon: 'mdi-chart-timeline-variant-shimmer', color: 'info', hint: 'Weighted opportunities',
  },
  {
    title: 'Follow-ups due', value: stats.value.follow_ups_due ?? 0,
    sub: `${taskStats.value.overdue ?? 0} overdue tasks`,
    icon: 'mdi-clock-alert-outline', color: 'amber', hint: 'Next action required',
  },
  {
    title: 'Loyalty points', value: (stats.value.loyalty_points ?? 0).toLocaleString(),
    sub: `avg health ${stats.value.avg_health ?? 0}`,
    icon: 'mdi-star-circle-outline', color: 'deep-purple', hint: 'Outstanding point liability',
  },
])

const lifecycleRows = computed(() => {
  const by = stats.value.by_lifecycle || {}
  const total = Object.values(by).reduce((a, b) => a + b, 0) || 1
  return ['lead', 'prospect', 'active', 'at_risk', 'dormant', 'churned'].map((key) => {
    const meta = lifecycleMeta(key)
    const count = by[key] || 0
    return {
      key, label: meta.label, icon: meta.icon, color: meta.color,
      hex: key === 'active' ? '#16a34a' : key === 'at_risk' ? '#d97706' : key === 'churned' ? '#dc2626' : key === 'prospect' ? '#2563eb' : key === 'lead' ? '#6b7280' : '#64748b',
      count, share: Math.round((count / total) * 100),
      pct: total ? Math.max(2, Math.round((count / total) * 100)) : 0,
    }
  })
})

const tierChips = computed(() => {
  const by = stats.value.by_tier || {}
  return ['bronze', 'silver', 'gold', 'platinum'].map((key) => ({
    key, ...tierMeta(key), count: by[key] || 0,
  }))
})

const winRatePct = computed(() => Math.min(100, Number(oppStats.value.win_rate || 0)))

const attention = computed(() => {
  const list = []
  if (ticketStats.value.overdue) {
    list.push({
      key: 'sla', tone: 'error', icon: 'mdi-timer-alert-outline',
      title: `${ticketStats.value.overdue} ticket(s) past SLA`,
      detail: 'Escalate to the support team now.', to: '/ims/crm/tickets?status=open',
    })
  }
  if (taskStats.value.overdue) {
    list.push({
      key: 'tasks', tone: 'warning', icon: 'mdi-clock-alert-outline',
      title: `${taskStats.value.overdue} overdue follow-up(s)`,
      detail: 'Close or reschedule outstanding tasks.', to: '/ims/crm/activities',
    })
  }
  if (stats.value.at_risk) {
    list.push({
      key: 'risk', tone: 'warning', icon: 'mdi-account-alert-outline',
      title: `${stats.value.at_risk} customer(s) at risk of churn`,
      detail: 'Re-engage with a targeted campaign.', to: '/ims/crm/customers?risk=high',
    })
  }
  if (interStats.value.overdue_follow_ups) {
    list.push({
      key: 'followup', tone: 'info', icon: 'mdi-phone-clock',
      title: `${interStats.value.overdue_follow_ups} interaction follow-up(s) overdue`,
      detail: 'Contact customers who are waiting on you.', to: '/ims/crm/activities',
    })
  }
  return list
})

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function rel(v) {
  if (!v) return '—'
  const t = new Date(v).getTime()
  if (Number.isNaN(t)) return '—'
  const mins = Math.round(Math.abs(Date.now() - t) / 60000)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.round(hours / 24)}d ago`
}

function goCustomer(id) {
  navigateTo(`/ims/crm/customers/${id}`)
}

async function load() {
  loading.value = true
  try {
    const [st, lead, bdays, inter, ist, tsk, tst, tix, txst, opp, opst] = await Promise.all([
      customerStats(),
      leaderboard(8),
      birthdays(30),
      interactions({ page_size: 8, ordering: '-occurred_at' }),
      interactionStats(),
      tasks({ page_size: 6, ordering: 'due_at' }),
      fetchTaskStats(),
      fetchTickets({ page_size: 1 }),
      fetchTicketStats(),
      fetchOpportunities({ page_size: 1 }),
      fetchOpportunityStats(),
    ])
    stats.value = st.data || {}
    leaders.value = lead.data || []
    birthdayRows.value = (bdays.data || []).slice(0, 5)
    recentInteractions.value = unpack(inter)
    interactionStatsData.value = ist.data || {}
    dueTasks.value = unpack(tsk).filter((t) => !['done', 'cancelled'].includes(t.status)).slice(0, 5)
    taskStatsData.value = tst.data || {}
    ticketStatsData.value = txst.data || {}
    oppStatsData.value = opst.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load CRM dashboard' }
  } finally {
    loading.value = false
  }
}

async function openQuickLog() {
  quickDialog.value = true
  if (customerOptions.value.length) return
  loadingOptions.value = true
  try {
    const { data } = await customers({ page_size: 200 })
    customerOptions.value = (data?.results || data || []).map((c) => ({
      ...c, label: `${c.name} · ${c.phone}`,
    }))
  } catch { /* ignore */ } finally {
    loadingOptions.value = false
  }
}

async function saveQuick() {
  if (!quickForm.customer || !quickForm.subject) {
    snack.value = { show: true, color: 'error', text: 'Customer and subject are required' }
    return
  }
  saving.value = true
  try {
    const body = {
      customer: quickForm.customer,
      kind: quickForm.kind,
      direction: quickForm.direction,
      subject: quickForm.subject,
      summary: quickForm.summary,
      outcome: quickForm.outcome,
      follow_up_required: quickForm.follow_up_required,
      occurred_at: new Date().toISOString(),
    }
    if (quickForm.follow_up_required && quickForm.follow_up_at) {
      body.follow_up_at = new Date(quickForm.follow_up_at).toISOString()
    }
    await $api.post('/crm/interactions/', body)
    quickDialog.value = false
    quickForm.subject = ''
    quickForm.summary = ''
    snack.value = { show: true, color: 'success', text: 'Activity logged' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to log activity' }
  } finally {
    saving.value = false
  }
}

async function completeTask(t) {
  try {
    await completeTaskApi(t.id)
    snack.value = { show: true, color: 'success', text: 'Task completed' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to complete task' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong {
  background: #fff !important; color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important;
  box-shadow: 0 6px 18px rgba(6,44,40,.28) !important;
}
.crm-hero-btn-glass {
  background: rgba(255,255,255,.16) !important; color: #fff !important;
  font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important;
  backdrop-filter: blur(6px);
}
.crm-hero-btn-glass:hover { background: rgba(255,255,255,.26) !important; }
.crm-funnel-row {
  display: grid; grid-template-columns: 130px 1fr 46px 46px;
  align-items: center; gap: 10px; margin-bottom: 9px;
}
.crm-funnel-label { display: flex; align-items: center; gap: 6px; font-size: 12.5px; }
.crm-funnel-track { height: 9px; border-radius: 999px; background: rgba(var(--v-theme-surface-variant), .7); overflow: hidden; }
.crm-funnel-fill { height: 100%; border-radius: 999px; transition: width .3s; }
.crm-funnel-count { text-align: right; font-size: 12.5px; font-weight: 700; }
.crm-funnel-pct { text-align: right; font-size: 11px; color: rgba(var(--v-theme-on-surface), .55); }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
.crm-attention { display: flex; flex-direction: column; gap: 8px; }
.crm-attention-row {
  display: flex; align-items: flex-start; gap: 10px; padding: 10px 12px;
  border-radius: 12px; border: 1px solid rgba(var(--v-border-color), .14);
}
.crm-attention--error { border-color: rgba(239,68,68,.28); background: rgba(239,68,68,.05); }
.crm-attention--warning { border-color: rgba(245,158,11,.28); background: rgba(245,158,11,.05); }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-row { cursor: pointer; }
.crm-row:hover { background: rgba(var(--v-theme-primary), .04); }
.crm-service-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.crm-service-tile { border-radius: 12px; padding: 10px 8px; text-align: center; border: 1px solid rgba(var(--v-border-color), .14); }
.crm-service--good { background: rgba(16,185,129,.08); border-color: rgba(16,185,129,.24); }
.crm-service--warn { background: rgba(245,158,11,.08); border-color: rgba(245,158,11,.24); }
.crm-service--bad { background: rgba(239,68,68,.08); border-color: rgba(239,68,68,.24); }
.crm-service-value { font-size: 19px; font-weight: 800; line-height: 1.1; }
.crm-service-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-kv { display: flex; align-items: center; justify-content: space-between; padding: 4px 0; font-size: 13px; }
.crm-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.crm-timeline-item { display: flex; gap: 12px; padding: 8px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-timeline-item:last-child { border-bottom: none; }
.crm-timeline-dot {
  width: 24px; height: 24px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.crm-task-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-task-row:last-child { border-bottom: none; }
</style>
