<template>
  <v-container fluid class="pa-4 pa-md-6 crm-list-shell">
    <PageHeader title="Customer CRM" icon="mdi-account-tie-hat-outline" color="indigo" :subtitle="pageSubtitle">
      <template #actions>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load" />
        <v-btn variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-file-delimited" @click="exportCsv">Export CSV</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-account-plus" @click="openDialog()">New Customer</v-btn>
      </template>
    </PageHeader>

    <!-- Stat cards -->
    <v-row dense class="mb-2">
      <v-col v-for="(s, i) in statCards" :key="i" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 crm-stat" :class="`crm-stat-${s.key}`">
          <div class="d-flex align-center mb-2">
            <v-icon :color="s.color" class="mr-2">{{ s.icon }}</v-icon>
            <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">{{ s.label }}</div>
          </div>
          <div class="text-h5 font-weight-bold">{{ s.value }}</div>
          <div v-if="s.sub" class="text-caption text-medium-emphasis mt-1">{{ s.sub }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters -->
    <v-card rounded="lg" class="pa-3 mb-3 crm-filter-bar">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-text-field
          v-model="search"
          placeholder="Search name, phone or email…"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          prepend-inner-icon="mdi-magnify"
          bg-color="surface"
          clearable
          class="flex-grow-1"
          style="min-width: 260px"
        />
        <v-select
          v-model="filterStatus"
          :items="statusItems"
          item-title="title"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-check-circle-outline"
          style="max-width: 180px; min-width: 150px"
        />
        <v-select
          v-model="filterTier"
          :items="tierItems"
          item-title="title"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-medal-outline"
          style="max-width: 180px; min-width: 150px"
        />
        <v-select
          v-model="sortBy"
          :items="sortItems"
          item-title="title"
          item-value="value"
          variant="solo-filled"
          density="comfortable"
          hide-details
          flat
          rounded="lg"
          bg-color="surface"
          prepend-inner-icon="mdi-sort"
          style="max-width: 200px; min-width: 160px"
        />
      </div>
    </v-card>

    <!-- Body -->
    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <EmptyState
      v-else-if="!filteredItems.length"
      icon="mdi-account-search"
      title="No customers found"
      message="Add your first customer or adjust your filters."
    >
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-account-plus" @click="openDialog()" class="text-none">New Customer</v-btn>
      </template>
    </EmptyState>

    <!-- Table -->
    <v-card v-else rounded="lg" class="crm-table-card">
      <v-data-table
        v-model:page="page"
        v-model:items-per-page="itemsPerPage"
        :headers="headers"
        :items="filteredItems"
        :items-per-page-options="perPageOptions"
        density="comfortable"
        hover
        item-value="id"
        class="crm-data-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <!-- Row number -->
        <template #item.rownum="{ index }">
          <span class="text-caption text-medium-emphasis">{{ (page - 1) * itemsPerPage + index + 1 }}</span>
        </template>

        <!-- Customer avatar + name -->
        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="avatarColor(item.name)" size="40" class="mr-3 crm-avatar" variant="tonal">
              <span class="text-body-2 font-weight-bold">{{ initials(item.name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-body-1 text-truncate" style="max-width: 240px">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis text-truncate" style="max-width: 240px">{{ item.email || '—' }}</div>
            </div>
          </div>
        </template>

        <!-- Phone -->
        <template #item.phone="{ item }">
          <div class="d-flex align-center">
            <v-icon size="14" color="medium-emphasis" class="mr-1">mdi-phone-outline</v-icon>
            <span class="font-mono text-body-2">{{ item.phone || '—' }}</span>
          </div>
        </template>

        <!-- Total spent with bar -->
        <template #item.total_purchases="{ item }">
          <div class="text-right">
            <div class="font-weight-bold" :class="spendClass(item.total_purchases)">
              {{ formatMoney(item.total_purchases || 0) }}
            </div>
            <div v-if="spendPct(item.total_purchases)" class="crm-spend-bar-wrap">
              <div class="crm-spend-bar" :style="{ width: spendPct(item.total_purchases) + '%', background: spendColor(item.total_purchases) }" />
            </div>
          </div>
        </template>

        <!-- Visits -->
        <template #item.visit_count="{ item }">
          <div class="d-flex align-center">
            <v-icon size="16" :color="item.visit_count >= 10 ? 'indigo' : 'grey'" class="mr-1">mdi-store-check-outline</v-icon>
            <span :class="item.visit_count >= 10 ? 'font-weight-bold' : ''">{{ item.visit_count || 0 }}</span>
            <span class="text-caption text-medium-emphasis ml-1">visits</span>
          </div>
        </template>

        <!-- Loyalty tier chip -->
        <template #item.loyalty_tier="{ item }">
          <v-chip :color="tierMeta(item.loyalty_tier || tier(item).key).color" size="small" variant="tonal" class="crm-tier-chip">
            <v-icon start size="14">{{ tierMeta(item.loyalty_tier || tier(item).key).icon }}</v-icon>
            {{ tierMeta(item.loyalty_tier || tier(item).key).label }}
          </v-chip>
        </template>

        <!-- Status -->
        <template #item.is_active="{ item }">
          <div class="d-inline-flex align-center">
            <div class="crm-status-dot" :class="item.is_active ? 'crm-dot-active' : 'crm-dot-inactive'" />
            <span class="text-body-2" :class="item.is_active ? 'text-success' : 'text-medium-emphasis'">
              {{ item.is_active ? 'Active' : 'Inactive' }}
            </span>
          </div>
        </template>

        <!-- Joined date -->
        <template #item.created_at="{ item }">
          <div class="d-flex align-center text-medium-emphasis">
            <v-icon size="14" class="mr-1">mdi-calendar-blank-outline</v-icon>
            <span class="text-caption">{{ formatDate(item.created_at) }}</span>
          </div>
        </template>

        <!-- Actions -->
        <template #item.actions="{ item }">
          <div class="d-flex" style="gap: 2px">
            <v-tooltip text="View details" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye" variant="text" size="small" color="indigo" @click.stop="goToDetail(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil" variant="text" size="small" @click.stop="openDialog(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Delete" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-delete" variant="text" size="small" color="error" @click.stop="confirmDelete(item)" />
              </template>
            </v-tooltip>
          </div>
        </template>

        <!-- Bottom row summary -->
        <template #bottom="{ page: currentPage, pageCount: total, setPage }">
          <div class="d-flex align-center justify-space-between pa-3 crm-table-bottom">
            <div class="text-caption text-medium-emphasis">
              Showing {{ filteredItems.length }} customers
              <span v-if="filterStatus !== 'all' || filterTier !== 'all' || search"> (filtered)</span>
            </div>
            <div class="d-flex align-center" style="gap: 8px">
              <v-btn icon="mdi-chevron-left" variant="text" size="small" :disabled="currentPage <= 1" @click="setPage(currentPage - 1)" />
              <span class="text-body-2 font-weight-medium">{{ currentPage }} / {{ total }}</span>
              <v-btn icon="mdi-chevron-right" variant="text" size="small" :disabled="currentPage >= total" @click="setPage(currentPage + 1)" />
            </div>
          </div>
        </template>

        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-2">mdi-account-search</v-icon>
            <div class="text-body-2 mt-2">No customers found.</div>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ Create / Edit dialog ═══ -->
    <v-dialog v-model="dialog" max-width="620" persistent>
      <v-card rounded="xl" class="crm-dialog">
        <div class="crm-dialog-header">
          <div class="d-flex align-center">
            <v-icon color="primary" size="26" class="mr-3">{{ editing ? 'mdi-account-edit' : 'mdi-account-plus' }}</v-icon>
            <span class="text-h6 font-weight-bold">{{ editing ? 'Edit Customer' : 'New Customer' }}</span>
          </div>
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </div>
        <v-divider />
        <v-card-text class="pt-4 pb-1">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.name" label="Full name *" variant="outlined"
                            density="comfortable" :error-messages="formErrors.name" autofocus />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone *" variant="outlined"
                            density="comfortable" prepend-inner-icon="mdi-phone"
                            placeholder="07xx xxx xxx"
                            :error-messages="formErrors.phone" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" variant="outlined"
                            density="comfortable" prepend-inner-icon="mdi-email"
                            :error-messages="formErrors.email" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.branch" :items="branchOptions" item-title="name" item-value="id"
                        label="Branch (warehouse)" variant="outlined" density="comfortable"
                        prepend-inner-icon="mdi-store-marker" clearable
                        hint="Leave empty for shared / all branches" persistent-hint />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.address" label="Address" variant="outlined"
                          density="comfortable" rows="2" auto-grow
                          :error-messages="formErrors.address" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" variant="outlined"
                          density="comfortable" rows="2" auto-grow
                          placeholder="Allergies, preferences, special instructions…"
                          :error-messages="formErrors.notes" />
            </v-col>
            <v-col cols="12">
              <v-switch v-model="form.is_active" color="success" label="Active customer"
                        hide-details inset />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Create customer' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Detail drawer (right-side panel) ═══ -->
    <v-navigation-drawer v-model="detailDrawer" location="right" width="460" temporary
                        class="crm-detail-drawer">
      <div v-if="selected" class="d-flex flex-column h-100">
        <!-- Profile header -->
        <div class="crm-profile-header">
          <div class="d-flex align-start justify-space-between pa-5 pb-3">
            <div class="d-flex align-center">
              <v-avatar :color="avatarColor(selected.name)" size="56" class="mr-3 elevation-2" variant="tonal">
                <span class="text-h6 font-weight-bold">{{ initials(selected.name) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-width-0">
                <div class="text-h6 font-weight-bold text-truncate">{{ selected.name }}</div>
                <div v-if="selected.phone" class="text-body-2 text-medium-emphasis d-flex align-center mt-1">
                  <v-icon size="14" class="mr-1">mdi-phone</v-icon> {{ selected.phone }}
                </div>
                <div v-if="selected.email" class="text-body-2 text-medium-emphasis d-flex align-center">
                  <v-icon size="14" class="mr-1">mdi-email</v-icon> {{ selected.email }}
                </div>
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" @click="detailDrawer = false" />
          </div>
          <div class="px-5 pb-3">
            <v-chip :color="tierMeta(selected.loyalty_tier || tier(selected).key).color" size="small" variant="tonal">
              <v-icon start size="16">{{ tierMeta(selected.loyalty_tier || tier(selected).key).icon }}</v-icon>
              {{ tierMeta(selected.loyalty_tier || tier(selected).key).label }}
            </v-chip>
            <v-chip :color="selected.is_active ? 'success' : 'grey'" size="small" variant="tonal" class="ml-2">
              <v-icon start size="14">{{ selected.is_active ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon>
              {{ selected.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>
        </div>

        <!-- Scrollable content -->
        <div class="flex-grow-1 overflow-y-auto pa-5 pt-3">
          <!-- Stats row -->
          <div class="d-flex mb-4" style="gap: 12px">
            <div class="crm-stat-box flex-grow-1">
              <div class="text-caption text-medium-emphasis">Total spent</div>
              <div class="text-h5 font-weight-bold text-success mt-1">
                {{ formatMoney(selected.total_purchases || 0) }}
              </div>
            </div>
            <div class="crm-stat-box flex-grow-1">
              <div class="text-caption text-medium-emphasis">Visits</div>
              <div class="text-h5 font-weight-bold text-indigo mt-1">{{ selected.visit_count || 0 }}</div>
            </div>
          </div>

          <!-- Secondary stats -->
          <div class="d-flex mb-4" style="gap: 12px">
            <div class="crm-stat-box flex-grow-1">
              <div class="text-caption text-medium-emphasis">Loyalty points</div>
              <div class="text-subtitle-1 font-weight-bold text-amber mt-1">{{ selected.loyalty_points || 0 }}</div>
            </div>
            <div class="crm-stat-box flex-grow-1">
              <div class="text-caption text-medium-emphasis">Member since</div>
              <div class="text-subtitle-1 font-weight-medium mt-1">{{ formatDate(selected.loyalty_joined_at || selected.created_at) }}</div>
            </div>
          </div>

          <v-divider class="mb-3" />

          <!-- Contact details -->
          <div v-if="branchOptions.find(b => b.id === selected.branch)" class="mb-3">
            <div class="text-caption text-medium-emphasis mb-1">Branch</div>
            <v-chip size="small" variant="tonal" color="primary">
              {{ branchOptions.find(b => b.id === selected.branch).name }}
            </v-chip>
          </div>
          <div v-else class="mb-3">
            <div class="text-caption text-medium-emphasis mb-1">Branch</div>
            <span class="text-body-2 text-medium-emphasis">All branches (shared)</span>
          </div>

          <div v-if="selected.address" class="mb-3">
            <div class="text-caption text-medium-emphasis mb-1">Address</div>
            <div class="text-body-2">{{ selected.address }}</div>
          </div>
          <div v-if="selected.notes" class="mb-3">
            <div class="text-caption text-medium-emphasis mb-1">Notes</div>
            <div class="text-body-2 crm-notes-text">{{ selected.notes }}</div>
          </div>

          <div class="d-flex text-caption text-medium-emphasis mb-2">
            <div class="mr-4"><v-icon size="14">mdi-calendar-plus</v-icon> Joined {{ formatDate(selected.created_at) }}</div>
            <div><v-icon size="14">mdi-update</v-icon> Updated {{ formatDate(selected.updated_at) }}</div>
          </div>

          <!-- Recent transactions -->
          <v-divider class="my-3" />
          <div class="d-flex align-center mb-3">
            <v-icon color="primary" class="mr-2" size="20">mdi-receipt-text</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Recent transactions</div>
          </div>
          <div v-if="txLoading" class="text-center py-4">
            <v-progress-circular indeterminate size="24" color="primary" />
          </div>
          <div v-else-if="!recentTx.length" class="text-caption text-medium-emphasis py-2 text-center">
            <v-icon size="32" color="grey-lighten-2" class="d-block mx-auto mb-2">mdi-cart-off</v-icon>
            No transactions yet for this customer.
          </div>
          <v-list v-else density="compact" class="pa-0" lines="two">
            <v-list-item v-for="t in recentTx" :key="t.id" class="px-2 crm-tx-item">
              <template #prepend>
                <v-avatar size="36" color="primary" variant="tonal" rounded>
                  <v-icon size="18">mdi-cart</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2 font-weight-medium">
                {{ t.transaction_number }}
              </v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ formatDateTime(t.created_at) }} · {{ t.payment_method }}
              </v-list-item-subtitle>
              <template #append>
                <span class="text-body-2 font-weight-bold text-success">{{ formatMoney(t.total) }}</span>
              </template>
            </v-list-item>
          </v-list>
        </div>

        <!-- Footer actions -->
        <v-divider />
        <div class="d-flex align-center pa-4">
          <v-btn variant="text" color="error" prepend-icon="mdi-delete"
                 @click="confirmDelete(selected); detailDrawer = false">Delete</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" prepend-icon="mdi-pencil"
                 @click="openDialog(selected); detailDrawer = false">Edit</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═══ Delete confirm ═══ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <div class="d-flex align-center pa-4 pb-2">
          <v-avatar color="error" variant="tonal" rounded size="40" class="mr-3">
            <v-icon color="error">mdi-delete-alert</v-icon>
          </v-avatar>
          <span class="text-h6 font-weight-bold">Delete customer?</span>
        </div>
        <v-card-text>
          <strong>{{ target?.name }}</strong> will be removed. Past transactions remain but lose the customer link.
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="pill">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()

const page = ref(1)
const items = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const filterStatus = ref('all')
const filterTier = ref('all')
const sortBy = ref('name')
const itemsPerPage = ref(25)
const perPageOptions = [
  { value: 10, title: '10' },
  { value: 25, title: '25' },
  { value: 50, title: '50' },
  { value: 100, title: '100' },
]

const statusItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]
const tierItems = [
  { title: 'All Tiers', value: 'all' },
  { title: 'Platinum', value: 'platinum' },
  { title: 'Gold', value: 'gold' },
  { title: 'Silver', value: 'silver' },
  { title: 'Bronze', value: 'bronze' },
]
const sortItems = [
  { title: 'Name (A-Z)', value: 'name' },
  { title: 'Top spenders', value: 'spend' },
  { title: 'Most visits', value: 'visits' },
  { title: 'Newest first', value: 'newest' },
]

const headers = [
  { title: '#', key: 'rownum', width: 50, sortable: false },
  { title: 'Customer', key: 'name', sortable: true, width: '280px' },
  { title: 'Phone', key: 'phone', sortable: false },
  { title: 'Total spent', key: 'total_purchases', sortable: true, align: 'end', width: '180px' },
  { title: 'Visits', key: 'visit_count', sortable: true, align: 'start', width: '120px' },
  { title: 'Tier', key: 'loyalty_tier', sortable: false, width: '130px' },
  { title: 'Status', key: 'is_active', sortable: true, width: '120px' },
  { title: 'Joined', key: 'created_at', sortable: true, width: '140px' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: '150px' },
]

const dialog = ref(false)
const editing = ref(null)
const form = reactive({
  name: '', phone: '', email: '', branch: null, address: '', notes: '', is_active: true,
})
const branchOptions = computed(() => branchStore.activeBranches || [])
const formErrors = reactive({})

const detailDrawer = ref(false)
const selected = ref(null)
const recentTx = ref([])
const txLoading = ref(false)

const deleteDialog = ref(false)
const target = ref(null)

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

const pageSubtitle = computed(() => {
  const base = 'Manage profiles, loyalty tiers & purchase history'
  return branchStore.currentBranch ? `${base} · ${branchStore.currentBranch.name}` : base
})

// ── Tier metadata ────────────────────────────────────────────────────────
const TIER_MAP = {
  platinum: { label: 'Platinum', color: 'deep-purple', icon: 'mdi-crown', key: 'platinum' },
  gold:     { label: 'Gold',     color: 'amber-darken-2', icon: 'mdi-medal', key: 'gold' },
  silver:   { label: 'Silver',   color: 'blue-grey', icon: 'mdi-shield-star', key: 'silver' },
  bronze:   { label: 'Bronze',   color: 'orange-darken-2', icon: 'mdi-account-star', key: 'bronze' },
}
function tierMeta(key) { return TIER_MAP[key] || { label: key, color: 'grey', icon: 'mdi-account', key } }

function tier(c) {
  const v = Number(c?.total_purchases || 0)
  if (v >= 100000) return { label: 'Platinum', key: 'platinum', color: 'deep-purple', icon: 'mdi-crown' }
  if (v >= 50000)  return { label: 'Gold',     key: 'gold',     color: 'amber-darken-2', icon: 'mdi-medal' }
  if (v >= 10000)  return { label: 'Silver',   key: 'silver',   color: 'blue-grey', icon: 'mdi-shield-star' }
  if (v > 0)       return { label: 'Bronze',   key: 'bronze',   color: 'orange-darken-2', icon: 'mdi-account-star' }
  return { label: 'New', key: 'bronze', color: 'grey', icon: 'mdi-sparkles' }
}

// ── Spend bar helpers ─────────────────────────────────────────────────────
const MAX_SPEND = computed(() => {
  const m = Math.max(1, ...items.value.map(c => Number(c.total_purchases || 0)))
  return m
})
function spendPct(v) {
  const pct = (Number(v || 0) / MAX_SPEND.value) * 100
  return pct > 0 ? Math.max(8, Math.min(100, pct)) : 0
}
function spendColor(v) {
  if (v >= 100000) return 'linear-gradient(90deg, #6750A4, #9c82d4)'
  if (v >= 50000)  return 'linear-gradient(90deg, #F9A825, #FBC02D)'
  if (v >= 10000)  return 'linear-gradient(90deg, #455A64, #78909C)'
  if (v > 0)       return 'linear-gradient(90deg, #E65100, #FF9800)'
  return 'transparent'
}
function spendClass(v) {
  if (Number(v || 0) >= 50000) return 'text-success'
  return ''
}

// ── Stat cards ───────────────────────────────────────────────────────────
const statCards = computed(() => {
  const total = items.value.length
  const active = items.value.filter(c => c.is_active).length
  const totalSpend = items.value.reduce((s, c) => s + Number(c.total_purchases || 0), 0)
  const vip = items.value.filter(c => Number(c.total_purchases || 0) >= 50000).length
  return [
    { key: 'total', label: 'Total Customers', value: total, icon: 'mdi-account-group', color: 'primary', sub: `${active} active` },
    { key: 'revenue', label: 'Lifetime Revenue', value: formatMoney(totalSpend), icon: 'mdi-cash-multiple', color: 'success', sub: 'all-time spend' },
    { key: 'points', label: 'Loyalty Points', value: items.value.reduce((s, c) => s + Number(c.loyalty_points || 0), 0).toLocaleString(), icon: 'mdi-star-circle', color: 'amber', sub: 'across all tiers' },
    { key: 'vip', label: 'VIPs (50K+)', value: vip, icon: 'mdi-crown', color: 'deep-purple', sub: 'gold & platinum' },
  ]
})

// ── Filtered & sorted items ──────────────────────────────────────────────
const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let rows = items.value.filter(c => {
    if (filterStatus.value === 'active' && !c.is_active) return false
    if (filterStatus.value === 'inactive' && c.is_active) return false
    if (filterTier.value !== 'all') {
      const tKey = c.loyalty_tier || tier(c).key
      if (tKey !== filterTier.value) return false
    }
    if (!q) return true
    return ['name', 'phone', 'email'].some(k => (c[k] || '').toLowerCase().includes(q))
  })
  const sorters = {
    name: (a, b) => (a.name || '').localeCompare(b.name || ''),
    spend: (a, b) => Number(b.total_purchases || 0) - Number(a.total_purchases || 0),
    visits: (a, b) => (b.visit_count || 0) - (a.visit_count || 0),
    newest: (a, b) => (b.created_at || '').localeCompare(a.created_at || ''),
  }
  return [...rows].sort(sorters[sortBy.value] || sorters.name)
})

// ── Load ─────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const params = { ordering: 'name', page_size: 500 }
    if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
    const { data } = await $api.get('/pos/customers/', { params })
    items.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load customers', 'error')
    items.value = []
  } finally {
    loading.value = false
  }
}

// ── CRUD ─────────────────────────────────────────────────────────────────
function openDialog(c = null) {
  editing.value = c
  Object.assign(form, c ? {
    name: c.name, phone: c.phone || '', email: c.email || '',
    branch: c.branch || null, address: c.address || '', notes: c.notes || '', is_active: c.is_active,
  } : { name: '', phone: '', email: '', branch: null, address: '', notes: '', is_active: true })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  dialog.value = true
}

async function save() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!form.name?.trim()) { formErrors.name = 'Name is required'; return }
  if (!form.phone?.trim()) { formErrors.phone = 'Phone is required'; return }
  saving.value = true
  try {
    if (editing.value) {
      await $api.patch(`/pos/customers/${editing.value.id}/`, form)
      notify('Customer updated')
    } else {
      await $api.post('/pos/customers/', form)
      notify('Customer created')
    }
    dialog.value = false
    await load()
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) {
        formErrors[k] = Array.isArray(v) ? v.join(' ') : String(v)
      }
    }
    notify(extractError(e) || 'Save failed', 'error')
  } finally {
    saving.value = false
  }
}

function goToDetail(c) {
  const route = useRoute()
  const ns = route.path.startsWith('/ims') ? '/ims' : route.path.startsWith('/pharmacy') ? '/pharmacy' : ''
  navigateTo(`${ns}/customers/${c.id}`)
}

async function openDetail(c) {
  selected.value = c
  detailDrawer.value = true
  recentTx.value = []
  txLoading.value = true
  try {
    const txParams = { customer: c.id, ordering: '-created_at', page_size: 10 }
    if (branchStore.currentBranchId) txParams.branch = branchStore.currentBranchId
    const { data } = await $api.get('/pos/transactions/', { params: txParams })
    recentTx.value = (data?.results || (Array.isArray(data) ? data : [])).slice(0, 10)
  } catch {
    recentTx.value = []
  } finally {
    txLoading.value = false
  }
}

function confirmDelete(c) { target.value = c; deleteDialog.value = true }
async function doDelete() {
  if (!target.value) return
  saving.value = true
  try {
    await $api.delete(`/pos/customers/${target.value.id}/`)
    notify('Customer deleted')
    deleteDialog.value = false
    await load()
  } catch (e) {
    notify(extractError(e) || 'Delete failed', 'error')
  } finally {
    saving.value = false
  }
}

// ── Export CSV ────────────────────────────────────────────────────────────
function exportCsv() {
  const rows = filteredItems.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const lines = ['Name,Phone,Email,Address,Total Spent,Visits,Tier,Loyalty Points,Status,Joined']
  rows.forEach(c => {
    lines.push([
      JSON.stringify(c.name || ''),
      JSON.stringify(c.phone || ''),
      JSON.stringify(c.email || ''),
      JSON.stringify(c.address || ''),
      c.total_purchases || 0,
      c.visit_count || 0,
      tier(c).label,
      c.loyalty_points || 0,
      c.is_active ? 'Active' : 'Inactive',
      c.created_at || '',
    ].join(','))
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `customers-${new Date().toISOString().slice(0,10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}

// ── Helpers ───────────────────────────────────────────────────────────────
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['indigo', 'teal', 'deep-purple', 'orange', 'cyan', 'green', 'blue', 'pink', 'amber', 'light-blue']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}

onMounted(load)

watch(() => branchStore.currentBranchId, () => {
  load()
})
</script>

<style scoped>
.crm-list-shell { max-width: 1500px; margin: 0 auto; }

/* ═══ Stat cards — match sales-orders pattern with left accent border ═══ */
.crm-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative;
  overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.crm-stat::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: rgb(var(--v-theme-primary));
}
.crm-stat-total::before { background: rgb(var(--v-theme-primary)); }
.crm-stat-revenue::before { background: rgb(var(--v-theme-success)); }
.crm-stat-points::before { background: rgb(var(--v-theme-warning)); }
.crm-stat-vip::before { background: rgb(var(--v-theme-info)); }
.crm-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

/* ═══ Filter bar ═══ */
.crm-filter-bar { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

/* ═══ Table card ═══ */
.crm-table-card {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  overflow: hidden;
}
.crm-data-table :deep(tbody tr) { cursor: pointer; }
.crm-data-table :deep(tbody tr:hover) { background: rgba(99, 102, 241, 0.05); }

/* ═══ Spend bar in table ═══ */
.crm-spend-bar-wrap {
  height: 3px;
  border-radius: 2px;
  background: rgba(0,0,0,0.06);
  margin-top: 4px;
  overflow: hidden;
}
.crm-spend-bar {
  height: 100%;
  border-radius: 2px;
  transition: width 0.4s ease;
}

/* ═══ Status dots ═══ */
.crm-status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
  flex-shrink: 0;
}
.crm-dot-active {
  background: #4CAF50;
  box-shadow: 0 0 6px rgba(76, 175, 80, 0.4);
}
.crm-dot-inactive {
  background: #BDBDBD;
}

/* ═══ Tier chip ═══ */
.crm-tier-chip { font-weight: 600; }

/* ═══ Table bottom row ═══ */
.crm-table-bottom { border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); }

/* ═══ Dialog header ═══ */
.crm-dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
}
.crm-dialog { overflow: hidden; }

/* ═══ Detail drawer ═══ */
.crm-detail-drawer {
  border-radius: 16px 0 0 16px !important;
}
.crm-profile-header {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(63, 81, 181, 0.04));
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.crm-stat-box {
  background: rgba(0, 0, 0, 0.03);
  border-radius: 12px;
  padding: 12px 14px;
}
.crm-notes-text {
  white-space: pre-wrap;
  word-break: break-word;
  background: rgba(0,0,0,0.03);
  padding: 10px 12px;
  border-radius: 10px;
  border-left: 3px solid rgba(var(--v-theme-primary), 0.5);
}
.crm-tx-item {
  border-radius: 10px;
  margin-bottom: 4px;
  transition: background 0.15s;
}
.crm-tx-item:hover { background: rgba(0, 0, 0, 0.04); }

.crm-avatar { border-radius: 10px; }

.font-mono { font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace; }
</style>
