<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="pink-darken-3" size="32">mdi-account-multiple</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Customers</div>
              <div class="text-body-2" style="opacity:0.9">
                Track buyers, lifetime spend &amp; visit history. Phones are unique.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-pink-darken-3"
                 prepend-icon="mdi-account-plus" @click="openDialog()">New Customer</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-refresh"
                 :loading="loading" @click="load">Refresh</v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="stat-card pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-3" border>
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name, phone or email…" density="comfortable"
                        hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="filterStatus" :items="statusItems" label="Status"
                    density="comfortable" hide-details variant="outlined" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortItems" label="Sort by"
                    density="comfortable" hide-details variant="outlined"
                    prepend-inner-icon="mdi-sort" />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" prepend-icon="mdi-download" @click="exportCsv">CSV</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table
        :headers="headers"
        :items="filteredItems"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        density="comfortable"
        hover
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="avatarColor(item.name)" size="34" class="mr-3">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.name) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.email || '—' }}</div>
            </div>
          </div>
        </template>
        <template #item.phone="{ item }">
          <span class="font-mono">{{ item.phone || '—' }}</span>
        </template>
        <template #item.total_purchases="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.total_purchases || 0) }}</span>
        </template>
        <template #item.visit_count="{ item }">
          <v-chip size="x-small" color="indigo" variant="tonal">
            {{ item.visit_count || 0 }} visits
          </v-chip>
        </template>
        <template #item.tier="{ item }">
          <v-chip :color="tier(item).color" size="x-small" variant="flat" class="text-white">
            <v-icon start size="14">{{ tier(item).icon }}</v-icon>{{ tier(item).label }}
          </v-chip>
        </template>
        <template #item.is_active="{ item }">
          <v-chip :color="item.is_active ? 'success' : 'grey'" size="small" variant="tonal">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.created_at="{ item }">
          <span class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</span>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-eye" variant="text" size="small" @click.stop="openDetail(item)" />
          <v-btn icon="mdi-pencil" variant="text" size="small" @click.stop="openDialog(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click.stop="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-account-search" title="No customers found"
                      message="Add your first customer or wait for POS sales to record one automatically." />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="dialog" max-width="600" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="pink" class="mr-2">mdi-account-multiple</v-icon>
          {{ editing ? 'Edit Customer' : 'New Customer' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
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
            <v-col cols="12">
              <v-text-field v-model="form.email" label="Email" variant="outlined"
                            density="comfortable" prepend-inner-icon="mdi-email"
                            :error-messages="formErrors.email" />
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
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ editing ? 'Save changes' : 'Create customer' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail drawer -->
    <v-dialog v-model="detailDialog" max-width="640" scrollable>
      <v-card v-if="selected" rounded="xl">
        <v-card-title class="d-flex align-center pa-4 detail-header">
          <v-avatar :color="avatarColor(selected.name)" size="56" class="mr-3 elevation-2">
            <span class="text-h6 font-weight-bold text-white">{{ initials(selected.name) }}</span>
          </v-avatar>
          <div class="flex-grow-1 min-width-0">
            <div class="text-h6 font-weight-bold text-truncate">{{ selected.name }}</div>
            <div class="text-caption text-medium-emphasis">
              <v-icon size="14">mdi-phone</v-icon> {{ selected.phone || '—' }}
              <span v-if="selected.email"> · <v-icon size="14">mdi-email</v-icon> {{ selected.email }}</span>
            </div>
          </div>
          <v-chip :color="tier(selected).color" size="small" variant="flat" class="text-white">
            <v-icon start size="16">{{ tier(selected).icon }}</v-icon>{{ tier(selected).label }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense class="mb-3">
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Total spent</div>
              <div class="text-h5 font-weight-bold text-success">
                {{ formatMoney(selected.total_purchases || 0) }}
              </div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Visits</div>
              <div class="text-h5 font-weight-bold text-indigo">{{ selected.visit_count || 0 }}</div>
            </v-col>
          </v-row>

          <v-divider class="mb-3" />

          <div v-if="selected.address" class="mb-3">
            <div class="text-caption text-medium-emphasis">Address</div>
            <div class="text-body-2">{{ selected.address }}</div>
          </div>
          <div v-if="selected.notes" class="mb-3">
            <div class="text-caption text-medium-emphasis">Notes</div>
            <div class="text-body-2">{{ selected.notes }}</div>
          </div>
          <div class="d-flex text-caption text-medium-emphasis">
            <div class="mr-4"><v-icon size="14">mdi-calendar-plus</v-icon> Joined {{ formatDate(selected.created_at) }}</div>
            <div><v-icon size="14">mdi-update</v-icon> Updated {{ formatDate(selected.updated_at) }}</div>
          </div>

          <!-- Recent transactions -->
          <v-divider class="my-3" />
          <div class="d-flex align-center mb-2">
            <v-icon color="primary" class="mr-2">mdi-receipt-text</v-icon>
            <div class="text-subtitle-2 font-weight-medium">Recent transactions</div>
          </div>
          <div v-if="txLoading" class="text-center py-4">
            <v-progress-circular indeterminate size="24" color="primary" />
          </div>
          <div v-else-if="!recentTx.length" class="text-caption text-medium-emphasis py-2">
            No transactions yet for this customer.
          </div>
          <v-list v-else density="compact" class="pa-0">
            <v-list-item v-for="t in recentTx" :key="t.id" class="px-0">
              <template #prepend>
                <v-avatar size="32" color="primary" variant="tonal">
                  <v-icon size="16">mdi-cart</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="text-body-2">
                {{ t.transaction_number }}
              </v-list-item-title>
              <v-list-item-subtitle class="text-caption">
                {{ formatDateTime(t.created_at) }} · {{ t.payment_method }}
              </v-list-item-subtitle>
              <template #append>
                <span class="font-weight-bold">{{ formatMoney(t.total) }}</span>
              </template>
            </v-list-item>
          </v-list>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" color="error" prepend-icon="mdi-delete"
                 @click="confirmDelete(selected); detailDialog = false">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" variant="flat" prepend-icon="mdi-pencil"
                 @click="openDialog(selected); detailDialog = false">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete customer?</v-card-title>
        <v-card-text>
          <strong>{{ target?.name }}</strong> will be removed. Past transactions remain but lose the customer link.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()

const items = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const filterStatus = ref('all')
const sortBy = ref('name')

const statusItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]
const sortItems = [
  { title: 'Name (A→Z)', value: 'name' },
  { title: 'Top spenders', value: 'spend' },
  { title: 'Most visits', value: 'visits' },
  { title: 'Newest', value: 'newest' },
]

const headers = [
  { title: 'Customer', key: 'name', sortable: true },
  { title: 'Phone', key: 'phone', sortable: false },
  { title: 'Total spent', key: 'total_purchases', sortable: true, align: 'end' },
  { title: 'Visits', key: 'visit_count', sortable: true, align: 'start' },
  { title: 'Tier', key: 'tier', sortable: false },
  { title: 'Status', key: 'is_active', sortable: true },
  { title: 'Joined', key: 'created_at', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 },
]

const dialog = ref(false)
const editing = ref(null)
const form = reactive({
  name: '', phone: '', email: '', address: '', notes: '', is_active: true,
})
const formErrors = reactive({})

const detailDialog = ref(false)
const selected = ref(null)
const recentTx = ref([])
const txLoading = ref(false)

const deleteDialog = ref(false)
const target = ref(null)

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let rows = items.value.filter(c => {
    if (filterStatus.value === 'active' && !c.is_active) return false
    if (filterStatus.value === 'inactive' && c.is_active) return false
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

const kpis = computed(() => {
  const total = items.value.length
  const active = items.value.filter(c => c.is_active).length
  const totalSpend = items.value.reduce((s, c) => s + Number(c.total_purchases || 0), 0)
  const vip = items.value.filter(c => Number(c.total_purchases || 0) >= 50000).length
  return [
    { label: 'Total customers', value: total, icon: 'mdi-account-multiple', color: 'pink' },
    { label: 'Active', value: active, icon: 'mdi-check-circle', color: 'success' },
    { label: 'Lifetime revenue', value: formatMoney(totalSpend), icon: 'mdi-cash-multiple', color: 'success' },
    { label: 'VIPs (≥50K)', value: vip, icon: 'mdi-crown', color: 'amber' },
  ]
})

function tier(c) {
  const v = Number(c?.total_purchases || 0)
  if (v >= 100000) return { label: 'Platinum', color: 'deep-purple', icon: 'mdi-crown' }
  if (v >= 50000) return { label: 'Gold', color: 'amber-darken-2', icon: 'mdi-medal' }
  if (v >= 10000) return { label: 'Silver', color: 'blue-grey', icon: 'mdi-shield-star' }
  if (v > 0) return { label: 'Bronze', color: 'orange-darken-2', icon: 'mdi-account-star' }
  return { label: 'New', color: 'grey', icon: 'mdi-sparkles' }
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/pos/customers/', { params: { ordering: 'name', page_size: 500 } })
    items.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load customers', 'error')
    items.value = []
  } finally {
    loading.value = false
  }
}

function openDialog(c = null) {
  editing.value = c
  Object.assign(form, c ? {
    name: c.name, phone: c.phone || '', email: c.email || '',
    address: c.address || '', notes: c.notes || '', is_active: c.is_active,
  } : { name: '', phone: '', email: '', address: '', notes: '', is_active: true })
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

async function openDetail(c) {
  selected.value = c
  detailDialog.value = true
  recentTx.value = []
  txLoading.value = true
  try {
    const { data } = await $api.get('/pos/transactions/', {
      params: { customer: c.id, ordering: '-created_at', page_size: 10 },
    })
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

function exportCsv() {
  const rows = filteredItems.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const lines = ['Name,Phone,Email,Address,Total spent,Visits,Tier,Status,Joined']
  rows.forEach(c => {
    lines.push([
      JSON.stringify(c.name || ''),
      JSON.stringify(c.phone || ''),
      JSON.stringify(c.email || ''),
      JSON.stringify(c.address || ''),
      c.total_purchases || 0,
      c.visit_count || 0,
      tier(c).label,
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
  const palette = ['pink', 'indigo', 'teal', 'deep-purple', 'orange', 'cyan', 'green', 'blue']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}

onMounted(load)
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #db2777 0%, #ec4899 50%, #f97316 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(219, 39, 119, 0.25);
}
.stat-card {
  background: rgba(255, 255, 255, 0.95);
  color: rgba(0, 0, 0, 0.85);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0,0,0,0.12); }
.detail-header {
  background: linear-gradient(135deg, rgba(236, 72, 153, 0.06), rgba(249, 115, 22, 0.04));
}
.font-mono { font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace; }
</style>
