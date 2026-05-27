<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Adhere Coins" icon="mdi-circle-multiple" subtitle="Virtual currency management — 1 coin = 1 KES. Pharmacies earn 300 coins on signup.">
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-wallet-plus" class="text-none" @click="initWallets" :loading="initingWallets">
          Init wallets
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" class="text-none" @click="openAllocateDialog">
          Allocate Coins
        </v-btn>
      </template>
    </PageHeader>

    <!-- KPI Cards -->
    <v-row dense class="mb-5">
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-amber pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="amber-darken-1" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-circle-multiple</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Total Balance</div>
              <div class="text-h5 font-weight-black">{{ stats.total_balance?.toLocaleString() || 0 }} <span class="text-caption font-weight-medium text-medium-emphasis">KES</span></div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-green pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-arrow-up-bold-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Total Earned</div>
              <div class="text-h5 font-weight-black">{{ stats.total_earned?.toLocaleString() || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-red pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-arrow-down-bold-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Total Spent</div>
              <div class="text-h5 font-weight-black">{{ stats.total_spent?.toLocaleString() || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-blue pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-wallet</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Wallets</div>
              <div class="text-h5 font-weight-black">{{ stats.total_wallets || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-purple pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="purple" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-swap-horizontal-bold</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Transactions</div>
              <div class="text-h5 font-weight-black">{{ stats.total_transactions?.toLocaleString() || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-teal pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:12px">
            <v-avatar color="teal" variant="tonal" rounded="lg" size="44">
              <v-icon size="24">mdi-package-variant</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Packages</div>
              <div class="text-h5 font-weight-black">{{ stats.active_packages || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card rounded="xl" elevation="0" class="mb-4" style="border:1px solid rgba(var(--v-border-color), 0.12)">
      <v-tabs v-model="tab" color="primary" density="comfortable" class="px-2 pt-1">
        <v-tab value="wallets" class="text-none">
          <v-icon start size="20">mdi-wallet</v-icon> Wallets
        </v-tab>
        <v-tab value="transactions" class="text-none">
          <v-icon start size="20">mdi-swap-horizontal-bold</v-icon> Transactions
        </v-tab>
        <v-tab value="packages" class="text-none">
          <v-icon start size="20">mdi-package-variant</v-icon> Packages
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Tab Content -->
    <v-window v-model="tab">
      <!-- WALLETS TAB -->
      <v-window-item value="wallets">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex align-center pa-4">
            <v-icon class="mr-2" color="primary">mdi-wallet</v-icon>
            Tenant Wallets
            <v-spacer />
            <v-text-field
              v-model="walletSearch"
              density="compact" variant="outlined" rounded="lg" hide-details
              placeholder="Search tenant..."
              prepend-inner-icon="mdi-magnify"
              style="max-width: 280px"
              clearable
            />
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingWallets" indeterminate color="primary" />
          <v-data-table
            :headers="walletHeaders"
            :items="filteredWallets"
            :items-per-page="15"
            density="comfortable"
            hover
            class="coin-table"
          >
            <template #item.tenant_name="{ item }">
              <div class="d-flex align-center py-1" style="gap:10px">
                <v-avatar :color="tenantColor(item.tenant)" variant="tonal" rounded="lg" size="36">
                  <span class="text-caption font-weight-bold">{{ (item.tenant_name || '?')[0] }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.tenant_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.tenant_type }}</div>
                </div>
              </div>
            </template>
            <template #item.balance="{ item }">
              <v-chip :color="Number(item.balance) > 0 ? 'amber-darken-2' : 'grey'" variant="flat" size="small" class="font-weight-bold">
                <v-icon start size="14">mdi-circle-multiple</v-icon>
                {{ Number(item.balance).toLocaleString() }} KES
              </v-chip>
            </template>
            <template #item.lifetime_earned="{ item }">
              <span class="text-success font-weight-medium">+{{ Number(item.lifetime_earned).toLocaleString() }}</span>
            </template>
            <template #item.lifetime_spent="{ item }">
              <span class="text-error font-weight-medium">-{{ Number(item.lifetime_spent).toLocaleString() }}</span>
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-plus-circle" variant="text" size="small" color="success" @click="openAllocateForTenant(item)" />
              <v-btn icon="mdi-minus-circle" variant="text" size="small" color="error" @click="openDeductForTenant(item)" />
              <v-btn icon="mdi-history" variant="text" size="small" color="primary" @click="viewTenantTransactions(item)" />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- TRANSACTIONS TAB -->
      <v-window-item value="transactions">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex flex-wrap align-center pa-4" style="gap:10px">
            <v-icon class="mr-2" color="primary">mdi-swap-horizontal-bold</v-icon>
            Transaction Ledger
            <v-spacer />
            <v-select
              v-model="txTypeFilter"
              :items="txTypeOptions"
              density="compact" variant="outlined" rounded="lg" hide-details
              style="max-width: 160px"
              prepend-inner-icon="mdi-filter-variant"
            />
            <v-text-field
              v-model="txSearch"
              density="compact" variant="outlined" rounded="lg" hide-details
              placeholder="Search..."
              prepend-inner-icon="mdi-magnify"
              style="max-width: 240px"
              clearable
            />
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingTxs" indeterminate color="primary" />
          <v-data-table
            :headers="txHeaders"
            :items="filteredTransactions"
            :items-per-page="20"
            density="comfortable"
            hover
            class="coin-table"
          >
            <template #item.tx_type="{ item }">
              <v-chip :color="txColor(item.tx_type)" variant="tonal" size="small" :prepend-icon="txIcon(item.tx_type)" class="text-none font-weight-bold">
                {{ item.tx_type }}
              </v-chip>
            </template>
            <template #item.amount="{ item }">
              <span :class="['font-weight-bold', isCredit(item.tx_type) ? 'text-success' : 'text-error']">
                {{ isCredit(item.tx_type) ? '+' : '-' }}{{ Number(item.amount).toLocaleString() }} KES
              </span>
            </template>
            <template #item.balance_after="{ item }">
              <span class="font-weight-medium">{{ item.balance_after != null ? Number(item.balance_after).toLocaleString() : '—' }}</span>
            </template>
            <template #item.created_at="{ item }">
              <span class="text-medium-emphasis">{{ formatDateTime(item.created_at) }}</span>
            </template>
            <template #item.tenant_name="{ item }">
              <span class="font-weight-medium">{{ item.tenant_name }}</span>
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- PACKAGES TAB -->
      <v-window-item value="packages">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex align-center pa-4">
            <v-icon class="mr-2" color="primary">mdi-package-variant</v-icon>
            Coin Packages
            <v-spacer />
            <v-btn color="primary" variant="flat" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openPackageDialog()">
              New Package
            </v-btn>
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingPackages" indeterminate color="primary" />
          <v-row dense class="pa-4">
            <v-col v-for="pkg in packages" :key="pkg.id" cols="12" sm="6" md="4" lg="3">
              <v-card
                rounded="xl" elevation="0"
                class="package-card pa-5 d-flex flex-column"
                :class="{ 'package-inactive': !pkg.is_active }"
                style="border:1px solid rgba(var(--v-border-color), 0.12); height:100%"
              >
                <div class="d-flex align-center mb-3" style="gap:10px">
                  <v-avatar color="amber-darken-2" variant="tonal" rounded="lg" size="48">
                    <v-icon size="26">mdi-circle-multiple</v-icon>
                  </v-avatar>
                  <div>
                    <div class="text-h6 font-weight-bold">{{ pkg.name }}</div>
                    <v-chip v-if="!pkg.is_active" size="x-small" color="grey" variant="flat">Inactive</v-chip>
                  </div>
                </div>
                <div class="d-flex align-center mb-2" style="gap:8px">
                  <div class="text-h4 font-weight-black text-amber-darken-3">{{ pkg.coins.toLocaleString() }}</div>
                  <div class="text-body-2 text-medium-emphasis">coins</div>
                </div>
                <div v-if="pkg.bonus_coins" class="d-flex align-center mb-3" style="gap:4px">
                  <v-icon color="success" size="16">mdi-gift</v-icon>
                  <span class="text-success text-body-2 font-weight-bold">+{{ pkg.bonus_coins.toLocaleString() }} bonus</span>
                </div>
                <div class="text-body-2 text-medium-emphasis mb-3" style="flex:1">{{ pkg.description || 'No description' }}</div>
                <v-divider class="mb-3" />
                <div class="d-flex align-center justify-space-between">
                  <div class="text-h6 font-weight-bold">{{ pkg.currency }} {{ Number(pkg.price).toLocaleString() }}</div>
                  <div class="d-flex" style="gap:4px">
                    <v-btn icon="mdi-pencil" variant="text" size="small" @click="openPackageDialog(pkg)" />
                    <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDeletePackage(pkg)" />
                  </div>
                </div>
              </v-card>
            </v-col>
            <v-col v-if="!packages.length && !loadingPackages" cols="12">
              <div class="text-center pa-10 text-medium-emphasis">
                <v-icon size="64" color="grey-lighten-1">mdi-package-variant</v-icon>
                <div class="text-h6 mt-3">No packages yet</div>
                <div class="text-body-2 mb-4">Create your first coin package to get started.</div>
                <v-btn color="primary" variant="flat" rounded="lg" prepend-icon="mdi-plus" class="text-none" @click="openPackageDialog()">Create Package</v-btn>
              </div>
            </v-col>
          </v-row>
        </v-card>
      </v-window-item>
    </v-window>

    <!-- ALLOCATE DIALOG -->
    <v-dialog v-model="allocateDialog" max-width="520" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="success" class="mr-2">mdi-plus-circle</v-icon>
          Allocate Coins
        </v-card-title>
        <v-card-text class="px-5">
          <v-autocomplete
            v-model="allocForm.tenant_id"
            :items="tenantOptions"
            item-title="name" item-value="id"
            label="Tenant"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-domain"
            class="mb-3"
            :disabled="!!allocForm._locked_tenant"
          />
          <v-text-field
            v-model.number="allocForm.amount"
            label="Amount (coins)"
            type="number" min="1"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-circle-multiple"
            class="mb-3"
          />
          <v-select
            v-model="allocForm.tx_type"
            :items="[{title:'Credit', value:'credit'},{title:'Bonus', value:'bonus'},{title:'Refund', value:'refund'}]"
            label="Type"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-tag"
            class="mb-3"
          />
          <v-select
            v-model="allocForm.package_id"
            :items="packageOptions"
            item-title="name" item-value="id"
            label="Package (optional)"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-package-variant"
            clearable
            class="mb-3"
          />
          <v-text-field
            v-model="allocForm.description"
            label="Description"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-text"
            class="mb-3"
          />
          <v-text-field
            v-model="allocForm.reference"
            label="Reference (e.g. payment ID)"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-identifier"
          />
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="allocateDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" rounded="lg" class="text-none" :loading="allocating" :disabled="!allocForm.tenant_id || !allocForm.amount" @click="submitAllocate">
            Allocate
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- DEDUCT DIALOG -->
    <v-dialog v-model="deductDialog" max-width="480" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="error" class="mr-2">mdi-minus-circle</v-icon>
          Deduct Coins
        </v-card-title>
        <v-card-text class="px-5">
          <v-autocomplete
            v-model="deductForm.tenant_id"
            :items="tenantOptions"
            item-title="name" item-value="id"
            label="Tenant"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-domain"
            class="mb-3"
            :disabled="!!deductForm._locked_tenant"
          />
          <v-alert v-if="deductForm._balance != null" type="info" variant="tonal" density="compact" class="mb-3">
            Current balance: <strong>{{ Number(deductForm._balance).toLocaleString() }} KES</strong>
          </v-alert>
          <v-text-field
            v-model.number="deductForm.amount"
            label="Amount (coins)"
            type="number" min="1"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-circle-multiple"
            class="mb-3"
          />
          <v-text-field
            v-model="deductForm.description"
            label="Reason"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-text"
            class="mb-3"
          />
          <v-text-field
            v-model="deductForm.reference"
            label="Reference"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-identifier"
          />
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="deductDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none" :loading="deducting" :disabled="!deductForm.tenant_id || !deductForm.amount" @click="submitDeduct">
            Deduct
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- PACKAGE DIALOG -->
    <v-dialog v-model="packageDialog" max-width="520" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="primary" class="mr-2">mdi-package-variant</v-icon>
          {{ editingPackage ? 'Edit Package' : 'New Package' }}
        </v-card-title>
        <v-card-text class="px-5">
          <v-text-field
            v-model="pkgForm.name"
            label="Package Name"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-label"
            class="mb-3"
          />
          <v-row dense class="mb-3">
            <v-col cols="6">
              <v-text-field
                v-model.number="pkgForm.coins"
                label="Coins"
                type="number" min="1"
                density="compact" variant="outlined" rounded="lg"
                prepend-inner-icon="mdi-circle-multiple"
              />
            </v-col>
            <v-col cols="6">
              <v-text-field
                v-model.number="pkgForm.bonus_coins"
                label="Bonus Coins"
                type="number" min="0"
                density="compact" variant="outlined" rounded="lg"
                prepend-inner-icon="mdi-gift"
              />
            </v-col>
          </v-row>
          <v-row dense class="mb-3">
            <v-col cols="4">
              <v-select
                v-model="pkgForm.currency"
                :items="['KES', 'USD', 'EUR', 'GBP']"
                label="Currency"
                density="compact" variant="outlined" rounded="lg"
              />
            </v-col>
            <v-col cols="8">
              <v-text-field
                v-model.number="pkgForm.price"
                label="Price"
                type="number" min="0" step="0.01"
                density="compact" variant="outlined" rounded="lg"
                prepend-inner-icon="mdi-cash"
              />
            </v-col>
          </v-row>
          <v-textarea
            v-model="pkgForm.description"
            label="Description"
            density="compact" variant="outlined" rounded="lg"
            rows="2"
            class="mb-3"
          />
          <v-switch v-model="pkgForm.is_active" label="Active" color="primary" density="compact" hide-details />
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="packageDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="savingPackage" :disabled="!pkgForm.name || !pkgForm.coins || !pkgForm.price" @click="submitPackage">
            {{ editingPackage ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- DELETE CONFIRM -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>
          Delete Package
        </v-card-title>
        <v-card-text class="px-5">
          Are you sure you want to delete <strong>{{ deletingPackage?.name }}</strong>? This action cannot be undone.
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none" :loading="deletingPkg" @click="doDeletePackage">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" rounded="lg" location="top">
      {{ snack.text }}
      <template #actions>
        <v-btn variant="text" @click="snack.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()

// State
const tab = ref('wallets')
const stats = ref({})
const wallets = ref([])
const transactions = ref([])
const packages = ref([])
const tenantOptions = ref([])

const loadingWallets = ref(false)
const loadingTxs = ref(false)
const loadingPackages = ref(false)
const initingWallets = ref(false)

const walletSearch = ref('')
const txSearch = ref('')
const txTypeFilter = ref('all')

// Dialogs
const allocateDialog = ref(false)
const deductDialog = ref(false)
const packageDialog = ref(false)
const deleteDialog = ref(false)
const allocating = ref(false)
const deducting = ref(false)
const savingPackage = ref(false)
const deletingPkg = ref(false)
const editingPackage = ref(null)
const deletingPackage = ref(null)

const allocForm = reactive({ tenant_id: null, amount: null, tx_type: 'credit', package_id: null, description: '', reference: '', _locked_tenant: false })
const deductForm = reactive({ tenant_id: null, amount: null, description: '', reference: '', _locked_tenant: false, _balance: null })
const pkgForm = reactive({ name: '', coins: null, bonus_coins: 0, price: null, currency: 'KES', description: '', is_active: true })

const snack = reactive({ show: false, text: '', color: 'success' })

// Computed
const txTypeOptions = [
  { title: 'All types', value: 'all' },
  { title: 'Earned', value: 'earned' },
  { title: 'Redeemed', value: 'redeemed' },
  { title: 'Bonus', value: 'bonus' },
  { title: 'Adjustment', value: 'adjustment' },
]

const walletHeaders = [
  { title: 'Tenant', key: 'tenant_name', sortable: true },
  { title: 'Balance', key: 'balance', sortable: true, align: 'end' },
  { title: 'Earned', key: 'lifetime_earned', sortable: true, align: 'end' },
  { title: 'Spent', key: 'lifetime_spent', sortable: true, align: 'end' },
  { title: 'Actions', key: 'actions', sortable: false, align: 'end', width: '140px' },
]

const txHeaders = [
  { title: 'Tenant', key: 'tenant_name', sortable: true },
  { title: 'Type', key: 'tx_type', sortable: true },
  { title: 'Amount', key: 'amount', sortable: true, align: 'end' },
  { title: 'Description', key: 'description' },
  { title: 'Date', key: 'created_at', sortable: true },
]

const packageOptions = computed(() => packages.value.filter(p => p.is_active))

const filteredWallets = computed(() => {
  const q = (walletSearch.value || '').toLowerCase()
  if (!q) return wallets.value
  return wallets.value.filter(w => (w.tenant_name || '').toLowerCase().includes(q))
})

const filteredTransactions = computed(() => {
  let arr = transactions.value
  if (txTypeFilter.value !== 'all') arr = arr.filter(t => t.tx_type === txTypeFilter.value)
  const q = (txSearch.value || '').toLowerCase()
  if (q) arr = arr.filter(t =>
    (t.tenant_name || '').toLowerCase().includes(q) ||
    (t.description || '').toLowerCase().includes(q) ||
    (t.reference || '').toLowerCase().includes(q)
  )
  return arr
})

// Helpers
function notify(text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function txColor(type) {
  const map = { credit: 'success', debit: 'error', bonus: 'purple', refund: 'info', expired: 'grey', purchase: 'amber-darken-2', earned: 'success', redeemed: 'error', adjustment: 'warning', gift_received: 'purple' }
  return map[type] || 'default'
}
function txIcon(type) {
  const map = { credit: 'mdi-arrow-up-bold', debit: 'mdi-arrow-down-bold', bonus: 'mdi-gift', refund: 'mdi-undo', expired: 'mdi-clock-alert', purchase: 'mdi-cart', earned: 'mdi-arrow-up-bold', redeemed: 'mdi-arrow-down-bold', adjustment: 'mdi-tune', gift_received: 'mdi-gift' }
  return map[type] || 'mdi-swap-horizontal'
}
function isCredit(type) { return ['credit', 'bonus', 'refund', 'purchase', 'earned', 'gift_received'].includes(type) }

const _colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'amber-darken-2']
function tenantColor(id) { return _colors[(Number(id) || 0) % _colors.length] }

// API calls
async function loadStats() {
  try {
    const { data } = await $api.get('/superadmin/coins/stats/')
    stats.value = data
  } catch { /* ignore */ }
}

async function loadWallets() {
  loadingWallets.value = true
  try {
    const { data } = await $api.get('/superadmin/coins/wallets/')
    wallets.value = data?.results || data || []
  } catch { wallets.value = [] }
  finally { loadingWallets.value = false }
}

async function loadTransactions() {
  loadingTxs.value = true
  try {
    const { data } = await $api.get('/superadmin/coins/transactions/')
    transactions.value = data?.results || data || []
  } catch { transactions.value = [] }
  finally { loadingTxs.value = false }
}

async function loadPackages() {
  loadingPackages.value = true
  try {
    const { data } = await $api.get('/superadmin/coins/packages/')
    packages.value = data?.results || data || []
  } catch { packages.value = [] }
  finally { loadingPackages.value = false }
}

async function loadTenants() {
  try {
    const { data } = await $api.get('/superadmin/tenants/?page_size=500')
    tenantOptions.value = (data?.results || data || []).map(t => ({ id: t.id, name: t.name }))
  } catch { tenantOptions.value = [] }
}

async function initWallets() {
  initingWallets.value = true
  try {
    const { data } = await $api.post('/superadmin/coins/init-wallets/')
    notify(`${data.created} wallet(s) initialized`)
    loadWallets()
    loadStats()
  } catch { notify('Failed to init wallets', 'error') }
  finally { initingWallets.value = false }
}

// Allocate
function openAllocateDialog() {
  Object.assign(allocForm, { tenant_id: null, amount: null, tx_type: 'credit', package_id: null, description: '', reference: '', _locked_tenant: false })
  allocateDialog.value = true
}
function openAllocateForTenant(wallet) {
  Object.assign(allocForm, { tenant_id: wallet.tenant, amount: null, tx_type: 'credit', package_id: null, description: '', reference: '', _locked_tenant: true })
  allocateDialog.value = true
}
async function submitAllocate() {
  allocating.value = true
  try {
    await $api.post('/superadmin/coins/allocate/', {
      tenant_id: allocForm.tenant_id,
      amount: allocForm.amount,
      tx_type: allocForm.tx_type,
      package_id: allocForm.package_id || null,
      description: allocForm.description,
      reference: allocForm.reference,
    })
    notify(`${allocForm.amount} coins allocated`)
    allocateDialog.value = false
    loadWallets(); loadTransactions(); loadStats()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Allocation failed', 'error')
  } finally { allocating.value = false }
}

// Deduct
function openDeductForTenant(wallet) {
  Object.assign(deductForm, { tenant_id: wallet.tenant, amount: null, description: '', reference: '', _locked_tenant: true, _balance: wallet.balance })
  deductDialog.value = true
}
async function submitDeduct() {
  deducting.value = true
  try {
    await $api.post('/superadmin/coins/deduct/', {
      tenant_id: deductForm.tenant_id,
      amount: deductForm.amount,
      description: deductForm.description,
      reference: deductForm.reference,
    })
    notify(`${deductForm.amount} coins deducted`)
    deductDialog.value = false
    loadWallets(); loadTransactions(); loadStats()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Deduction failed', 'error')
  } finally { deducting.value = false }
}

// Packages CRUD
function openPackageDialog(pkg = null) {
  editingPackage.value = pkg
  if (pkg) {
    Object.assign(pkgForm, { name: pkg.name, coins: pkg.coins, bonus_coins: pkg.bonus_coins, price: Number(pkg.price), currency: pkg.currency, description: pkg.description || '', is_active: pkg.is_active })
  } else {
    Object.assign(pkgForm, { name: '', coins: null, bonus_coins: 0, price: null, currency: 'KES', description: '', is_active: true })
  }
  packageDialog.value = true
}

async function submitPackage() {
  savingPackage.value = true
  try {
    const payload = { name: pkgForm.name, coins: pkgForm.coins, bonus_coins: pkgForm.bonus_coins || 0, price: pkgForm.price, currency: pkgForm.currency, description: pkgForm.description, is_active: pkgForm.is_active }
    if (editingPackage.value) {
      await $api.put(`/superadmin/coins/packages/${editingPackage.value.id}/`, payload)
      notify('Package updated')
    } else {
      await $api.post('/superadmin/coins/packages/', payload)
      notify('Package created')
    }
    packageDialog.value = false
    loadPackages(); loadStats()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save package', 'error')
  } finally { savingPackage.value = false }
}

function confirmDeletePackage(pkg) {
  deletingPackage.value = pkg
  deleteDialog.value = true
}
async function doDeletePackage() {
  deletingPkg.value = true
  try {
    await $api.delete(`/superadmin/coins/packages/${deletingPackage.value.id}/`)
    notify('Package deleted')
    deleteDialog.value = false
    loadPackages(); loadStats()
  } catch { notify('Failed to delete', 'error') }
  finally { deletingPkg.value = false }
}

// View tenant transactions
function viewTenantTransactions(wallet) {
  txTypeFilter.value = 'all'
  txSearch.value = wallet.tenant_name
  tab.value = 'transactions'
}

// Init
onMounted(() => {
  loadStats()
  loadWallets()
  loadTransactions()
  loadPackages()
  loadTenants()
})
</script>

<style scoped>
.kpi-card {
  border: 1px solid rgba(var(--v-border-color), 0.08);
  transition: transform 0.2s, box-shadow 0.2s;
}
.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
}
.kpi-gradient-amber { background: linear-gradient(135deg, rgba(255,193,7,0.08), rgba(255,193,7,0.02)); }
.kpi-gradient-green { background: linear-gradient(135deg, rgba(76,175,80,0.08), rgba(76,175,80,0.02)); }
.kpi-gradient-red { background: linear-gradient(135deg, rgba(244,67,54,0.08), rgba(244,67,54,0.02)); }
.kpi-gradient-blue { background: linear-gradient(135deg, rgba(33,150,243,0.08), rgba(33,150,243,0.02)); }
.kpi-gradient-purple { background: linear-gradient(135deg, rgba(156,39,176,0.08), rgba(156,39,176,0.02)); }
.kpi-gradient-teal { background: linear-gradient(135deg, rgba(0,150,136,0.08), rgba(0,150,136,0.02)); }

.package-card {
  transition: transform 0.2s, box-shadow 0.2s;
}
.package-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 32px rgba(0,0,0,0.1);
}
.package-inactive {
  opacity: 0.6;
}

.coin-table :deep(th) {
  font-weight: 700 !important;
  text-transform: uppercase;
  font-size: 11px !important;
  letter-spacing: 0.05em;
}
</style>
