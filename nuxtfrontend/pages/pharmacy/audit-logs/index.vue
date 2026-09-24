<template>
  <v-container fluid class="pa-3 pa-md-5 audit-logs">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="deep-purple-lighten-5" variant="tonal" rounded="lg" size="52">
          <v-icon size="28" color="deep-purple-darken-2">mdi-history</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ $t('auditLogs.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">
            {{ $t('auditLogs.subtitle') }}
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg"
               class="text-none" :loading="loading" @click="reloadAll">{{ $t('common.refresh') }}</v-btn>
        <v-menu>
          <template #activator="{ props }">
            <v-btn color="primary" prepend-icon="mdi-download" rounded="lg"
                   class="text-none" v-bind="props">{{ $t('roles.newRole').startsWith('New') ? 'Export' : 'Export' }}</v-btn>
          </template>
          <v-list density="compact">
            <v-list-item prepend-icon="mdi-file-delimited" @click="exportData('csv')">
              <v-list-item-title>{{ $t('auditLogs.exportCsv') }}</v-list-item-title>
            </v-list-item>
            <v-list-item prepend-icon="mdi-code-json" @click="exportData('json')">
              <v-list-item-title>{{ $t('auditLogs.exportJson') }}</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
      </div>
    </div>

    <!-- ─────────────────────────────────────────────────────────────── -->
    <!-- KPI tiles                                                          -->
    <!-- ─────────────────────────────────────────────────────────────── -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" style="border:1px solid rgba(99,102,241,0.08)">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">{{ $t('auditLogs.totalEvents') }}</div>
              <div class="text-h5 font-weight-bold mt-1">{{ kpis.total?.toLocaleString() || 0 }}</div>
            </div>
            <v-avatar color="indigo" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-counter</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" style="border:1px solid rgba(34,197,94,0.08)">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">{{ $t('auditLogs.last24h') }}</div>
              <div class="text-h5 font-weight-bold mt-1">{{ kpis.last_24h?.toLocaleString() || 0 }}</div>
            </div>
            <v-avatar color="success" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-clock-outline</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" style="border:1px solid rgba(245,158,11,0.08)">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">{{ $t('auditLogs.distinctActors') }}</div>
              <div class="text-h5 font-weight-bold mt-1">{{ kpis.distinct_actors?.toLocaleString() || 0 }}</div>
            </div>
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-account-group</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" style="border:1px solid rgba(239,68,68,0.08)">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">{{ $t('auditLogs.critical') }}</div>
              <div class="text-h5 font-weight-bold mt-1 text-error">
                {{ kpis.critical?.toLocaleString() || 0 }}
              </div>
            </div>
            <v-avatar color="error" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-alert-circle</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Two sparate secondary KPIs -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-3 kpi-card" style="border:1px solid rgba(99,102,241,0.06)">
          <div class="d-flex align-center" style="gap:10px">
            <v-icon color="warning">mdi-alert</v-icon>
            <div>
              <div class="text-caption text-medium-emphasis">{{ $t('auditLogs.warnings') }}</div>
              <div class="text-body-1 font-weight-bold">{{ kpis.warnings?.toLocaleString() || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-3 kpi-card" style="border:1px solid rgba(239,68,68,0.06)">
          <div class="d-flex align-center" style="gap:10px">
            <v-icon color="error">mdi-cloud-alert</v-icon>
            <div>
              <div class="text-caption text-medium-emphasis">{{ $t('auditLogs.failedRequests') }}</div>
              <div class="text-body-1 font-weight-bold">{{ kpis.failures?.toLocaleString() || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ─────────────────────────────────────────────────────────────── -->
    <!-- Charts row                                                        -->
    <!-- ─────────────────────────────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <!-- Events per day trend -->
      <v-col cols="12" md="6">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="text-subtitle-2 font-weight-bold">
              <v-icon size="18" class="mr-1" color="primary">mdi-chart-line</v-icon>
              {{ $t('auditLogs.eventsPerDay') }}
            </div>
            <v-select v-model="trendDays" :items="trendOptions"
                      item-title="label" item-value="value"
                      density="compact" hide-details flat variant="solo-filled"
                      style="max-width:140px" @update:model-value="loadTrends" />
          </div>
          <div class="trend-chart">
            <SparkArea :data="trendData.map(d => d.count)" :height="160" />
          </div>
        </v-card>
      </v-col>

      <!-- Action breakdown -->
      <v-col cols="12" md="6">
        <v-card flat rounded="xl" border class="pa-3 h-100">
          <div class="text-subtitle-2 font-weight-bold mb-2">
            <v-icon size="18" class="mr-1" color="indigo">mdi-chart-donut</v-icon>
            {{ $t('auditLogs.actionBreakdown') }}
          </div>
          <div class="d-flex flex-wrap ga-2 justify-center align-center py-2">
            <div v-for="row in actionBreakdown" :key="row.action" class="d-flex align-center">
              <v-chip :color="actionColor(row.action)" variant="tonal" size="small"
                      :style="{ borderColor: actionColor(row.action) }">
                <v-icon start size="14">{{ actionIcon(row.action) }}</v-icon>
                {{ actionLabel(row.action) }}
                <span class="ml-1 font-weight-bold">{{ row.count }}</span>
              </v-chip>
            </div>
            <div v-if="!actionBreakdown.length" class="text-caption text-medium-emphasis pa-3">
              No data
            </div>
          </div>

          <v-divider class="my-3" />
          <div class="text-subtitle-2 font-weight-bold mb-2">
            <v-icon size="18" class="mr-1" color="primary">mdi-account-star</v-icon>
            {{ $t('auditLogs.topActors') }}
          </div>
          <v-list density="compact" class="px-0">
            <v-list-item v-for="actor in topActors" :key="actor.user_id" density="compact"
                         class="px-1">
              <template #prepend>
                <v-avatar size="28" color="indigo-lighten-4" variant="tonal">
                  <span class="text-body-2 font-weight-bold">
                    {{ (actor.email || '?').charAt(0).toUpperCase() }}
                  </span>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2">{{ actor.email }}</v-list-item-title>
              <v-list-item-subtitle class="text-capitalize">
                {{ actor.role }} · {{ actor.count }} events
              </v-list-item-subtitle>
              <template #append>
                <v-progress-circular :model-value="(actor.count / maxActorCount) * 100"
                                     size="32" color="primary" width="3">
                  <span class="text-caption">{{ actor.count }}</span>
                </v-progress-circular>
              </template>
            </v-list-item>
            <v-list-item v-if="!topActors.length" density="compact" class="text-medium-emphasis">
              <v-list-item-title class="text-caption">No actor activity yet</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- ─────────────────────────────────────────────────────────────── -->
    <!-- Filter toolbar                                                    -->
    <!-- ─────────────────────────────────────────────────────────────── -->
    <v-card flat rounded="xl" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          prepend-inner-icon="mdi-magnify"
          :placeholder="$t('auditLogs.search')"
          density="compact" variant="solo-filled" flat hide-details clearable
          style="min-width: 240px; max-width: 320px; flex:1"
          @update:model-value="onFilterChange"
        />
        <v-select
          v-model="filterAction"
          :items="actionItems" item-title="label" item-value="value"
          :label="$t('auditLogs.filterAction')"
          density="compact" variant="outlined" hide-details clearable
          style="min-width: 140px; max-width: 170px;"
          @update:model-value="onFilterChange"
        />
        <v-select
          v-model="filterSeverity"
          :items="severityItems" item-title="label" item-value="value"
          :label="$t('auditLogs.filterSeverity')"
          density="compact" variant="outlined" hide-details clearable
          style="min-width: 140px; max-width: 170px;"
          @update:model-value="onFilterChange"
        />
        <v-select
          v-model="filterObjectType"
          :items="objectTypeItems" item-title="object_type" item-value="object_type"
          :label="$t('auditLogs.filterObjectType')"
          density="compact" variant="outlined" hide-details clearable
          style="min-width: 170px; max-width: 220px;"
          @update:model-value="onFilterChange"
        />
        <v-select
          v-model="filterActor"
          :items="actorItems" item-title="email" item-value="user_id"
          :label="$t('auditLogs.filterActor')"
          density="compact" variant="outlined" hide-details clearable
          style="min-width: 180px; max-width: 240px;"
          @update:model-value="onFilterChange"
        />
        <v-select
          v-model="sinceDays"
          :items="sinceOptions" item-title="label" item-value="value"
          label="Range"
          density="compact" variant="outlined" hide-details
          style="min-width: 130px; max-width: 160px;"
          @update:model-value="onFilterChange"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">
          {{ count.toLocaleString() }} events
        </span>
      </div>
    </v-card>

    <!-- ─────────────────────────────────────────────────────────────── -->
    <!-- Audit events table                                                -->
    <!-- ─────────────────────────────────────────────────────────────── -->
    <v-card flat rounded="xl" border>
      <v-data-table-server
        v-model:items-per-page="itemsPerPage"
        v-model:page="page"
        v-model:sort-by="sortBy"
        :headers="headers"
        :items="events"
        :items-length="count"
        :loading="loading"
        density="comfortable"
        :items-per-page-options="[20, 50, 100, 200]"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template #item.actor="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="actorColor(item.actor_email)" size="32" variant="tonal" class="mr-2">
              <span class="text-caption font-weight-bold">
                {{ (item.actor_email || '?').charAt(0).toUpperCase() }}
              </span>
            </v-avatar>
            <div>
              <div class="text-body-2 font-weight-medium">{{ item.actor_display || item.actor_email }}</div>
              <div class="text-caption text-medium-emphasis text-capitalize">{{ item.actor_role || '—' }}</div>
            </div>
          </div>
        </template>

        <template #item.action="{ item }">
          <v-chip :color="actionColor(item.action)" variant="tonal" size="small">
            <v-icon start size="14">{{ actionIcon(item.action) }}</v-icon>
            {{ actionLabel(item.action) }}
          </v-chip>
        </template>

        <template #item.target="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="objectTypeColor(item.object_type)" variant="tonal" size="28"
                      rounded="lg" class="mr-2">
              <v-icon size="14">{{ objectTypeIcon(item.object_type) }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-body-2">{{ item.object_repr || item.object_type || '—' }}</div>
              <div v-if="item.object_id" class="text-caption text-medium-emphasis">#{{ item.object_id }}</div>
            </div>
          </div>
        </template>

        <template #item.method="{ item }">
          <v-chip :color="methodColor(item.method)" size="x-small" variant="flat">
            {{ item.method }}
          </v-chip>
        </template>

        <template #item.status_code="{ item }">
          <v-chip
            v-if="item.status_code"
            :color="statusColor(item.status_code)"
            size="x-small"
            :variant="item.status_code >= 400 ? 'flat' : 'tonal'"
          >
            {{ item.status_code }}
          </v-chip>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>

        <template #item.severity="{ item }">
          <v-icon :color="severityColor(item.severity)" size="16">
            {{ severityIcon(item.severity) }}
          </v-icon>
        </template>

        <template #item.ip="{ item }">
          <span class="text-body-2 text-medium-emphasis">{{ item.ip || '—' }}</span>
        </template>

        <template #item.location="{ item }">
          <v-tooltip v-if="item.latitude != null && item.longitude != null" location="top">
            <template #activator="{ props }">
              <v-chip size="x-small" variant="tonal" color="teal" v-bind="props" class="font-mono">
                <v-icon start size="12">mdi-map-marker</v-icon>
                {{ Number(item.latitude).toFixed(4) }}, {{ Number(item.longitude).toFixed(4) }}
              </v-chip>
            </template>
            <span class="font-mono">{{ item.latitude }}, {{ item.longitude }}</span>
          </v-tooltip>
          <span v-else class="text-caption text-medium-emphasis">—</span>
        </template>

        <template #item.created_at="{ item }">
          <div class="text-body-2">{{ formatDate(item.created_at) }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatTime(item.created_at) }}</div>
        </template>

        <template #item.actions="{ item }">
          <v-tooltip text="View details">
            <template #activator="{ props }">
              <v-btn icon="mdi-information-outline" variant="text" size="small"
                     v-bind="props" @click.stop="openDetails(item)" />
            </template>
          </v-tooltip>
        </template>

        <template #no-data>
          <EmptyState
            icon="mdi-history-off"
            :title="$t('auditLogs.noEvents')"
            :message="$t('auditLogs.noEventsHint')"
          />
        </template>
      </v-data-table-server>
    </v-card>

    <!-- ─────────────────────────────────────────────────────────────── -->
    <!-- Event details drawer                                              -->
    <!-- ─────────────────────────────────────────────────────────────── -->
    <v-dialog v-model="detailsDialog" max-width="640">
      <v-card rounded="xl" class="pa-1" v-if="detailsItem">
        <v-card-title class="d-flex align-center">
          <v-icon :color="actionColor(detailsItem.action)" class="mr-2">
            {{ actionIcon(detailsItem.action) }}
          </v-icon>
          {{ actionLabel(detailsItem.action) }} — {{ detailsItem.object_repr || detailsItem.object_type }}
        </v-card-title>
        <v-card-text>
          <v-list density="compact" class="pa-0">
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.actor') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">
                {{ detailsItem.actor_display || detailsItem.actor_email }} · {{ detailsItem.actor_role || '—' }}
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.description') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">
                {{ detailsItem.description || '—' }}
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.path') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2 font-mono">{{ detailsItem.method }} {{ detailsItem.path }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.ip') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ detailsItem.ip || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.location') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2 font-mono">
                <template v-if="detailsItem.latitude != null && detailsItem.longitude != null">
                  {{ detailsItem.latitude }}, {{ detailsItem.longitude }}
                </template>
                <template v-else>—</template>
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.status') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">
                <v-chip :color="statusColor(detailsItem.status_code)" size="small" variant="tonal">
                  {{ detailsItem.status_code }}
                </v-chip>
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.userAgent') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">{{ detailsItem.user_agent || '—' }}</v-list-item-subtitle>
            </v-list-item>
            <v-list-item density="compact">
              <v-list-item-title class="text-caption text-medium-emphasis">{{ $t('auditLogs.sessionId') }}</v-list-item-title>
              <v-list-item-subtitle class="text-body-2 font-mono">{{ detailsItem.session_id || '—' }}</v-list-item-subtitle>
            </v-list-item>
          </v-list>

          <div v-if="detailsItem.payload_diff && Object.keys(detailsItem.payload_diff).length" class="mt-3">
            <div class="text-caption text-medium-emphasis mb-1">{{ $t('auditLogs.payloadDiff') }}</div>
            <pre class="json-block">{{ JSON.stringify(detailsItem.payload_diff, null, 2) }}</pre>
          </div>

          <div v-if="detailsItem.extra && Object.keys(detailsItem.extra).length" class="mt-3">
            <div class="text-caption text-medium-emphasis mb-1">{{ $t('auditLogs.extra') }}</div>
            <pre class="json-block">{{ JSON.stringify(detailsItem.extra, null, 2) }}</pre>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="detailsDialog = false">
            {{ $t('common.close') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { t } = useI18n()

// ──────────────────────────────────────────────────────────────────
// State
// ──────────────────────────────────────────────────────────────────
const loading = ref(false)
const events = ref([])
const count = ref(0)
const kpis = ref({})
const trendData = ref([])
const actionBreakdown = ref([])
const topActors = ref([])
const objectTypeOptions = ref([])
const actorOptions = ref([])

const search = ref('')
const filterAction = ref(null)
const filterSeverity = ref(null)
const filterObjectType = ref(null)
const filterActor = ref(null)
const sinceDays = ref(7)

const itemsPerPage = ref(20)
const page = ref(1)
const sortBy = ref([{ key: 'created_at', order: 'desc' }])

const detailsDialog = ref(false)
const detailsItem = ref(null)

const trendDays = ref(30)

// ──────────────────────────────────────────────────────────────────
// Computed / options
// ──────────────────────────────────────────────────────────────────
const trendOptions = computed(() => [
  { label: t('auditLogs.last7Days'), value: 7 },
  { label: t('auditLogs.last30Days'), value: 30 },
  { label: 'Last 90 days', value: 90 },
])

const headers = computed(() => [
  { title: t('auditLogs.actor'), key: 'actor', sortable: false },
  { title: t('auditLogs.action'), key: 'action', sortable: true, width: 130 },
  { title: t('auditLogs.target'), key: 'target', sortable: true, width: 220 },
  { title: t('auditLogs.method'), key: 'method', sortable: true, width: 80, align: 'center' },
  { title: t('auditLogs.status'), key: 'status_code', sortable: true, width: 80, align: 'center' },
  { title: '', key: 'severity', sortable: true, width: 50, align: 'center' },
  { title: t('auditLogs.ip'), key: 'ip', sortable: false, width: 130 },
  { title: t('auditLogs.location'), key: 'location', sortable: false, width: 150 },
  { title: t('auditLogs.time'), key: 'created_at', sortable: true, width: 180 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
])

const actionItems = computed(() => [
  { label: t('auditLogs.action') + ': Create', value: 'create' },
  { label: t('auditLogs.action') + ': Update', value: 'update' },
  { label: t('auditLogs.action') + ': Delete', value: 'delete' },
  { label: t('auditLogs.action') + ': View', value: 'view' },
  { label: t('auditLogs.action') + ': Login', value: 'login' },
  { label: t('auditLogs.action') + ': Logout', value: 'logout' },
  { label: t('auditLogs.action') + ': Export', value: 'export' },
  { label: t('auditLogs.action') + ': Custom', value: 'action' },
])

const severityItems = [
  { label: 'Info', value: 'info' },
  { label: 'Notice', value: 'notice' },
  { label: 'Warning', value: 'warning' },
  { label: 'Critical', value: 'critical' },
]

const sinceOptions = computed(() => [
  { label: t('auditLogs.last24h'), value: 1 },
  { label: t('auditLogs.last7Days'), value: 7 },
  { label: t('auditLogs.last30Days'), value: 30 },
  { label: 'Last 90 days', value: 90 },
  { label: t('auditLogs.allTime'), value: 0 },
])

const actorItems = computed(() => actorOptions.value)
const objectTypeItems = computed(() => objectTypeOptions.value)
const maxActorCount = computed(() =>
  Math.max(1, ...(topActors.value || []).map(a => a.count || 0))
)

// ──────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────
const ACTION_COLORS = {
  create: 'success', update: 'info', delete: 'error',
  view: 'grey', login: 'primary', logout: 'grey',
  export: 'warning', print: 'warning', config: 'purple',
  action: 'indigo',
}
const ACTION_ICONS = {
  create: 'mdi-plus', update: 'mdi-pencil', delete: 'mdi-delete',
  view: 'mdi-eye', login: 'mdi-login', logout: 'mdi-logout',
  export: 'mdi-download', print: 'mdi-printer', config: 'mdi-cog',
  action: 'mdi-flash',
}
function actionColor(a) { return ACTION_COLORS[a] || 'grey' }
function actionIcon(a) { return ACTION_ICONS[a] || 'mdi-circle' }
function actionLabel(a) {
  const map = {
    create: 'Create', update: 'Update', delete: 'Delete', view: 'View',
    login: 'Login', logout: 'Logout', export: 'Export',
    print: 'Print', config: 'Config', action: 'Action',
  }
  return map[a] || a || '—'
}

const SEVERITY_COLORS = { info: 'info', notice: 'primary', warning: 'warning', critical: 'error' }
const SEVERITY_ICONS = {
  info: 'mdi-information-outline', notice: 'mdi-bell-outline',
  warning: 'mdi-alert', critical: 'mdi-alert-circle',
}
function severityColor(s) { return SEVERITY_COLORS[s] || 'grey' }
function severityIcon(s) { return SEVERITY_ICONS[s] || 'mdi-circle' }

const METHOD_COLORS = {
  GET: 'info', POST: 'success', PUT: 'warning', PATCH: 'warning', DELETE: 'error',
}
function methodColor(m) { return METHOD_COLORS[m] || 'grey' }

function statusColor(s) {
  if (!s) return 'grey'
  if (s >= 500) return 'error'
  if (s >= 400) return 'warning'
  if (s >= 300) return 'info'
  return 'success'
}

const OBJECT_TYPE_COLORS = {
  patients: 'primary', pos: 'success', prescriptions: 'indigo',
  dispensing: 'teal', inventory: 'amber', accounts: 'red',
  auth: 'deep-purple', purchase_orders: 'orange', suppliers: 'cyan',
  pharmacy_profile: 'blue', settings: 'grey', reports: 'pink',
  insurance: 'green', audit: 'brown', staff_profiles: 'purple',
}
function objectTypeColor(t) {
  if (!t) return 'grey'
  return OBJECT_TYPE_COLORS[t] || 'indigo'
}
function objectTypeIcon(t) {
  if (!t) return 'mdi-circle-outline'
  const map = {
    patients: 'mdi-account', pos: 'mdi-cart', prescriptions: 'mdi-pill',
    dispensing: 'mdi-clipboard-check', inventory: 'mdi-package-variant',
    accounts: 'mdi-account-cog', auth: 'mdi-shield-account',
    purchase_orders: 'mdi-cart', suppliers: 'mdi-truck',
    pharmacy_profile: 'mdi-store', settings: 'mdi-cog',
    reports: 'mdi-chart-box', insurance: 'mdi-shield',
    audit: 'mdi-history', staff_profiles: 'mdi-badge-account',
  }
  return map[t] || 'mdi-folder'
}

function actorColor(email) {
  if (!email) return 'grey'
  return ['primary','success','warning','info','purple','teal','pink','indigo'][email.charCodeAt(0) % 8]
}

function formatDate(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return d.toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function formatTime(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

// ──────────────────────────────────────────────────────────────────
// Filter handling
// ──────────────────────────────────────────────────────────────────
let debounce = null
function onFilterChange() {
  page.value = 1
  clearTimeout(debounce)
  debounce = setTimeout(() => loadEvents(), 250)
}

function buildParams() {
  const params = {
    page: page.value,
    page_size: itemsPerPage.value,
  }
  const sort = sortBy.value[0]
  if (sort) params.ordering = (sort.order === 'desc' ? '-' : '') + sort.key
  if (search.value) params.search = search.value
  if (filterAction.value) params.action = filterAction.value
  if (filterSeverity.value) params.severity = filterSeverity.value
  if (filterObjectType.value) params.object_type = filterObjectType.value
  if (filterActor.value) params.actor_user_id = filterActor.value
  if (sinceDays.value && sinceDays.value > 0) params.since_days = sinceDays.value
  return params
}

// ──────────────────────────────────────────────────────────────────
// API calls
// ──────────────────────────────────────────────────────────────────
async function loadEvents() {
  loading.value = true
  try {
    const { data } = await $api.get('/audit/events/', { params: buildParams() })
    events.value = data?.results || []
    count.value = data?.count || 0
  } catch {
    events.value = []
    count.value = 0
  } finally {
    loading.value = false
  }
}

async function loadKpis() {
  try {
    const params = sinceDays.value > 0 ? { since_days: sinceDays.value } : {}
    const { data } = await $api.get('/audit/events/kpis/', { params })
    kpis.value = data
  } catch { kpis.value = {} }
}

async function loadTrends() {
  try {
    const { data } = await $api.get('/audit/events/trends/', {
      params: { days: trendDays.value }
    })
    trendData.value = data || []
  } catch { trendData.value = [] }
}

async function loadActionBreakdown() {
  try {
    const { data } = await $api.get('/audit/events/action-breakdown/')
    actionBreakdown.value = data || []
  } catch { actionBreakdown.value = [] }
}

async function loadTopActors() {
  try {
    const { data } = await $api.get('/audit/events/top-actors/', { params: { limit: 5 } })
    topActors.value = data || []
  } catch { topActors.value = [] }
}

async function loadFilterOptions() {
  try {
    const [types, actors] = await Promise.all([
      $api.get('/audit/events/object-types/'),
      $api.get('/audit/events/top-actors/', { params: { limit: 100 } }),
    ])
    objectTypeOptions.value = types.data || []
    actorOptions.value = actors.data || []
  } catch {
    objectTypeOptions.value = []
    actorOptions.value = []
  }
}

async function exportData(format) {
  try {
    const params = { format, limit: 10000 }
    if (search.value) params.search = search.value
    if (filterAction.value) params.action = filterAction.value
    if (filterSeverity.value) params.severity = filterSeverity.value
    if (filterObjectType.value) params.object_type = filterObjectType.value
    if (filterActor.value) params.actor_user_id = filterActor.value
    if (sinceDays.value && sinceDays.value > 0) params.since_days = sinceDays.value

    const res = await $api.get('/audit/events/export/', {
      params, responseType: format === 'csv' ? 'blob' : 'json',
    })
    let blob
    let filename
    if (format === 'csv') {
      blob = new Blob([res.data], { type: 'text/csv' })
      filename = `audit-logs-${new Date().toISOString().slice(0,10)}.csv`
    } else {
      blob = new Blob([JSON.stringify(res.data, null, 2)], { type: 'application/json' })
      filename = `audit-logs-${new Date().toISOString().slice(0,10)}.json`
    }
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    a.click()
    URL.revokeObjectURL(url)
  } catch (e) {
    console.error('export failed', e)
  }
}

// ──────────────────────────────────────────────────────────────────
// Detail dialog
// ──────────────────────────────────────────────────────────────────
function openDetails(item) {
  detailsItem.value = item
  detailsDialog.value = true
}

// ──────────────────────────────────────────────────────────────────
// Reload aggregations whenever filters change
// ──────────────────────────────────────────────────────────────────
function reloadAll() {
  loadEvents()
  loadKpis()
  loadTrends()
  loadActionBreakdown()
  loadTopActors()
  loadFilterOptions()
}

// Watch page / pageSize / sort changes (server-side data table).
watch([page, itemsPerPage, sortBy], () => loadEvents())

onMounted(reloadAll)
</script>

<style scoped>
.kpi-card {
  background: white;
}
.json-block {
  background: rgba(0,0,0,0.04);
  border-radius: 8px;
  padding: 8px 10px;
  font-family: 'Cascadia Code', 'Fira Code', monospace;
  font-size: 12px;
  overflow-x: auto;
  max-height: 220px;
}
.font-mono {
  font-family: 'Cascadia Code', 'Fira Code', monospace;
  font-size: 12px;
}
.trend-chart {
  min-height: 160px;
}
</style>
