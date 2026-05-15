<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="orange-lighten-5" size="48" class="mr-3">
          <v-icon color="orange-darken-2" size="28">mdi-bell-alert</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Stock Alerts &amp; Notifications</h1>
          <div class="text-body-2 text-medium-emphasis">
            Monitor stock levels, expiry dates &amp; system notifications
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="loadAll">{{ $t('common.refresh') }}</v-btn>
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-radar"
               class="text-none" :loading="scanning" @click="runScan">Scan Inventory</v-btn>
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-check-all"
               class="text-none" :disabled="!unreadCount" :loading="saving"
               @click="markAllRead">Mark all read</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3" lg="2">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card" :class="{ 'kpi-active': k.value > 0 }"
                style="cursor:pointer" @click="k.action">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-tabs v-model="tab" bg-color="transparent" class="mb-3">
      <v-tab value="stock" prepend-icon="mdi-package-variant-closed">
        Stock Alerts
        <v-badge v-if="stockAlertCount" :content="stockAlertCount" color="error" inline class="ml-1" />
      </v-tab>
      <v-tab value="expiry" prepend-icon="mdi-calendar-clock">
        Expiry Alerts
        <v-badge v-if="expiringItems.length" :content="expiringItems.length" color="warning" inline class="ml-1" />
      </v-tab>
      <v-tab value="notifications" prepend-icon="mdi-bell">
        Notifications
        <v-badge v-if="unreadCount" :content="unreadCount" color="info" inline class="ml-1" />
      </v-tab>
    </v-tabs>

    <!-- ─── STOCK ALERTS TAB ───────────────────────────────── -->
    <v-window v-model="tab">
      <v-window-item value="stock">
        <!-- Filters -->
        <v-card flat rounded="xl" border class="pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="5">
              <v-text-field v-model="stockSearch" prepend-inner-icon="mdi-magnify"
                            placeholder="Search by item name…"
                            density="comfortable" variant="solo-filled" flat hide-details clearable />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="stockLevel" :items="stockLevelItems" label="Stock Level"
                        density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="stockSort" :items="stockSortItems" label="Sort by"
                        density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="2" class="text-right">
              <v-chip color="error" variant="tonal">{{ filteredStock.length }} items</v-chip>
            </v-col>
          </v-row>
        </v-card>

        <!-- Stock items table -->
        <v-card flat rounded="xl" border>
          <v-data-table
            :headers="stockHeaders"
            :items="filteredStock"
            :loading="stockLoading"
            density="comfortable"
            :items-per-page="20"
            class="stock-table"
          >
            <template #item.medication_name="{ item }">
              <div class="d-flex align-center">
                <v-avatar :color="stockStatusColor(item)" size="32" class="mr-2" variant="tonal">
                  <v-icon size="16">{{ stockStatusIcon(item) }}</v-icon>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.medication_name }}</div>
                  <div v-if="item.abbreviation" class="text-caption text-medium-emphasis">
                    {{ item.abbreviation }}
                  </div>
                </div>
              </div>
            </template>
            <template #item.total_quantity="{ item }">
              <v-chip :color="stockStatusColor(item)" variant="tonal" size="small" class="font-weight-bold">
                {{ item.total_quantity }}
              </v-chip>
            </template>
            <template #item.reorder_level="{ item }">
              {{ item.reorder_level }}
            </template>
            <template #item.reorder_quantity="{ item }">
              {{ item.reorder_quantity }}
            </template>
            <template #item.status="{ item }">
              <v-chip :color="stockStatusColor(item)" size="small" variant="flat">
                <v-icon start size="14">{{ stockStatusIcon(item) }}</v-icon>
                {{ stockStatusLabel(item) }}
              </v-chip>
            </template>
            <template #item.deficit="{ item }">
              <span v-if="item.total_quantity < item.reorder_level" class="text-error font-weight-bold">
                -{{ item.reorder_level - item.total_quantity }}
              </span>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.category_name="{ item }">
              {{ item.category_name || '—' }}
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-cart-plus" variant="text" size="small" color="primary"
                     :to="`/pharmacy/purchase-orders/new?stock=${item.id}`"
                     title="Create purchase order" />
            </template>
            <template #no-data>
              <EmptyState icon="mdi-check-circle-outline" title="All stocked up"
                          message="No low stock or out of stock items." />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- ─── EXPIRY ALERTS TAB ──────────────────────────────── -->
      <v-window-item value="expiry">
        <v-card flat rounded="xl" border class="pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="4">
              <v-text-field v-model="expirySearch" prepend-inner-icon="mdi-magnify"
                            placeholder="Search by item or batch…"
                            density="comfortable" variant="solo-filled" flat hide-details clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="expiryDays" :items="expiryDayItems" label="Expiry window"
                        density="comfortable" variant="outlined" hide-details
                        @update:model-value="onExpiryDaysChange" />
            </v-col>
            <v-col v-if="expiryDays === 'custom'" cols="6" md="2">
              <v-text-field v-model="expiryCustomStart" label="From" type="date"
                            density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col v-if="expiryDays === 'custom'" cols="6" md="2">
              <v-text-field v-model="expiryCustomEnd" label="To" type="date"
                            density="comfortable" variant="outlined" hide-details>
                <template #append-inner>
                  <v-btn icon="mdi-check" size="x-small" variant="text" color="primary"
                         :disabled="!expiryCustomStart || !expiryCustomEnd"
                         @click="loadExpiring" />
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="6" :md="expiryDays === 'custom' ? 1 : 2">
              <v-select v-model="expiryStatus" :items="expiryStatusItems" label="Status"
                        density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col cols="12" md="1" class="text-right">
              <v-chip color="warning" variant="tonal">{{ filteredExpiry.length }}</v-chip>
            </v-col>
          </v-row>
        </v-card>

        <v-card flat rounded="xl" border>
          <v-data-table
            :headers="expiryHeaders"
            :items="filteredExpiry"
            :loading="expiryLoading"
            density="comfortable"
            :items-per-page="20"
          >
            <template #item.stock_name="{ item }">
              <div class="font-weight-medium">{{ item.stock_name }}</div>
            </template>
            <template #item.batch_number="{ item }">
              <code class="text-caption">{{ item.batch_number || '—' }}</code>
            </template>
            <template #item.quantity_remaining="{ item }">
              {{ item.quantity_remaining }}
            </template>
            <template #item.expiry_date="{ item }">
              <span :class="expiryDateClass(item)">{{ item.expiry_date }}</span>
            </template>
            <template #item.days_left="{ item }">
              <v-chip :color="item.days_left <= 0 ? 'error' : item.days_left <= 7 ? 'warning' : 'info'"
                      size="small" variant="flat">
                {{ item.days_left <= 0 ? 'EXPIRED' : item.days_left + 'd left' }}
              </v-chip>
            </template>
            <template #no-data>
              <EmptyState icon="mdi-calendar-check" title="No expiry concerns"
                          message="No items expiring within the selected window." />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- ─── NOTIFICATIONS TAB ──────────────────────────────── -->
      <v-window-item value="notifications">
        <v-card flat rounded="xl" border class="pa-3 mb-3">
          <v-row dense align="center">
            <v-col cols="12" md="3">
              <v-text-field v-model="notifSearch" prepend-inner-icon="mdi-magnify"
                            placeholder="Search by title or message…"
                            density="comfortable" variant="solo-filled" flat hide-details clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="typeFilter" :items="typeItems" label="Type"
                        density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-select v-model="readFilter" :items="readItems" label="Status"
                        density="comfortable" variant="outlined" hide-details />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model="notifDateFrom" label="From" type="date"
                            density="comfortable" variant="outlined" hide-details clearable />
            </v-col>
            <v-col cols="6" md="2">
              <v-text-field v-model="notifDateTo" label="To" type="date"
                            density="comfortable" variant="outlined" hide-details clearable />
            </v-col>
            <v-col cols="12" md="1" class="text-right">
              <v-chip color="primary" variant="tonal">{{ filteredNotifs.length }}</v-chip>
            </v-col>
          </v-row>
        </v-card>

        <v-card flat rounded="xl" border>
          <v-list lines="three">
            <template v-if="notifsLoading">
              <v-list-item v-for="i in 4" :key="i">
                <v-skeleton-loader type="list-item-three-line" />
              </v-list-item>
            </template>
            <template v-else-if="filteredNotifs.length">
              <template v-for="n in filteredNotifs" :key="n.id">
                <v-list-item :class="!n.is_read ? 'unread-item' : ''">
                  <template #prepend>
                    <v-avatar :color="typeColor(n.type)" size="40">
                      <v-icon color="white">{{ typeIcon(n.type) }}</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="d-flex align-center">
                    <span :class="!n.is_read ? 'font-weight-bold' : ''">{{ n.title }}</span>
                    <v-chip v-if="!n.is_read" size="x-small" color="primary" class="ml-2">New</v-chip>
                    <v-chip size="x-small" :color="typeColor(n.type)" variant="tonal"
                            class="ml-2 text-capitalize">
                      {{ (n.type || '').replace('_', ' ') }}
                    </v-chip>
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-body-2 mt-1">{{ n.message }}</v-list-item-subtitle>
                  <v-list-item-subtitle class="text-caption text-medium-emphasis mt-1">
                    {{ formatDateTime(n.created_at) }}
                  </v-list-item-subtitle>
                  <template #append>
                    <v-btn v-if="!n.is_read" icon="mdi-check" variant="text" size="small"
                           color="success" @click="markRead(n)" />
                  </template>
                </v-list-item>
                <v-divider />
              </template>
            </template>
            <EmptyState v-else icon="mdi-bell-off-outline" title="No alerts"
                        message="You're all caught up." />
          </v-list>
        </v-card>
      </v-window-item>
    </v-window>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const loading = ref(false)

// ─── Stock Alerts ──────────────────────────────────────
const stockItems = ref([])
const stockLoading = ref(false)
const stockSearch = ref('')
const stockLevel = ref('all')
const stockSort = ref('qty_asc')

const stockLevelItems = [
  { title: 'All alerts', value: 'all' },
  { title: 'Out of stock', value: 'out' },
  { title: 'Low stock', value: 'low' },
]
const stockSortItems = [
  { title: 'Qty (low first)', value: 'qty_asc' },
  { title: 'Qty (high first)', value: 'qty_desc' },
  { title: 'Name A-Z', value: 'name_asc' },
  { title: 'Deficit (worst first)', value: 'deficit' },
]
const stockHeaders = [
  { title: 'Item', key: 'medication_name', sortable: true },
  { title: 'Qty on Hand', key: 'total_quantity', align: 'center', sortable: true },
  { title: 'Reorder Level', key: 'reorder_level', align: 'center', sortable: true },
  { title: 'Deficit', key: 'deficit', align: 'center', sortable: false },
  { title: 'Reorder Qty', key: 'reorder_quantity', align: 'center' },
  { title: 'Category', key: 'category_name' },
  { title: 'Status', key: 'status', sortable: false },
  { title: '', key: 'actions', sortable: false, width: 48 },
]

async function loadLowStock() {
  stockLoading.value = true
  try {
    const { data } = await $api.get('/inventory/stocks/low_stock/')
    stockItems.value = (data?.results || data || []).map(s => ({
      ...s,
      total_quantity: s.total_quantity ?? 0,
      reorder_level: s.reorder_level ?? 10,
      reorder_quantity: s.reorder_quantity ?? 50,
    }))
  } catch { notify('Failed to load stock alerts', 'error') }
  finally { stockLoading.value = false }
}

const filteredStock = computed(() => {
  let list = [...stockItems.value]
  if (stockLevel.value === 'out') list = list.filter(s => s.total_quantity === 0)
  else if (stockLevel.value === 'low') list = list.filter(s => s.total_quantity > 0)

  const q = (stockSearch.value || '').toLowerCase().trim()
  if (q) list = list.filter(s => (s.medication_name || '').toLowerCase().includes(q))

  if (stockSort.value === 'qty_asc') list.sort((a, b) => a.total_quantity - b.total_quantity)
  else if (stockSort.value === 'qty_desc') list.sort((a, b) => b.total_quantity - a.total_quantity)
  else if (stockSort.value === 'name_asc') list.sort((a, b) => (a.medication_name || '').localeCompare(b.medication_name || ''))
  else if (stockSort.value === 'deficit') list.sort((a, b) => (a.total_quantity - a.reorder_level) - (b.total_quantity - b.reorder_level))
  return list
})

const outOfStockCount = computed(() => stockItems.value.filter(s => s.total_quantity === 0).length)
const lowStockCount = computed(() => stockItems.value.filter(s => s.total_quantity > 0).length)
const stockAlertCount = computed(() => stockItems.value.length)

function stockStatusColor(item) {
  if (item.total_quantity === 0) return 'error'
  if (item.total_quantity <= item.reorder_level) return 'warning'
  return 'success'
}
function stockStatusIcon(item) {
  if (item.total_quantity === 0) return 'mdi-alert-circle'
  if (item.total_quantity <= item.reorder_level) return 'mdi-alert'
  return 'mdi-check-circle'
}
function stockStatusLabel(item) {
  if (item.total_quantity === 0) return 'Out of Stock'
  if (item.total_quantity <= item.reorder_level) return 'Low Stock'
  return 'OK'
}

// ─── Expiry Alerts ─────────────────────────────────────
const expiringItems = ref([])
const expiryLoading = ref(false)
const expirySearch = ref('')
const expiryDays = ref(30)
const expiryStatus = ref('all')

const expiryDayItems = [
  { title: '7 days', value: 7 },
  { title: '14 days', value: 14 },
  { title: '30 days', value: 30 },
  { title: '60 days', value: 60 },
  { title: '90 days', value: 90 },
  { title: 'Custom range', value: 'custom' },
]
const expiryCustomStart = ref('')
const expiryCustomEnd = ref('')

function onExpiryDaysChange(val) {
  if (val !== 'custom') loadExpiring()
}
const expiryStatusItems = [
  { title: 'All', value: 'all' },
  { title: 'Expired', value: 'expired' },
  { title: 'Expiring soon', value: 'expiring' },
]
const expiryHeaders = [
  { title: 'Item', key: 'stock_name', sortable: true },
  { title: 'Batch #', key: 'batch_number' },
  { title: 'Qty Remaining', key: 'quantity_remaining', align: 'center' },
  { title: 'Expiry Date', key: 'expiry_date', sortable: true },
  { title: 'Status', key: 'days_left', align: 'center', sortable: true },
]

async function loadExpiring() {
  expiryLoading.value = true
  try {
    const params = {}
    if (expiryDays.value === 'custom') {
      if (expiryCustomStart.value) params.expiry_from = expiryCustomStart.value
      if (expiryCustomEnd.value) params.expiry_to = expiryCustomEnd.value
      // Fetch with a large window so the backend returns all; we filter client-side by date
      params.days = 3650
    } else {
      params.days = expiryDays.value
    }
    const { data } = await $api.get('/inventory/stocks/expiring_soon/', { params })
    let items = (data?.results || data || []).map(b => ({
      ...b,
      days_left: b.days_left ?? Math.ceil((new Date(b.expiry_date) - new Date()) / 86400000),
    }))
    // Client-side date range filter for custom mode
    if (expiryDays.value === 'custom') {
      if (expiryCustomStart.value) items = items.filter(b => b.expiry_date >= expiryCustomStart.value)
      if (expiryCustomEnd.value) items = items.filter(b => b.expiry_date <= expiryCustomEnd.value)
    }
    expiringItems.value = items
  } catch { notify('Failed to load expiry alerts', 'error') }
  finally { expiryLoading.value = false }
}

const filteredExpiry = computed(() => {
  let list = [...expiringItems.value]
  if (expiryStatus.value === 'expired') list = list.filter(b => b.days_left <= 0)
  else if (expiryStatus.value === 'expiring') list = list.filter(b => b.days_left > 0)

  const q = (expirySearch.value || '').toLowerCase().trim()
  if (q) {
    list = list.filter(b =>
      (b.stock_name || '').toLowerCase().includes(q) ||
      (b.batch_number || '').toLowerCase().includes(q)
    )
  }
  return list
})

function expiryDateClass(item) {
  if (item.days_left <= 0) return 'text-error font-weight-bold'
  if (item.days_left <= 7) return 'text-warning font-weight-bold'
  return ''
}

// ─── Notifications ─────────────────────────────────────
const notifications = ref([])
const notifsLoading = ref(false)
const notifSearch = ref('')
const typeFilter = ref('all')
const readFilter = ref('all')
const notifDateFrom = ref('')
const notifDateTo = ref('')

const typeOptions = ['system', 'stock_alert', 'appointment', 'lab_result', 'prescription', 'billing']
const typeItems = [
  { title: 'All types', value: 'all' },
  ...typeOptions.map(v => ({ title: v.replace(/_/g, ' '), value: v }))
]
const readItems = [
  { title: 'All', value: 'all' },
  { title: 'Unread', value: 'unread' },
  { title: 'Read', value: 'read' },
]

async function loadNotifications() {
  notifsLoading.value = true
  try {
    const { data } = await $api.get('/notifications/', { params: { page_size: 200 } })
    notifications.value = data?.results || data || []
  } catch { notify('Failed to load notifications', 'error') }
  finally { notifsLoading.value = false }
}

const filteredNotifs = computed(() => {
  const q = (notifSearch.value || '').toLowerCase().trim()
  return notifications.value.filter(n => {
    if (typeFilter.value !== 'all' && n.type !== typeFilter.value) return false
    if (readFilter.value === 'unread' && n.is_read) return false
    if (readFilter.value === 'read' && !n.is_read) return false
    const d = (n.created_at || '').slice(0, 10)
    if (notifDateFrom.value && d < notifDateFrom.value) return false
    if (notifDateTo.value && d > notifDateTo.value) return false
    if (!q) return true
    return (n.title || '').toLowerCase().includes(q)
        || (n.message || '').toLowerCase().includes(q)
  })
})

const unreadCount = computed(() => notifications.value.filter(n => !n.is_read).length)

function typeColor(t) {
  return ({
    appointment: 'indigo', lab_result: 'purple', prescription: 'teal',
    home_collection: 'cyan', billing: 'amber-darken-2', system: 'grey',
    stock_alert: 'error'
  })[t] || 'grey'
}
function typeIcon(t) {
  return ({
    appointment: 'mdi-calendar', lab_result: 'mdi-microscope', prescription: 'mdi-pill',
    home_collection: 'mdi-truck', billing: 'mdi-receipt', system: 'mdi-cog',
    stock_alert: 'mdi-package-variant-closed'
  })[t] || 'mdi-bell'
}

async function markRead(n) {
  try {
    await $api.post(`/notifications/${n.id}/mark_read/`)
    n.is_read = true
  } catch (e) { notify(extractError(e) || 'Failed', 'error') }
}
async function markAllRead() {
  saving.value = true
  try {
    await $api.post('/notifications/mark_all_read/')
    notifications.value.forEach(n => (n.is_read = true))
    notify('All marked as read')
  } catch (e) { notify(extractError(e) || 'Failed', 'error') }
  finally { saving.value = false }
}

// ─── Scan & Common ─────────────────────────────────────
const saving = ref(false)
const scanning = ref(false)

async function runScan() {
  scanning.value = true
  try {
    const r = await $api.post('/notifications/scan-inventory/', { days: expiryDays.value })
    notify(`Scan complete: ${r.data?.output || 'no new alerts'}`, 'success')
    await loadAll()
  } catch { notify('Scan failed', 'error') }
  finally { scanning.value = false }
}

async function loadAll() {
  loading.value = true
  await Promise.all([loadLowStock(), loadExpiring(), loadNotifications()])
  loading.value = false
}

const tab = ref('stock')
const todayCount = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return notifications.value.filter(n => (n.created_at || '').slice(0, 10) === today).length
})

const kpiTiles = computed(() => [
  { label: 'Out of Stock', value: outOfStockCount.value, icon: 'mdi-alert-circle', color: 'error',
    sub: outOfStockCount.value ? 'Need immediate restock' : 'All items stocked',
    action: () => { tab.value = 'stock'; stockLevel.value = 'out' } },
  { label: 'Low Stock', value: lowStockCount.value, icon: 'mdi-alert', color: 'warning',
    sub: lowStockCount.value ? 'Below reorder level' : 'Levels OK',
    action: () => { tab.value = 'stock'; stockLevel.value = 'low' } },
  { label: 'Expiring Soon', value: expiringItems.value.filter(b => b.days_left > 0).length,
    icon: 'mdi-calendar-clock', color: 'amber-darken-2',
    sub: `Within ${expiryDays.value === 'custom' ? 'custom range' : expiryDays.value + ' days'}`,
    action: () => { tab.value = 'expiry'; expiryStatus.value = 'expiring' } },
  { label: 'Expired', value: expiringItems.value.filter(b => b.days_left <= 0).length,
    icon: 'mdi-calendar-remove', color: 'error',
    action: () => { tab.value = 'expiry'; expiryStatus.value = 'expired' } },
  { label: 'Unread Notifs', value: unreadCount.value, icon: 'mdi-bell-badge', color: 'info',
    action: () => { tab.value = 'notifications'; readFilter.value = 'unread' } },
  { label: "Today's Alerts", value: todayCount.value, icon: 'mdi-calendar-today', color: 'grey',
    action: () => { tab.value = 'notifications'; const t = new Date().toISOString().slice(0,10); notifDateFrom.value = t; notifDateTo.value = t; readFilter.value = 'all' } },
])

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

onMounted(loadAll)
</script>

<style scoped>
.kpi-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
}
.kpi-active { border-color: rgba(var(--v-theme-primary), 0.3) !important; }
.unread-item { background: rgba(249, 115, 22, 0.04); }
.stock-table :deep(tr:hover) { background: rgba(var(--v-theme-primary), 0.04); }
</style>
