<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-test-tube</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Worklist</div>
        <div class="text-body-2 text-medium-emphasis">
          Active orders ready for processing and result entry
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="orders.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             @click="$router.push('/lab/requisitions/new')">New requisition</v-btn>
    </div>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3" lg="2">
        <v-card flat rounded="lg" class="kpi pa-3"
                :class="{ 'is-active': activeKpi === k.key }"
                @click="setKpi(k)">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Status tabs with counts -->
    <v-card flat rounded="lg" class="mt-4">
      <v-tabs v-model="tab" color="primary" align-tabs="start" show-arrows>
        <v-tab v-for="t in tabs" :key="t.value" :value="t.value">
          <v-icon size="18" start>{{ t.icon }}</v-icon>
          {{ t.label }}
          <v-chip size="x-small" class="ml-2" variant="tonal" :color="t.color">
            {{ statusCount(t.value) }}
          </v-chip>
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search patient, test, REQ #…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="priorityFilter" :items="priorityOptions"
                    label="Priority" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dateFilter" :items="dateOptions"
                    label="Date" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="collectionFilter" :items="collectionOptions"
                    label="Source" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2" class="d-flex justify-end ga-2">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="cards" icon="mdi-view-grid-outline" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>

      <!-- Quick priority pills -->
      <div class="d-flex flex-wrap ga-2 mt-3">
        <v-chip
          v-for="p in priorityPills" :key="p.value || 'all'"
          :color="priorityFilter === p.value ? p.color : undefined"
          :variant="priorityFilter === p.value ? 'flat' : 'tonal'"
          size="small" class="text-capitalize"
          @click="priorityFilter = p.value"
        >
          <v-icon v-if="p.icon" size="14" start>{{ p.icon }}</v-icon>
          {{ p.label }}
          <span class="ml-2 font-weight-bold">{{ p.count }}</span>
        </v-chip>
      </div>
    </v-card>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="orders.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        class="wl-table"
        @click:row="(_, { item }) => openOrder(item)"
      >
        <template #item.id="{ value, item }">
          <div class="d-flex flex-column">
            <span class="font-monospace font-weight-bold text-caption">REQ-{{ String(value).padStart(5, '0') }}</span>
            <span v-if="item.is_home_collection" class="text-caption text-medium-emphasis">
              <v-icon size="12">mdi-home-outline</v-icon> Home
            </span>
          </div>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="hashColor(item.patient || item.id)" size="32" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.patient_name || 'Unknown' }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.ordered_by_name || '—' }}</div>
            </div>
          </div>
        </template>
        <template #item.test_names="{ value }">
          <div class="d-flex flex-wrap ga-1" style="max-width: 320px">
            <v-chip v-for="(t, i) in (value || []).slice(0, 3)" :key="i"
                    size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
            <v-chip v-if="(value || []).length > 3" size="x-small" variant="tonal">
              +{{ value.length - 3 }} more
            </v-chip>
            <span v-if="!value || !value.length" class="text-medium-emphasis text-caption">—</span>
          </div>
        </template>
        <template #item.priority="{ value }">
          <v-chip size="x-small" variant="flat" :color="priorityColor(value)" class="text-uppercase text-white">
            <v-icon size="12" start>{{ priorityIcon(value) }}</v-icon>{{ value }}
          </v-chip>
        </template>
        <template #item.status="{ item, value }">
          <v-chip v-if="awaitingVerification(item)" size="x-small" variant="tonal" color="deep-purple-darken-2">
            <v-icon size="12" start>mdi-shield-check-outline</v-icon>To verify
          </v-chip>
          <v-chip v-else size="x-small" variant="tonal" :color="statusColor(value)" class="text-capitalize">
            <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>{{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.progress="{ item }">
          <div class="d-flex align-center ga-2" style="min-width: 130px">
            <v-progress-linear
              :model-value="resultProgress(item)"
              :color="resultProgress(item) === 100 ? 'success' : 'primary'"
              height="6" rounded
              style="width: 80px"
            />
            <span class="text-caption">{{ (item.results || []).length }}/{{ (item.test_names || []).length }}</span>
          </div>
        </template>
        <template #item.created_at="{ value }">
          <div class="d-flex flex-column">
            <span class="text-caption">{{ formatDateTime(value) }}</span>
            <span class="text-caption text-medium-emphasis">{{ relativeTime(value) }}</span>
          </div>
        </template>
        <template #item.tat="{ item }">
          <v-chip size="x-small" variant="tonal" :color="tatColor(item)">
            <v-icon size="12" start>mdi-timer-outline</v-icon>{{ tatLabel(item) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Open requisition" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye-outline" variant="text" size="small"
                       @click="openOrder(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Enter results" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-clipboard-edit-outline" variant="text" size="small"
                       color="primary" @click="enterResults(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item v-if="item.status === 'pending'"
                             prepend-icon="mdi-tray-arrow-down" title="Mark sample collected"
                             @click="setStatus(item, 'sample_collected')" />
                <v-list-item v-if="['pending','sample_collected'].includes(item.status)"
                             prepend-icon="mdi-cog-outline" title="Start processing"
                             @click="setStatus(item, 'processing')" />
                <v-list-item v-if="awaitingVerification(item)"
                             prepend-icon="mdi-shield-check-outline" title="Verify & release"
                             base-color="deep-purple-darken-2" @click="verifyAndRelease(item)" />
                <v-list-item v-if="item.status === 'processing'"
                             prepend-icon="mdi-check" title="Mark completed"
                             base-color="success" @click="setStatus(item, 'completed')" />
                <v-list-item prepend-icon="mdi-barcode-scan" title="Register specimen"
                             @click="$router.push(`/lab/accessioning?order=${item.id}`)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print worksheet"
                             @click="printWorksheet(item)" />
                <v-divider />
                <v-list-item v-if="item.status !== 'cancelled'"
                             prepend-icon="mdi-close-circle-outline" title="Cancel order"
                             base-color="error" @click="setStatus(item, 'cancelled')" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No orders in this view</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Try changing the filters above.</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Cards view -->
    <div v-else class="mt-3">
      <div v-if="orders.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No orders in this view</div>
      </div>
      <v-row v-else dense>
        <v-col v-for="o in filtered" :key="o.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="ord-card pa-3 h-100" hover @click="openOrder(o)">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="hashColor(o.patient || o.id)" size="36" class="mr-2">
                <span class="text-white text-caption font-weight-bold">{{ initials(o.patient_name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-body-2 text-truncate">{{ o.patient_name || 'Unknown' }}</div>
                <div class="text-caption text-medium-emphasis font-monospace">REQ-{{ String(o.id).padStart(5, '0') }}</div>
              </div>
              <v-chip size="x-small" variant="flat" :color="priorityColor(o.priority)" class="text-uppercase text-white">
                {{ o.priority }}
              </v-chip>
            </div>
            <v-divider class="my-2" />
            <div class="d-flex flex-wrap ga-1 mb-2">
              <v-chip v-for="(t, i) in (o.test_names || []).slice(0, 4)" :key="i"
                      size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
              <v-chip v-if="(o.test_names || []).length > 4" size="x-small" variant="tonal">
                +{{ o.test_names.length - 4 }}
              </v-chip>
            </div>
            <div class="d-flex align-center ga-2 mb-2">
              <v-progress-linear :model-value="resultProgress(o)"
                                 :color="resultProgress(o) === 100 ? 'success' : 'primary'"
                                 height="6" rounded />
              <span class="text-caption">{{ (o.results || []).length }}/{{ (o.test_names || []).length }}</span>
            </div>
            <div class="d-flex align-center justify-space-between">
              <v-chip size="x-small" variant="tonal" :color="statusColor(o.status)" class="text-capitalize">
                <v-icon size="12" start>{{ statusIcon(o.status) }}</v-icon>{{ statusLabel(o.status) }}
              </v-chip>
              <span class="text-caption text-medium-emphasis">{{ relativeTime(o.created_at) }}</span>
            </div>
            <v-divider class="my-2" />
            <div class="d-flex ga-1 justify-end" @click.stop>
              <v-btn size="x-small" variant="text" icon="mdi-printer-outline"
                     @click="printWorksheet(o)" />
              <v-btn size="x-small" variant="tonal" color="primary"
                     prepend-icon="mdi-clipboard-edit-outline"
                     @click="enterResults(o)">Results</v-btn>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Order details drawer -->
    <v-navigation-drawer v-model="detailsDrawer" location="right" temporary
                         width="520" class="pa-0">
      <div v-if="selectedOrder" class="pa-4">
        <div class="d-flex align-center mb-3">
          <v-avatar :color="hashColor(selectedOrder.patient || selectedOrder.id)" size="40" class="mr-3">
            <span class="text-white font-weight-bold">{{ initials(selectedOrder.patient_name) }}</span>
          </v-avatar>
          <div class="flex-grow-1">
            <div class="text-h6 font-weight-bold">{{ selectedOrder.patient_name }}</div>
            <div class="text-caption text-medium-emphasis font-monospace">
              REQ-{{ String(selectedOrder.id).padStart(5, '0') }}
            </div>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" @click="detailsDrawer = false" />
        </div>

        <div class="d-flex flex-wrap ga-2 mb-3">
          <v-chip size="small" variant="flat" :color="priorityColor(selectedOrder.priority)" class="text-uppercase text-white">
            {{ selectedOrder.priority }}
          </v-chip>
          <v-chip size="small" variant="tonal" :color="statusColor(selectedOrder.status)" class="text-capitalize">
            <v-icon size="14" start>{{ statusIcon(selectedOrder.status) }}</v-icon>{{ statusLabel(selectedOrder.status) }}
          </v-chip>
          <v-chip v-if="selectedOrder.is_home_collection" size="small" variant="tonal" color="purple">
            <v-icon size="14" start>mdi-home-outline</v-icon>Home collection
          </v-chip>
        </div>

        <v-card flat rounded="lg" class="pa-3 mb-3 detail-card">
          <div class="d-flex justify-space-between text-caption">
            <span class="text-medium-emphasis">Ordered by</span>
            <span class="font-weight-medium">{{ selectedOrder.ordered_by_name || '—' }}</span>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between text-caption">
            <span class="text-medium-emphasis">Ordered at</span>
            <span class="font-weight-medium">{{ formatDateTime(selectedOrder.created_at) }}</span>
          </div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between text-caption">
            <span class="text-medium-emphasis">Last update</span>
            <span class="font-weight-medium">{{ formatDateTime(selectedOrder.updated_at) }}</span>
          </div>
        </v-card>

        <div class="text-overline text-medium-emphasis mb-1">Tests ({{ (selectedOrder.test_names || []).length }})</div>
        <v-list density="compact" class="pa-0 mb-3" rounded="lg" border>
          <v-list-item v-for="(t, i) in (selectedOrder.test_names || [])" :key="i" :title="t">
            <template #prepend>
              <v-icon size="20" color="indigo">mdi-flask-outline</v-icon>
            </template>
            <template #append>
              <v-chip v-if="resultForTest(selectedOrder, t)" size="x-small" color="success" variant="tonal">
                <v-icon size="12" start>mdi-check</v-icon>Done
              </v-chip>
              <v-chip v-else size="x-small" variant="tonal">Pending</v-chip>
            </template>
          </v-list-item>
        </v-list>

        <div v-if="selectedOrder.clinical_notes" class="mb-3">
          <div class="text-overline text-medium-emphasis mb-1">Clinical notes</div>
          <v-card flat rounded="lg" class="pa-3 detail-card">
            <div class="text-body-2">{{ selectedOrder.clinical_notes }}</div>
          </v-card>
        </div>

        <div v-if="(selectedOrder.results || []).length" class="mb-3">
          <div class="text-overline text-medium-emphasis mb-1">Results</div>
          <v-card flat rounded="lg" class="pa-3 detail-card">
            <div v-for="res in selectedOrder.results" :key="res.id" class="result-row">
              <div class="d-flex justify-space-between align-center">
                <span class="font-weight-medium">{{ res.test_name }}</span>
                <span :class="res.is_abnormal ? 'text-error font-weight-bold' : 'font-weight-medium'">
                  {{ res.result_value }} {{ res.unit }}
                  <v-icon v-if="res.is_abnormal" size="14" color="error">mdi-alert</v-icon>
                </span>
              </div>
              <div v-if="res.comments" class="text-caption text-medium-emphasis">{{ res.comments }}</div>
            </div>
          </v-card>
        </div>

        <div class="d-flex flex-wrap ga-2 mt-3">
          <v-btn v-if="awaitingVerification(selectedOrder)"
                 color="deep-purple-darken-2" rounded="lg" prepend-icon="mdi-shield-check-outline"
                 @click="verifyAndRelease(selectedOrder)">Verify &amp; release</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-clipboard-edit-outline"
                 @click="enterResults(selectedOrder)">Enter results</v-btn>
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-barcode-scan"
                 @click="$router.push(`/lab/accessioning?order=${selectedOrder.id}`)">Specimen</v-btn>
          <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-printer-outline"
                 @click="printWorksheet(selectedOrder)">Worksheet</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const router = useRouter()
const orders = useResource('/lab/orders/')

const tab = ref(route.query.status || 'pending')
const view = ref('table')
const search = ref('')
const priorityFilter = ref(null)
const dateFilter = ref(null)
const collectionFilter = ref(null)
const activeKpi = ref(null)
const detailsDrawer = ref(false)
const selectedOrder = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  pending: { label: 'Pending', color: 'amber-darken-2', icon: 'mdi-clock-outline' },
  sample_collected: { label: 'Collected', color: 'cyan-darken-2', icon: 'mdi-tray-arrow-down' },
  processing: { label: 'Processing', color: 'blue-darken-2', icon: 'mdi-cog-outline' },
  verify: { label: 'To verify', color: 'deep-purple-darken-2', icon: 'mdi-shield-check-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check' },
  cancelled: { label: 'Cancelled', color: 'grey-darken-1', icon: 'mdi-close-circle-outline' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1', icon: 'mdi-circle-small' },
  urgent: { color: 'orange-darken-2', icon: 'mdi-alert-outline' },
  stat: { color: 'red-darken-2', icon: 'mdi-flash' },
}

const tabs = [
  { value: 'pending', label: 'Pending', icon: 'mdi-clock-outline', color: 'amber-darken-2' },
  { value: 'sample_collected', label: 'Collected', icon: 'mdi-tray-arrow-down', color: 'cyan-darken-2' },
  { value: 'processing', label: 'Processing', icon: 'mdi-cog-outline', color: 'blue-darken-2' },
  { value: 'verify', label: 'To verify', icon: 'mdi-shield-check-outline', color: 'deep-purple-darken-2' },
  { value: 'completed', label: 'Completed', icon: 'mdi-check', color: 'green-darken-2' },
  { value: 'cancelled', label: 'Cancelled', icon: 'mdi-close-circle-outline', color: 'grey-darken-1' },
  { value: 'all', label: 'All', icon: 'mdi-format-list-bulleted', color: 'primary' },
]
const priorityOptions = Object.keys(PRIORITY_META).map(v => ({ title: v.toUpperCase(), value: v }))
const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: 'week' },
  { title: 'Last 30 days', value: 'month' },
]
const collectionOptions = [
  { title: 'In-clinic', value: 'clinic' },
  { title: 'Home collection', value: 'home' },
]

const headers = [
  { title: 'REQ #', key: 'id', width: 110 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Tests', key: 'test_names', sortable: false },
  { title: 'Priority', key: 'priority', width: 100 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Progress', key: 'progress', sortable: false, width: 150 },
  { title: 'Ordered', key: 'created_at', width: 170 },
  { title: 'TAT', key: 'tat', sortable: false, width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }
function priorityIcon(v) { return PRIORITY_META[v]?.icon || 'mdi-circle-small' }

const list = computed(() => orders.items.value || [])

function awaitingVerification(o) {
  if (['cancelled', 'completed'].includes(o.status)) return false
  const total = (o.test_names || []).length
  const results = o.results || []
  if (!total || !results.length) return false
  // All tests have results entered, but at least one is unverified
  if (results.length < total) return false
  return results.some(r => !r.verified_by)
}

function statusCount(value) {
  if (value === 'all') return list.value.length
  if (value === 'verify') return list.value.filter(awaitingVerification).length
  return list.value.filter(o => o.status === value).length
}

const filtered = computed(() => {
  let arr = list.value
  if (tab.value === 'verify') arr = arr.filter(awaitingVerification)
  else if (tab.value !== 'all') arr = arr.filter(o => o.status === tab.value)
  if (priorityFilter.value) arr = arr.filter(o => o.priority === priorityFilter.value)
  if (collectionFilter.value === 'home') arr = arr.filter(o => o.is_home_collection)
  else if (collectionFilter.value === 'clinic') arr = arr.filter(o => !o.is_home_collection)
  if (dateFilter.value) {
    const lim = dateFilter.value === 'today' ? 86400000
      : dateFilter.value === 'week' ? 7 * 86400000 : 30 * 86400000
    const now = Date.now()
    arr = arr.filter(o => o.created_at && (now - new Date(o.created_at).getTime()) <= lim)
  }
  if (activeKpi.value === 'stat') arr = arr.filter(o => o.priority === 'stat')
  if (activeKpi.value === 'overdue') arr = arr.filter(isOverdue)
  if (activeKpi.value === 'home') arr = arr.filter(o => o.is_home_collection)
  if (search.value) {
    const q = search.value.toLowerCase()
    arr = arr.filter(o =>
      (o.patient_name || '').toLowerCase().includes(q)
      || (o.test_names || []).some(t => t.toLowerCase().includes(q))
      || `req-${String(o.id).padStart(5, '0')}`.includes(q)
      || String(o.id) === q
    )
  }
  return arr
})

const priorityPills = computed(() => {
  const counts = list.value.reduce((acc, o) => {
    acc[o.priority] = (acc[o.priority] || 0) + 1
    return acc
  }, {})
  return [
    { label: 'All priorities', value: null, count: list.value.length, color: 'primary' },
    ...Object.entries(PRIORITY_META).map(([v, m]) => ({
      label: v, value: v, count: counts[v] || 0, color: m.color, icon: m.icon,
    })),
  ]
})

const kpis = computed(() => {
  const arr = list.value
  const today = new Date().toDateString()
  return [
    { key: null, label: 'Active', value: arr.filter(o => !['completed', 'cancelled'].includes(o.status)).length,
      icon: 'mdi-flask-outline', color: 'teal' },
    { key: 'today', label: 'Ordered today', value: arr.filter(o => o.created_at && new Date(o.created_at).toDateString() === today).length,
      icon: 'mdi-calendar-today', color: 'indigo' },
    { key: 'stat', label: 'STAT', value: arr.filter(o => o.priority === 'stat' && o.status !== 'completed').length,
      icon: 'mdi-flash', color: 'red' },
    { key: 'overdue', label: 'Overdue', value: arr.filter(isOverdue).length,
      icon: 'mdi-alert-outline', color: 'orange' },
    { key: 'home', label: 'Home collection', value: arr.filter(o => o.is_home_collection).length,
      icon: 'mdi-home-outline', color: 'purple' },
    { key: 'completed', label: 'Completed today', value: arr.filter(o => o.status === 'completed' && o.updated_at && new Date(o.updated_at).toDateString() === today).length,
      icon: 'mdi-check-circle', color: 'green' },
  ]
})

function setKpi(k) {
  if (activeKpi.value === k.key) {
    activeKpi.value = null
    return
  }
  activeKpi.value = k.key
  if (k.key === 'completed') tab.value = 'completed'
  else if (k.key === null) tab.value = 'pending'
}

function resetFilters() {
  search.value = ''
  priorityFilter.value = null
  dateFilter.value = null
  collectionFilter.value = null
  activeKpi.value = null
}

function resultProgress(o) {
  const total = (o.test_names || []).length
  const done = (o.results || []).length
  if (!total) return 0
  return Math.min(100, Math.round((done / total) * 100))
}
function resultForTest(o, name) {
  return (o.results || []).find(r => r.test_name === name)
}

function isOverdue(o) {
  if (['completed', 'cancelled'].includes(o.status)) return false
  if (!o.created_at) return false
  const ageHours = (Date.now() - new Date(o.created_at).getTime()) / 3600000
  if (o.priority === 'stat') return ageHours > 1
  if (o.priority === 'urgent') return ageHours > 4
  return ageHours > 24
}
function tatLabel(o) {
  if (['completed', 'cancelled'].includes(o.status)) return statusLabel(o.status)
  if (!o.created_at) return '—'
  const ageMs = Date.now() - new Date(o.created_at).getTime()
  const h = Math.floor(ageMs / 3600000)
  if (h < 1) return `${Math.floor(ageMs / 60000)}m`
  if (h < 24) return `${h}h`
  return `${Math.floor(h / 24)}d`
}
function tatColor(o) {
  if (o.status === 'completed') return 'success'
  if (o.status === 'cancelled') return 'grey'
  if (isOverdue(o)) return 'error'
  return 'grey-darken-1'
}

function openOrder(item) {
  selectedOrder.value = item
  detailsDrawer.value = true
}
function enterResults(item) {
  router.push(`/lab/results?order=${item.id}`)
}

async function setStatus(item, status) {
  try {
    await orders.update(item.id, { ...item, status, test_ids: item.tests || [] })
    snack.text = `Order ${statusLabel(status).toLowerCase()}`
    snack.color = 'success'
    snack.show = true
    orders.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to update status'
    snack.color = 'error'
    snack.show = true
  }
}

function reload() { orders.list() }

async function verifyAndRelease(item) {
  try {
    // Mark all unverified results as verified, then complete the order
    const unverified = (item.results || []).filter(r => !r.verified_by)
    for (const res of unverified) {
      await $api.patch(`/lab/results/${res.id}/`, { ...res, verified_by: 'self' }).catch(() => {})
    }
    await orders.update(item.id, { ...item, status: 'completed', test_ids: item.tests || [] })
    snack.text = `REQ-${String(item.id).padStart(5, '0')} verified and released`
    snack.color = 'success'
    snack.show = true
    detailsDrawer.value = false
    orders.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to verify'
    snack.color = 'error'
    snack.show = true
  }
}

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}
function relativeTime(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.floor(h / 24)
  if (d < 30) return `${d}d ago`
  return new Date(iso).toLocaleDateString()
}

function printWorksheet(o) {
  const w = window.open('', '_blank', 'width=820,height=900')
  if (!w) return
  const tests = (o.test_names || []).map(t => `
    <tr>
      <td style="padding:8px;border:1px solid #ccc">${t}</td>
      <td style="padding:8px;border:1px solid #ccc;width:30%"></td>
      <td style="padding:8px;border:1px solid #ccc;width:15%"></td>
      <td style="padding:8px;border:1px solid #ccc;width:15%"></td>
    </tr>`).join('')
  w.document.write(`
    <html><head><title>Worksheet REQ-${String(o.id).padStart(5, '0')}</title>
    <style>
      body{font-family:Arial,sans-serif;margin:24px;color:#222}
      h1{margin:0;font-size:20px}
      .sub{color:#666;font-size:12px;margin-bottom:16px}
      table{width:100%;border-collapse:collapse;margin-top:8px}
      th{padding:8px;background:#f5f5f5;border:1px solid #ccc;text-align:left;font-size:12px}
      .meta{display:flex;justify-content:space-between;margin:12px 0;font-size:13px}
      .box{border:1px solid #ccc;padding:8px;border-radius:6px}
      .sig{margin-top:24px;display:flex;justify-content:space-between;font-size:12px;color:#444}
    </style></head><body>
      <h1>Lab Worksheet</h1>
      <div class="sub">REQ-${String(o.id).padStart(5, '0')} · ${o.priority?.toUpperCase()}</div>
      <div class="meta">
        <div class="box"><b>Patient:</b> ${o.patient_name || '—'}</div>
        <div class="box"><b>Ordered by:</b> ${o.ordered_by_name || '—'}</div>
        <div class="box"><b>Date:</b> ${new Date(o.created_at).toLocaleString()}</div>
      </div>
      ${o.clinical_notes ? `<div class="box"><b>Clinical notes:</b> ${o.clinical_notes}</div>` : ''}
      <table>
        <thead><tr><th>Test</th><th>Result</th><th>Unit</th><th>Flag</th></tr></thead>
        <tbody>${tests}</tbody>
      </table>
      <div class="sig">
        <div>Performed by: ____________________</div>
        <div>Verified by: ____________________</div>
        <div>Date: __________</div>
      </div>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 200)
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['req', 'patient', 'tests', 'priority', 'status', 'progress', 'ordered_at', 'home_collection']
  const header = cols.join(',')
  const body = rows.map(o => [
    `REQ-${String(o.id).padStart(5, '0')}`,
    `"${(o.patient_name || '').replace(/"/g, '""')}"`,
    `"${(o.test_names || []).join('; ').replace(/"/g, '""')}"`,
    o.priority || '',
    o.status || '',
    `${(o.results || []).length}/${(o.test_names || []).length}`,
    o.created_at || '',
    o.is_home_collection ? 'yes' : 'no',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `worklist_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

const VALID_TABS = tabs.map(t => t.value)
function syncTabFromRoute() {
  const q = route.query.status
  if (q && VALID_TABS.includes(q)) tab.value = q
}
watch(() => route.query.status, syncTabFromRoute)
watch(tab, (v) => {
  if ((route.query.status || 'pending') !== v) {
    router.replace({ query: { ...route.query, status: v } })
  }
})

onMounted(() => {
  orders.list()
  syncTabFromRoute()
})
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: all 120ms ease;
}
.kpi:hover { border-color: rgba(var(--v-theme-primary), 0.4); }
.kpi.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.05);
}
.ord-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.ord-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
}
.wl-table :deep(tbody tr) { cursor: pointer; }
.detail-card {
  background: rgba(var(--v-theme-on-surface), 0.02);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.result-row {
  padding: 6px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.result-row:last-child { border-bottom: none; }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
