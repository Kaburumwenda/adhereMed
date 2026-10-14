<template>
  <v-container fluid class="pa-4 pa-md-6 cust-detail-shell">
    <!-- ── Header ─────────────────────────────────────────────────── -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
             @click="navigateTo(backPath)">Back</v-btn>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
             @click="navigateTo(editPath)">Edit</v-btn>
      <v-btn color="error" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-delete"
             @click="deleteDialog = true">Delete</v-btn>
    </div>

    <!-- ── Loading ────────────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <div v-else-if="!customer" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-account-question</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Customer not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3" @click="navigateTo(backPath)">
        Back to Customers
      </v-btn>
    </div>

    <template v-else>
      <!-- ═══ Identity banner ═══ -->
      <v-card rounded="lg" class="cust-banner pa-5 mb-4" border>
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="avatarColor(customer.name)" size="72" class="mr-2" variant="tonal">
            <span class="text-h5 font-weight-bold">{{ initials(customer.name) }}</span>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 200px;">
            <div class="text-h5 font-weight-bold">{{ customer.name }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis mt-1">
              <span v-if="customer.phone" class="d-flex align-center">
                <v-icon size="16" class="mr-1">mdi-phone</v-icon>{{ customer.phone }}
              </span>
              <span v-if="customer.email" class="d-flex align-center">
                <v-icon size="16" class="mr-1">mdi-email</v-icon>{{ customer.email }}
              </span>
            </div>
          </div>
          <div class="d-flex flex-wrap ga-2">
            <v-chip :color="tierMeta(customer.loyalty_tier || tier(customer).key).color" size="small" variant="tonal">
              <v-icon start size="16">{{ tierMeta(customer.loyalty_tier || tier(customer).key).icon }}</v-icon>
              {{ tierMeta(customer.loyalty_tier || tier(customer).key).label }}
            </v-chip>
            <v-chip :color="customer.is_active ? 'success' : 'grey'" size="small" variant="tonal">
              <v-icon start size="14">{{ customer.is_active ? 'mdi-check-circle' : 'mdi-circle-off-outline' }}</v-icon>
              {{ customer.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>
        </div>
      </v-card>

      <!-- ═══ Stat cards ═══ -->
      <v-row dense class="mb-4">
        <v-col cols="6" md="3">
          <v-card rounded="lg" class="pa-4 cust-stat crm-stat-total" border>
            <div class="d-flex align-center mb-2">
              <v-icon color="success" class="mr-2">mdi-cash-multiple</v-icon>
              <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">Total Spent</div>
            </div>
            <div class="text-h5 font-weight-bold text-success">{{ formatMoney(customer.total_purchases || 0) }}</div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" class="pa-4 cust-stat crm-stat-visits" border>
            <div class="d-flex align-center mb-2">
              <v-icon color="indigo" class="mr-2">mdi-store-check-outline</v-icon>
              <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">Visits</div>
            </div>
            <div class="text-h5 font-weight-bold text-indigo">{{ customer.visit_count || 0 }}</div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" class="pa-4 cust-stat crm-stat-points" border>
            <div class="d-flex align-center mb-2">
              <v-icon color="amber" class="mr-2">mdi-star-circle</v-icon>
              <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">Loyalty Points</div>
            </div>
            <div class="text-h5 font-weight-bold text-amber">{{ customer.loyalty_points || 0 }}</div>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card rounded="lg" class="pa-4 cust-stat crm-stat-member" border>
            <div class="d-flex align-center mb-2">
              <v-icon color="primary" class="mr-2">mdi-calendar-account</v-icon>
              <div class="text-caption text-medium-emphasis text-uppercase font-weight-bold">Member Since</div>
            </div>
            <div class="text-h6 font-weight-medium">{{ formatDate(customer.loyalty_joined_at || customer.created_at) }}</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- ═══ Tabs ═══ -->
      <v-card rounded="lg" border>
        <v-tabs v-model="tab" density="comfortable">
          <v-tab value="overview" prepend-icon="mdi-account-details">Overview</v-tab>
          <v-tab value="transactions" prepend-icon="mdi-receipt-text">Transactions</v-tab>
        </v-tabs>
        <v-divider />

        <v-window v-model="tab" class="pa-4">
          <!-- ── Overview tab ───────────────────────────────────────── -->
          <v-window-item value="overview">
            <v-row dense>
              <v-col cols="12" md="6">
                <div class="text-subtitle-2 font-weight-bold mb-3">Contact</div>
                <DetailField label="Phone" :value="customer.phone" />
                <DetailField label="Email" :value="customer.email" />
                <div class="text-subtitle-2 font-weight-bold mb-3 mt-4">Branch</div>
                <v-chip v-if="branchName" size="small" variant="tonal" color="primary">{{ branchName }}</v-chip>
                <span v-else class="text-body-2 text-medium-emphasis">All branches (shared)</span>
              </v-col>
              <v-col cols="12" md="6">
                <div class="text-subtitle-2 font-weight-bold mb-3">Address</div>
                <v-card variant="tonal" rounded="lg" density="compact" class="pa-3 mb-4" v-if="customer.address">
                  <div class="text-body-2 white-space-pre-wrap">{{ customer.address }}</div>
                </v-card>
                <v-alert v-else variant="tonal" color="grey" density="compact">No address recorded.</v-alert>

                <div class="text-subtitle-2 font-weight-bold mb-3">Notes</div>
                <v-card variant="tonal" rounded="lg" density="compact" class="pa-3 cust-notes-box" v-if="customer.notes">
                  <div class="text-body-2 white-space-pre-wrap">{{ customer.notes }}</div>
                </v-card>
                <v-alert v-else variant="tonal" color="grey" density="compact">No notes recorded.</v-alert>
              </v-col>
            </v-row>

            <v-divider class="my-4" />

            <v-row dense>
              <v-col cols="12" md="6">
                <div class="text-subtitle-2 font-weight-bold mb-3">Registration</div>
                <DetailField label="Customer ID" :value="String(customer.id)" :mono="true" />
                <DetailField label="Joined" :value="formatDateTime(customer.created_at)" />
                <DetailField label="Updated" :value="formatDateTime(customer.updated_at)" />
              </v-col>
              <v-col cols="12" md="6">
                <div class="text-subtitle-2 font-weight-bold mb-3">Engagement</div>
                <div class="d-flex flex-wrap ga-2">
                  <v-chip size="small" variant="tonal" color="indigo" prepend-icon="mdi-store-check-outline">
                    {{ customer.visit_count || 0 }} visits
                  </v-chip>
                  <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-cash-multiple">
                    {{ formatMoney(customer.total_purchases || 0) }} spent
                  </v-chip>
                  <v-chip size="small" variant="tonal" color="amber" prepend-icon="mdi-star-circle">
                    {{ customer.loyalty_points || 0 }} points
                  </v-chip>
                </div>
              </v-col>
            </v-row>
          </v-window-item>

          <!-- ── Transactions tab ───────────────────────────────────── -->
          <v-window-item value="transactions">
            <div v-if="txLoading" class="text-center pa-8">
              <v-progress-circular indeterminate color="primary" size="36" />
            </div>
            <div v-else-if="!transactions.length" class="pa-8 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-cart-off</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2">No transactions yet for this customer.</div>
            </div>
            <div v-else>
              <v-expansion-panels v-model="expandedTx" multiple>
                <v-expansion-panel
                  v-for="t in transactions" :key="t.id"
                  rounded="lg" class="tx-panel"
                  :class="{ 'tx-panel-cancelled': t.status === 'cancelled' }"
                >
                  <!-- Panel header (always visible) -->
                  <v-expansion-panel-title class="py-3">
                    <div class="d-flex align-center justify-space-between w-100 ga-3">
                      <div class="d-flex align-center">
                        <v-avatar :color="txStatusColor(t.status)" variant="tonal" rounded size="40" class="mr-3">
                          <v-icon size="20" :color="txStatusColor(t.status)">{{ txStatusIcon(t.status) }}</v-icon>
                        </v-avatar>
                        <div>
                          <div class="text-subtitle-2 font-weight-bold">{{ t.transaction_number }}</div>
                          <div class="text-caption text-medium-emphasis">{{ formatDateTime(t.created_at) }}</div>
                        </div>
                      </div>
                      <div class="d-flex align-center ga-2">
                        <v-chip v-if="t.status && t.status !== 'completed'" size="x-small" variant="tonal"
                                :color="txStatusColor(t.status)" class="text-capitalize">
                          {{ t.status }}
                        </v-chip>
                        <v-chip size="small" variant="tonal" :color="txPaymentColor(t.payment_method)">
                          <v-icon start size="14">{{ txPaymentIcon(t.payment_method) }}</v-icon>
                          {{ txPaymentLabel(t.payment_method) }}
                        </v-chip>
                        <span class="text-h6 font-weight-bold text-success">{{ formatMoney(t.total) }}</span>
                      </div>
                    </div>
                  </v-expansion-panel-title>

                  <!-- Panel content (click to expand) -->
                  <v-expansion-panel-text>
                    <v-divider />

                    <!-- Summary row: subtotal / tax / discount -->
                    <div class="d-flex flex-wrap ga-4 pa-4 pb-2">
                      <div class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Subtotal</div>
                        <div class="text-body-2 font-weight-medium">{{ formatMoney(t.subtotal) }}</div>
                      </div>
                      <div class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Tax</div>
                        <div class="text-body-2 font-weight-medium">{{ formatMoney(t.tax) }}</div>
                      </div>
                      <div v-if="Number(t.discount) > 0" class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Discount</div>
                        <div class="text-body-2 font-weight-medium text-error">-{{ formatMoney(t.discount) }}</div>
                      </div>
                      <div v-if="t.payment_reference" class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Ref</div>
                        <div class="text-body-2 font-weight-medium font-mono">{{ t.payment_reference }}</div>
                      </div>
                      <div v-if="t.cashier_name" class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Cashier</div>
                        <div class="text-body-2 font-weight-medium">{{ t.cashier_name }}</div>
                      </div>
                      <div v-if="t.branch_name" class="d-flex flex-column">
                        <div class="text-caption text-medium-emphasis">Branch</div>
                        <div class="text-body-2 font-weight-medium">{{ t.branch_name }}</div>
                      </div>
                    </div>

                    <!-- Items -->
                    <div v-if="t.items && t.items.length" class="px-4 pb-4">
                      <div class="text-caption text-medium-emphasis mb-2">
                        {{ t.items.length }} item{{ t.items.length === 1 ? '' : 's' }}
                      </div>
                      <v-table density="compact" class="tx-items-table">
                        <thead>
                          <tr>
                            <th class="text-left text-caption text-medium-emphasis">Item</th>
                            <th class="text-left text-caption text-medium-emphasis">Category</th>
                            <th class="text-right text-caption text-medium-emphasis">Qty</th>
                            <th class="text-right text-caption text-medium-emphasis">Unit Price</th>
                            <th class="text-right text-caption text-medium-emphasis">Total</th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr v-for="item in t.items" :key="item.id">
                            <td class="text-body-2 font-weight-medium">{{ item.stock_name || item.medication_name || '—' }}</td>
                            <td class="text-body-2 text-medium-emphasis">{{ item.category_name || '—' }}</td>
                            <td class="text-body-2 text-right">{{ item.quantity }}</td>
                            <td class="text-body-2 text-right">{{ formatMoney(item.unit_price) }}</td>
                            <td class="text-body-2 text-right font-weight-bold">{{ formatMoney(item.total_price) }}</td>
                          </tr>
                        </tbody>
                      </v-table>
                    </div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>
            </div>
          </v-window-item>
        </v-window>
      </v-card>
    </template>

    <!-- ── Delete confirmation ────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <div class="d-flex align-center pa-4 pb-2">
          <v-avatar color="error" variant="tonal" rounded size="40" class="mr-3">
            <v-icon color="error">mdi-delete-alert</v-icon>
          </v-avatar>
          <span class="text-h6 font-weight-bold">Delete customer?</span>
        </div>
        <v-card-text>
          <strong>{{ customer?.name }}</strong> will be removed. Past transactions remain but lose the customer link.
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'

definePageMeta({ layout: 'default' })

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const branchStore = useBranchStore()

const id = computed(() => route.params.id)
const ns = computed(() => route.path.startsWith('/ims') ? '/ims' : route.path.startsWith('/pharmacy') ? '/pharmacy' : '')
const basePath = computed(() => `${ns.value}/customers`)
const backPath = computed(() => basePath.value)
const editPath = computed(() => `${basePath.value}/${id.value}/edit`)

const customer = ref(null)
const loading = ref(true)
const tab = ref('overview')

const transactions = ref([])
const txLoading = ref(false)
const expandedTx = ref([])

const deleteDialog = ref(false)
const deleting = ref(false)

const branchName = computed(() => {
  if (!customer.value?.branch) return ''
  const branches = branchStore.activeBranches || []
  return branches.find(b => b.id === customer.value.branch)?.name || ''
})

// ── Tier metadata ────────────────────────────────────────────────────────
const TIER_MAP = {
  platinum: { label: 'Platinum', color: 'deep-purple', icon: 'mdi-crown' },
  gold:     { label: 'Gold',     color: 'amber-darken-2', icon: 'mdi-medal' },
  silver:   { label: 'Silver',   color: 'blue-grey', icon: 'mdi-shield-star' },
  bronze:   { label: 'Bronze',   color: 'orange-darken-2', icon: 'mdi-account-star' },
}
function tierMeta(key) { return TIER_MAP[key] || { label: key, color: 'grey', icon: 'mdi-account' } }

function tier(c) {
  const v = Number(c?.total_purchases || 0)
  if (v >= 100000) return { key: 'platinum' }
  if (v >= 50000)  return { key: 'gold' }
  if (v >= 10000)  return { key: 'silver' }
  return { key: 'bronze' }
}

// ── Load ─────────────────────────────────────────────────────────────────
async function loadCustomer() {
  loading.value = true
  try {
    const { data } = await $api.get(`/pos/customers/${id.value}/`)
    customer.value = data
  } catch {
    customer.value = null
  } finally {
    loading.value = false
  }
}

async function loadTransactions() {
  txLoading.value = true
  try {
    const params = { customer: id.value, ordering: '-created_at', page_size: 50 }
    if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
    const { data } = await $api.get('/pos/transactions/', { params })
    transactions.value = data?.results || (Array.isArray(data) ? data : [])
    // Auto-expand the first transaction
    expandedTx.value = transactions.value.length ? [0] : []
  } catch {
    transactions.value = []
    expandedTx.value = []
  } finally {
    txLoading.value = false
  }
}

async function performDelete() {
  deleting.value = true
  try {
    await $api.delete(`/pos/customers/${id.value}/`)
    navigateTo(backPath.value)
  } catch {
    // stay on page
  } finally {
    deleting.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────
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

// ── Transaction helpers ──────────────────────────────────────────────────
function txStatusColor(status) {
  if (status === 'completed') return 'success'
  if (status === 'cancelled') return 'error'
  if (status === 'suspended') return 'warning'
  if (status === 'pending') return 'info'
  return 'primary'
}
function txStatusIcon(status) {
  if (status === 'completed') return 'mdi-check-circle'
  if (status === 'cancelled') return 'mdi-close-circle'
  if (status === 'suspended') return 'mdi-pause-circle'
  if (status === 'pending') return 'mdi-clock-outline'
  return 'mdi-receipt-text'
}
function txPaymentIcon(method) {
  if (method === 'cash') return 'mdi-cash'
  if (method === 'card') return 'mdi-credit-card'
  if (method === 'mpesa') return 'mdi-cellphone'
  if (method === 'insurance') return 'mdi-shield-account'
  if (method === 'credit') return 'mdi-credit-card-clock'
  return 'mdi-cash'
}
function txPaymentColor(method) {
  if (method === 'cash') return 'success'
  if (method === 'card') return 'blue'
  if (method === 'mpesa') return 'green'
  if (method === 'insurance') return 'teal'
  if (method === 'credit') return 'orange'
  return 'grey'
}
function txPaymentLabel(method) {
  if (method === 'mpesa') return 'M-Pesa'
  if (!method) return '—'
  return method.charAt(0).toUpperCase() + method.slice(1)
}

onMounted(() => {
  loadCustomer()
  loadTransactions()
})
</script>

<style scoped>
.cust-detail-shell { max-width: 1200px; margin: 0 auto; }

.cust-banner {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.06), rgba(63, 81, 181, 0.03));
}

.cust-stat {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  position: relative;
  overflow: hidden;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.cust-stat::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: rgb(var(--v-theme-primary));
}
.crm-stat-total::before { background: rgb(var(--v-theme-success)); }
.crm-stat-visits::before { background: rgb(var(--v-theme-info)); }
.crm-stat-points::before { background: rgb(var(--v-theme-warning)); }
.crm-stat-member::before { background: rgb(var(--v-theme-primary)); }
.cust-stat:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }

.cust-notes-box {
  white-space: pre-wrap;
  word-break: break-word;
}

.tx-panel {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  margin-bottom: 12px;
  transition: box-shadow 0.15s ease;
}
.tx-panel:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.06); }
.tx-panel-cancelled { opacity: 0.6; }

.tx-items-table {
  border-radius: 8px;
  overflow: hidden;
}
.tx-items-table :deep(thead) { background: rgba(var(--v-theme-surface-variant), 0.08); }
.tx-items-table :deep(th) { padding: 6px 8px; font-weight: 600; }
.tx-items-table :deep(td) { padding: 6px 8px; }
.white-space-pre-wrap { white-space: pre-wrap; word-break: break-word; }
</style>
