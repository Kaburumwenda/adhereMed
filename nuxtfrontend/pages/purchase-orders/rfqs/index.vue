<template>
  <v-container fluid class="pa-3 pa-md-5 rfq-page">

    <!-- ═══════════════ HERO ═══════════════ -->
    <div class="rfq-hero mb-4" :style="heroTheme">
      <span class="rfq-glow" />
      <span class="rfq-glow rfq-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3 rfq-hero-top">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="rfq-hero-icon">
            <v-icon size="30">mdi-file-document-multiple-outline</v-icon>
          </div>
          <div style="min-width:0">
            <div class="rfq-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              PROCUREMENT · SOURCING
            </div>
            <h1 class="rfq-title">Requests for Quotation</h1>
            <div class="rfq-sub">
              Invite suppliers, compare bids and award with confidence
              <span v-if="activeBranchLabel"> · {{ activeBranchLabel }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="rfq-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none rfq-btn-glass"
            prepend-icon="mdi-download"
            :disabled="!filteredRows.length"
            @click="exportCsv"
          >Export</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none rfq-btn-strong"
            prepend-icon="mdi-plus"
            :to="newRfqPath"
          >New RFQ</v-btn>
        </div>
      </div>

      <div class="rfq-hero-foot d-flex flex-wrap align-center" style="gap:8px">
        <span class="rfq-hero-chip"><v-icon size="14">mdi-file-document-multiple-outline</v-icon>{{ stats.total }} request{{ stats.total === 1 ? '' : 's' }}</span>
        <span class="rfq-hero-chip"><v-icon size="14">mdi-progress-clock</v-icon>{{ stats.open }} open</span>
        <span class="rfq-hero-chip"><v-icon size="14">mdi-calendar-clock</v-icon>{{ stats.dueSoon }} due this week</span>
        <span v-if="stats.overdue" class="rfq-hero-chip rfq-hero-chip-alert"><v-icon size="14">mdi-calendar-alert</v-icon>{{ stats.overdue }} overdue</span>
      </div>
    </div>

    <!-- ═══════════════ KPI STRIP ═══════════════ -->
    <v-row dense class="mb-2">
      <v-col v-for="k in kpiTiles" :key="k.title" cols="12" sm="6" md="4" lg="2">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- ═══════════════ TOOLBAR ═══════════════ -->
    <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
      <div class="pa-3 d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          placeholder="Search RFQ #, title, supplier…"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          style="min-width:240px; max-width:420px; flex:1"
        />
        <v-select
          v-model="branchFilter"
          :items="branchOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-store-marker"
          style="min-width:170px; max-width:220px"
        />
        <v-select
          v-model="deadlineFilter"
          :items="deadlineOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-filter"
          style="min-width:160px; max-width:210px"
        />
        <v-spacer />
        <v-btn-toggle v-model="viewMode" density="compact" variant="outlined" rounded="lg" mandatory divided>
          <v-btn value="table" size="small" icon="mdi-table-large" title="Table view" />
          <v-btn value="grid" size="small" icon="mdi-view-grid-outline" title="Card view" />
        </v-btn-toggle>
      </div>

      <v-divider />

      <div class="px-3 py-2 d-flex flex-wrap align-center" style="gap:10px">
        <v-chip-group
          :model-value="statusFilter"
          mandatory
          class="rfq-chipgroup"
          @update:model-value="(v) => (statusFilter = v || 'all')"
        >
          <v-chip
            v-for="s in statusOptions"
            :key="s.value"
            :value="s.value"
            size="small"
            :color="s.color"
            :variant="statusFilter === s.value ? 'flat' : 'tonal'"
            class="text-none"
          >
            {{ s.label }}
            <span class="rfq-chip-count">{{ statusCount(s.value) }}</span>
          </v-chip>
        </v-chip-group>

        <v-spacer />

        <v-select
          v-model="sortKey"
          :items="sortOptions"
          item-title="label"
          item-value="value"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-sort"
          style="min-width:180px; max-width:210px"
        />
        <span class="text-caption text-medium-emphasis">{{ filteredRows.length }} of {{ stats.total }}</span>
      </div>
    </v-card>

    <!-- ═══════════════ RESULTS ═══════════════ -->
    <v-card rounded="lg" elevation="0" class="rfq-card overflow-hidden">
      <v-progress-linear v-if="loading && items.length" color="primary" indeterminate />

      <!-- Loading skeleton -->
      <div v-if="loading && !items.length" class="pa-4">
        <v-skeleton-loader type="table-heading, table-row@6" />
      </div>

      <!-- Empty -->
      <EmptyState
        v-else-if="!filteredRows.length"
        icon="mdi-file-document-outline"
        :title="items.length ? 'No RFQs match these filters' : 'No RFQs yet'"
        :message="items.length ? 'Clear a filter or broaden your search to see more requests.' : 'Raise your first request for quotation to start collecting supplier bids.'"
      >
        <v-btn
          v-if="!items.length"
          color="purple"
          variant="flat"
          rounded="lg"
          class="text-none mt-3"
          prepend-icon="mdi-plus"
          :to="newRfqPath"
        >Create RFQ</v-btn>
        <v-btn
          v-else
          variant="tonal"
          color="purple"
          rounded="lg"
          class="text-none mt-3"
          prepend-icon="mdi-filter-off"
          @click="clearFilters"
        >Clear filters</v-btn>
      </EmptyState>

      <template v-else>
        <!-- Table view -->
        <div v-if="viewMode === 'table'" class="rfq-table-wrap">
          <table class="rfq-table">
            <thead>
              <tr>
                <th>RFQ</th>
                <th>Status</th>
                <th>Supplier quotes</th>
                <th class="text-center">Items</th>
                <th>Deadline</th>
                <th>Created</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredRows" :key="row.id" class="rfq-row" @click="openRfq(row)">
                <td>
                  <div class="rfq-id">{{ row.rfq_number }}</div>
                  <div class="rfq-rowtitle">{{ row.title || 'Untitled request' }}</div>
                  <div class="rfq-rowsub">
                    <v-icon size="12">mdi-store-marker</v-icon>
                    {{ row.branch_name || 'All branches' }}
                    <template v-if="row.awarded_supplier_name">
                      <span class="rfq-dot">·</span>
                      <v-icon size="12">mdi-trophy-outline</v-icon>
                      {{ row.awarded_supplier_name }}
                    </template>
                  </div>
                </td>
                <td><StatusChip :status="row.status" /></td>
                <td>
                  <div v-if="row.quoteCount" class="d-flex align-center" style="gap:8px">
                    <div class="rfq-avatars">
                      <v-avatar
                        v-for="s in row.suppliers.slice(0, 3)"
                        :key="s"
                        size="24"
                        :color="avatarColor(s)"
                        variant="tonal"
                      >
                        <span class="rfq-initials">{{ initials(s) }}</span>
                      </v-avatar>
                      <span v-if="row.suppliers.length > 3" class="rfq-more">+{{ row.suppliers.length - 3 }}</span>
                    </div>
                    <span class="rfq-quote-count">{{ row.quoteCount }}</span>
                  </div>
                  <span v-else class="text-caption text-medium-emphasis">Awaiting</span>
                </td>
                <td class="text-center"><span class="rfq-item-pill">{{ row.itemCount }}</span></td>
                <td>
                  <v-chip
                    size="small"
                    variant="tonal"
                    :color="row.deadline.color"
                    :prepend-icon="row.deadline.icon"
                  >{{ row.deadline.label }}</v-chip>
                </td>
                <td class="text-medium-emphasis">{{ formatDate(row.created_at) }}</td>
                <td class="text-right" @click.stop>
                  <div class="d-flex align-center justify-end" style="gap:2px">
                    <v-btn
                      size="small"
                      variant="text"
                      color="purple"
                      class="text-none"
                      @click="openRfq(row)"
                    >Open</v-btn>
                    <v-menu offset="4" location="bottom end">
                      <template #activator="{ props: menuProps }">
                        <v-btn v-bind="menuProps" icon="mdi-dots-vertical" variant="text" size="small" />
                      </template>
                      <v-list density="compact" min-width="210">
                        <v-list-item prepend-icon="mdi-eye-outline" title="View details" @click="openRfq(row)" />
                        <v-list-item
                          v-if="row.status === 'draft'"
                          prepend-icon="mdi-send"
                          title="Send to suppliers"
                          :disabled="actionLoading === row.id"
                          @click="sendToSuppliers(row)"
                        />
                        <v-list-item
                          v-if="row.status === 'awarded' && !row.awarded_po"
                          prepend-icon="mdi-cart-plus"
                          title="Create purchase order"
                          :disabled="actionLoading === row.id"
                          @click="createPo(row)"
                        />
                        <v-list-item
                          v-if="row.awarded_po"
                          prepend-icon="mdi-cart-check"
                          title="View purchase order"
                          @click="goToPo(row)"
                        />
                        <v-divider class="my-1" />
                        <v-list-item
                          v-if="['draft', 'cancelled'].includes(row.status)"
                          prepend-icon="mdi-trash-can-outline"
                          title="Delete RFQ"
                          base-color="error"
                          @click="askDelete(row)"
                        />
                      </v-list>
                    </v-menu>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Card view -->
        <div v-else class="rfq-grid">
          <v-card
            v-for="row in filteredRows"
            :key="row.id"
            rounded="lg"
            border
            elevation="0"
            class="rfq-grid-card"
            @click="openRfq(row)"
          >
            <div class="d-flex align-start justify-space-between" style="gap:10px">
              <div class="d-flex align-center" style="gap:10px; min-width:0">
                <v-avatar size="40" color="purple" variant="tonal" rounded="lg">
                  <v-icon size="20">mdi-file-document-outline</v-icon>
                </v-avatar>
                <div style="min-width:0">
                  <div class="rfq-id">{{ row.rfq_number }}</div>
                  <div class="rfq-gridtitle">{{ row.title || 'Untitled request' }}</div>
                </div>
              </div>
              <StatusChip :status="row.status" />
            </div>

            <div class="rfq-gridmeta">
              <span><v-icon size="13">mdi-store-marker</v-icon>{{ row.branch_name || 'All branches' }}</span>
              <span><v-icon size="13">mdi-package-variant-closed</v-icon>{{ row.itemCount }} item{{ row.itemCount === 1 ? '' : 's' }}</span>
              <span><v-icon size="13">mdi-calendar-blank</v-icon>{{ formatDate(row.created_at) }}</span>
            </div>

            <v-progress-linear
              :model-value="statusProgress(row.status)"
              :color="statusColor(row.status)"
              height="5"
              rounded
              class="my-3"
            />

            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <div class="d-flex align-center" style="gap:8px">
                <div class="rfq-avatars">
                  <v-avatar
                    v-for="s in row.suppliers.slice(0, 3)"
                    :key="s"
                    size="24"
                    :color="avatarColor(s)"
                    variant="tonal"
                  >
                    <span class="rfq-initials">{{ initials(s) }}</span>
                  </v-avatar>
                  <span v-if="row.suppliers.length > 3" class="rfq-more">+{{ row.suppliers.length - 3 }}</span>
                </div>
                <span class="text-caption text-medium-emphasis">{{ row.quoteCount }} quote{{ row.quoteCount === 1 ? '' : 's' }}</span>
              </div>
              <v-chip size="x-small" variant="tonal" :color="row.deadline.color" :prepend-icon="row.deadline.icon">
                {{ row.deadline.label }}
              </v-chip>
            </div>
          </v-card>
        </div>

        <div class="rfq-foot">
          <span class="text-caption text-medium-emphasis">
            Showing {{ filteredRows.length }} RFQ{{ filteredRows.length === 1 ? '' : 's' }}
            <template v-if="filteredRows.length !== stats.total"> of {{ stats.total }}</template>
          </span>
          <v-spacer />
          <span class="text-caption text-medium-emphasis">
            {{ stats.quotes }} quote{{ stats.quotes === 1 ? '' : 's' }} received in total
          </span>
        </div>
      </template>
    </v-card>

    <!-- ═══════════════ DELETE CONFIRM ═══════════════ -->
    <v-dialog v-model="deleteDialog" max-width="460" persistent>
      <v-card rounded="lg" class="overflow-hidden">
        <BrandDialogHeader
          icon="mdi-trash-can-outline"
          title="Delete request for quotation"
          :subtitle="deleteTarget?.rfq_number"
          @close="deleteDialog = false"
        />
        <div class="pa-5 text-body-2">
          This permanently removes <b>{{ deleteTarget?.title || 'this RFQ' }}</b>
          and any supplier quotes attached to it. This action cannot be undone.
        </div>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn
            color="error"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-trash-can"
            :loading="deleting"
            @click="confirmDelete"
          >Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
      <template #actions>
        <v-btn variant="text" @click="snack.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, reactive, onMounted, watch } from 'vue'
import { useResource } from '~/composables/useResource'
import { useBranchStore } from '~/stores/branch'
import { useBranding } from '~/composables/useBranding'
import { formatDate, formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const brand = useBranding()
const branchStore = useBranchStore()

const rfqRes = useResource('/purchase-orders/rfqs/')
const loading = computed(() => rfqRes.loading.value)
const items = computed(() => rfqRes.items.value || [])

// Keep every generated link inside the namespace the user arrived from
// (/ims, /pharmacy or the bare tree) instead of hard-coding /ims.
const ns = computed(() => {
  const p = route.path
  if (p.startsWith('/ims')) return '/ims'
  if (p.startsWith('/pharmacy')) return '/pharmacy'
  return ''
})
const newRfqPath = computed(() => `${ns.value}/purchase-orders/rfqs/new`)

// Tenant palette → CSS variables for the hero.
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

// ── Filters / view state ────────────────────────────────────────────────
const search = ref('')
const statusFilter = ref('all')
const branchFilter = ref('all')
const deadlineFilter = ref('all')
const sortKey = ref('newest')
const viewMode = ref('table')

const CLOSED = ['awarded', 'closed', 'cancelled']

const statusOptions = [
  { label: 'All', value: 'all', color: 'grey' },
  { label: 'Draft', value: 'draft', color: 'grey' },
  { label: 'Sent', value: 'sent', color: 'info' },
  { label: 'Quoted', value: 'quoted', color: 'warning' },
  { label: 'Awarded', value: 'awarded', color: 'success' },
  { label: 'Closed', value: 'closed', color: 'default' },
  { label: 'Cancelled', value: 'cancelled', color: 'error' }
]

const deadlineOptions = [
  { label: 'Any deadline', value: 'all' },
  { label: 'Overdue', value: 'overdue' },
  { label: 'Due in 7 days', value: 'due7' },
  { label: 'No deadline', value: 'none' }
]

const sortOptions = [
  { label: 'Newest first', value: 'newest' },
  { label: 'Deadline soonest', value: 'deadline' },
  { label: 'Most quotes', value: 'quotes' },
  { label: 'Title A–Z', value: 'title' }
]

const branchOptions = computed(() => {
  const opts = [{ label: 'All branches', value: 'all' }]
  for (const b of branchStore.activeBranches) opts.push({ label: b.name, value: b.id })
  return opts
})

const activeBranchLabel = computed(() => {
  if (branchFilter.value === 'all') return ''
  return branchStore.activeBranches.find((b) => b.id === branchFilter.value)?.name || ''
})

// ── Deadlines ───────────────────────────────────────────────────────────
function buildDeadline(date, status) {
  if (!date) {
    return { label: 'No deadline', color: 'grey', icon: 'mdi-calendar-blank-outline', days: null }
  }
  const iso = String(date).slice(0, 10)
  const parsed = new Date(`${iso}T00:00:00`)
  if (Number.isNaN(parsed.getTime())) {
    return { label: formatDate(date), color: 'grey', icon: 'mdi-calendar', days: null }
  }
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const days = Math.round((parsed - today) / 86400000)

  if (CLOSED.includes(status)) {
    return { label: formatDate(date), color: 'default', icon: 'mdi-calendar-check', days }
  }
  if (days < 0) {
    return { label: `${Math.abs(days)}d overdue`, color: 'error', icon: 'mdi-calendar-alert', days }
  }
  if (days === 0) {
    return { label: 'Due today', color: 'warning', icon: 'mdi-calendar-clock', days }
  }
  if (days <= 3) {
    return { label: `${days}d left`, color: 'warning', icon: 'mdi-calendar-clock', days }
  }
  if (days <= 7) {
    return { label: `${days}d left`, color: 'info', icon: 'mdi-calendar-clock', days }
  }
  return { label: `${days}d left`, color: 'success', icon: 'mdi-calendar-check', days }
}

// ── Enriched rows ───────────────────────────────────────────────────────
const enriched = computed(() =>
  items.value.map((r) => {
    const quotes = Array.isArray(r.quotes) ? r.quotes : []
    const totals = quotes
      .map((q) => Number(q.total_cost) || 0)
      .filter((n) => n > 0)
    const quoteCount = Number(r.quote_count ?? quotes.length) || 0
    const best = totals.length ? Math.min(...totals) : null
    const worst = totals.length ? Math.max(...totals) : null
    const deadline = buildDeadline(r.response_deadline, r.status)
    return {
      ...r,
      quotes,
      quoteCount,
      suppliers: quotes.map((q) => q.supplier_name).filter(Boolean),
      bestQuote: best,
      spread: best != null && worst != null ? worst - best : 0,
      itemCount: Array.isArray(r.items) ? r.items.length : 0,
      deadline,
      deadlineDays: deadline.days
    }
  })
)

// ── Aggregate KPIs ──────────────────────────────────────────────────────
const stats = computed(() => {
  const rows = enriched.value
  const total = rows.length
  const open = rows.filter((r) => ['draft', 'sent', 'quoted'].includes(r.status)).length
  const quotes = rows.reduce((n, r) => n + r.quoteCount, 0)
  const quoted = rows.filter((r) => r.status === 'quoted').length
  const awarded = rows.filter((r) => r.status === 'awarded').length
  const ordered = rows.filter((r) => r.awarded_po).length
  const overdue = rows.filter(
    (r) => r.deadlineDays != null && r.deadlineDays < 0 && !CLOSED.includes(r.status)
  ).length
  const dueSoon = rows.filter(
    (r) =>
      r.deadlineDays != null &&
      r.deadlineDays >= 0 &&
      r.deadlineDays <= 7 &&
      !CLOSED.includes(r.status)
  ).length
  const spread = rows.reduce((n, r) => n + r.spread, 0)
  const avgQuotes = total ? quotes / total : 0
  return {
    total,
    open,
    quotes,
    quoted,
    awarded,
    ordered,
    overdue,
    dueSoon,
    atRisk: overdue + dueSoon,
    spread,
    avgQuotes
  }
})

const kpiTiles = computed(() => {
  const s = stats.value
  return [
    {
      title: 'Total requests',
      value: String(s.total),
      icon: 'mdi-file-document-multiple-outline',
      color: 'purple',
      hint: `${s.open} still open`,
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Quotes received',
      value: String(s.quotes),
      icon: 'mdi-cash-multiple',
      color: 'info',
      hint: `${s.avgQuotes.toFixed(1)} avg per RFQ`,
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Awaiting award',
      value: String(s.quoted),
      icon: 'mdi-gavel',
      color: 'warning',
      hint: 'Quotes in, decision pending',
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Awarded',
      value: String(s.awarded),
      icon: 'mdi-trophy-outline',
      color: 'success',
      hint: `${s.ordered} converted to a PO`,
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Deadline risk',
      value: String(s.atRisk),
      icon: 'mdi-calendar-alert',
      color: 'error',
      hint: `${s.overdue} overdue · ${s.dueSoon} due this week`,
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Bid spread',
      value: formatMoney(s.spread),
      valueNum: s.spread,
      icon: 'mdi-swap-horizontal-bold',
      color: 'teal',
      hint: 'Best vs highest quote',
      deltaLabel: '',
      flat: true
    }
  ]
})

function statusCount(value) {
  if (value === 'all') return stats.value.total
  return enriched.value.filter((r) => r.status === value).length
}

// ── Filtering / sorting ─────────────────────────────────────────────────
function sortRows(rows) {
  const arr = rows.slice()
  if (sortKey.value === 'deadline') {
    return arr.sort((a, b) => (a.deadlineDays ?? 999999) - (b.deadlineDays ?? 999999))
  }
  if (sortKey.value === 'quotes') {
    return arr.sort((a, b) => b.quoteCount - a.quoteCount)
  }
  if (sortKey.value === 'title') {
    return arr.sort((a, b) => String(a.title || '').localeCompare(String(b.title || '')))
  }
  return arr.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
}

const filteredRows = computed(() => {
  const q = (search.value || '').trim().toLowerCase()
  let rows = enriched.value

  if (statusFilter.value !== 'all') {
    rows = rows.filter((r) => r.status === statusFilter.value)
  }
  if (branchFilter.value !== 'all') {
    rows = rows.filter((r) => r.branch === branchFilter.value)
  }
  if (deadlineFilter.value !== 'all') {
    rows = rows.filter((r) => {
      if (deadlineFilter.value === 'none') return r.deadlineDays == null
      if (CLOSED.includes(r.status)) return false
      if (deadlineFilter.value === 'overdue') {
        return r.deadlineDays != null && r.deadlineDays < 0
      }
      if (deadlineFilter.value === 'due7') {
        return r.deadlineDays != null && r.deadlineDays >= 0 && r.deadlineDays <= 7
      }
      return true
    })
  }
  if (q) {
    rows = rows.filter((r) =>
      [
        r.rfq_number,
        r.title,
        r.description,
        r.branch_name,
        r.awarded_supplier_name,
        ...r.suppliers
      ].some((v) => String(v || '').toLowerCase().includes(q))
    )
  }
  return sortRows(rows)
})

function clearFilters() {
  search.value = ''
  statusFilter.value = 'all'
  branchFilter.value = 'all'
  deadlineFilter.value = 'all'
  sortKey.value = 'newest'
}

// ── Helpers ─────────────────────────────────────────────────────────────
const STATUS_COLORS = {
  draft: 'grey',
  sent: 'info',
  quoted: 'warning',
  awarded: 'success',
  closed: 'default',
  cancelled: 'error'
}
function statusColor(s) {
  return STATUS_COLORS[s] || 'grey'
}
function statusProgress(s) {
  return { draft: 12, sent: 45, quoted: 75, awarded: 100, closed: 100, cancelled: 0 }[s] || 0
}

const AVATAR_COLORS = ['purple', 'indigo', 'teal', 'deep-orange', 'blue', 'green', 'pink', 'cyan']
function avatarColor(name) {
  let h = 0
  for (const ch of String(name || '')) h = (h * 31 + ch.charCodeAt(0)) % 997
  return AVATAR_COLORS[h % AVATAR_COLORS.length]
}
function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
}

// ── Loading ─────────────────────────────────────────────────────────────
async function load() {
  await Promise.all([rfqRes.list({ page_size: 500 }), branchStore.load(), brand.load()])
}

// ── Actions ─────────────────────────────────────────────────────────────
const actionLoading = ref(null)
const snack = reactive({ show: false, text: '', color: 'success' })

function notify(text, color = 'success') {
  snack.text = text
  snack.color = color
  snack.show = true
}

function errorMessage(e) {
  const data = e?.response?.data
  return data?.detail || (data ? JSON.stringify(data) : e?.message) || 'Something went wrong.'
}

function openRfq(row) {
  navigateTo(`${ns.value}/purchase-orders/rfqs/${row.id}`)
}
function goToPo(row) {
  navigateTo(`${ns.value}/purchase-orders/${row.awarded_po}`)
}

async function sendToSuppliers(row) {
  if (actionLoading.value) return
  actionLoading.value = row.id
  try {
    await $api.post(`/purchase-orders/rfqs/${row.id}/send_to_suppliers/`)
    notify(`RFQ ${row.rfq_number} sent to suppliers.`)
    await load()
  } catch (e) {
    notify(errorMessage(e), 'error')
  } finally {
    actionLoading.value = null
  }
}

async function createPo(row) {
  if (actionLoading.value) return
  actionLoading.value = row.id
  try {
    const { data } = await $api.post(`/purchase-orders/rfqs/${row.id}/create_po/`)
    notify(`Purchase order created from ${row.rfq_number}.`)
    navigateTo(`${ns.value}/purchase-orders/${data.id}`)
  } catch (e) {
    notify(errorMessage(e), 'error')
    actionLoading.value = null
  }
}

// Delete
const deleteDialog = ref(false)
const deleting = ref(false)
const deleteTarget = ref(null)

function askDelete(row) {
  deleteTarget.value = row
  deleteDialog.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`/purchase-orders/rfqs/${deleteTarget.value.id}/`)
    notify(`RFQ ${deleteTarget.value.rfq_number} deleted.`)
    deleteDialog.value = false
    deleteTarget.value = null
    await load()
  } catch (e) {
    notify(errorMessage(e), 'error')
  } finally {
    deleting.value = false
  }
}

// CSV export
function exportCsv() {
  const rows = filteredRows.value
  const headers = [
    'RFQ #',
    'Title',
    'Status',
    'Branch',
    'Items',
    'Quotes',
    'Best quote',
    'Bid spread',
    'Deadline',
    'Created',
    'Awarded supplier',
    'PO'
  ]
  const lines = [
    headers,
    ...rows.map((r) => [
      r.rfq_number,
      r.title,
      r.status,
      r.branch_name || '',
      r.itemCount,
      r.quoteCount,
      r.bestQuote ?? '',
      r.spread || '',
      r.response_deadline || '',
      String(r.created_at || '').slice(0, 10),
      r.awarded_supplier_name || '',
      r.awarded_po || ''
    ])
  ]
  const csv = lines
    .map((line) =>
      line
        .map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`)
        .join(',')
    )
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `rfqs-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(() => {
  // Remember the last list presentation (table vs cards) across visits.
  if (import.meta.client) {
    const saved = localStorage.getItem('rfq.viewMode')
    if (saved === 'grid' || saved === 'table') viewMode.value = saved
  }
  load()
})

watch(viewMode, (mode) => {
  if (import.meta.client) localStorage.setItem('rfq.viewMode', mode)
})
</script>

<style scoped>
/* ═══════════════ Hero ═══════════════ */
.rfq-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.rfq-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.rfq-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.rfq-hero-top {
  position: relative;
}
.rfq-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.rfq-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.rfq-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.rfq-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.rfq-hero-iconbtn {
  color: #fff !important;
}
.rfq-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.rfq-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
}
.rfq-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.rfq-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.rfq-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.rfq-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
.rfq-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.rfq-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.94);
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.24);
}
.rfq-hero-chip-alert {
  background: rgba(239, 68, 68, 0.28);
  border-color: rgba(255, 255, 255, 0.45);
}

/* ═══════════════ Cards / toolbar ═══════════════ */
.rfq-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.rfq-chipgroup :deep(.v-chip) {
  margin-inline-end: 6px;
}
.rfq-chip-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  margin-left: 6px;
  padding: 0 5px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  background: rgba(15, 23, 42, 0.08);
}

/* ═══════════════ Table ═══════════════ */
.rfq-table-wrap {
  overflow-x: auto;
}
.rfq-table {
  width: 100%;
  min-width: 940px;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 14px;
}
.rfq-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgb(var(--v-theme-surface));
  border-bottom: 1.5px solid rgba(15, 23, 42, 0.1);
  padding: 12px 16px;
  white-space: nowrap;
}
.rfq-table thead th.text-right {
  text-align: right;
}
.rfq-table thead th.text-center {
  text-align: center;
}
.rfq-table tbody td {
  padding: 13px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.055);
  vertical-align: middle;
}
.rfq-table tbody td.text-right {
  text-align: right;
}
.rfq-table tbody td.text-center {
  text-align: center;
}
.rfq-row {
  cursor: pointer;
  transition: background 0.12s ease;
}
.rfq-row:hover {
  background: rgba(var(--v-theme-primary), 0.035);
}
.rfq-row:last-child td {
  border-bottom: none;
}
.rfq-id {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.5px;
  color: rgb(var(--v-theme-primary));
  text-transform: uppercase;
}
.rfq-rowtitle {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
  margin-top: 1px;
}
.rfq-rowsub {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 3px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.rfq-dot {
  opacity: 0.5;
}
.rfq-avatars {
  display: inline-flex;
  align-items: center;
}
.rfq-avatars :deep(.v-avatar) {
  border: 2px solid rgb(var(--v-theme-surface));
  margin-left: -7px;
}
.rfq-avatars :deep(.v-avatar:first-child) {
  margin-left: 0;
}
.rfq-initials {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.2px;
}
.rfq-more {
  margin-left: 4px;
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.rfq-quote-count {
  font-size: 13px;
  font-weight: 700;
}
.rfq-item-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 28px;
  height: 24px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  background: rgba(15, 23, 42, 0.06);
}

/* ═══════════════ Card grid ═══════════════ */
.rfq-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 14px;
  padding: 16px;
}
.rfq-grid-card {
  padding: 16px;
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.rfq-grid-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 28px rgba(15, 23, 42, 0.09);
}
.rfq-gridtitle {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.rfq-gridmeta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 14px;
  margin-top: 14px;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.rfq-gridmeta span {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

/* ═══════════════ Footer ═══════════════ */
.rfq-foot {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  padding: 12px 18px;
  border-top: 1px solid rgba(15, 23, 42, 0.07);
  background: rgba(15, 23, 42, 0.015);
}

@media (max-width: 600px) {
  .rfq-title {
    font-size: 22px;
  }
  .rfq-grid {
    grid-template-columns: 1fr;
    padding: 12px;
  }
}
</style>
