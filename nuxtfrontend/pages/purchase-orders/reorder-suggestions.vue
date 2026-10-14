<template>
  <v-container fluid class="pa-3 pa-md-5 reorder-page">
    <!-- Hero header -->
    <div class="hero-header mb-5">
      <div class="d-flex flex-wrap align-center justify-space-between">
        <div class="d-flex align-center" style="gap:16px">
          <v-avatar color="info" variant="tonal" rounded="xl" size="56">
            <v-icon size="30">mdi-package-variant-closed</v-icon>
          </v-avatar>
          <div>
            <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Reorder Suggestions</h1>
            <div class="text-body-2 text-medium-emphasis">Auto-generated restock recommendations based on reorder levels</div>
          </div>
        </div>
        <div class="d-flex align-center flex-wrap mt-3 mt-md-0" style="gap:8px">
          <v-select
            v-if="branchStore.hasBranches && !isBranchLocked"
            v-model="branchFilter"
            :items="branchFilterItems"
            item-title="name"
            item-value="id"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            flat
            prepend-inner-icon="mdi-store-marker"
            style="max-width: 200px; min-width: 160px"
          />
          <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="reload">Refresh</v-btn>
          <v-btn color="info" prepend-icon="mdi-magic" rounded="lg" class="text-none" :loading="generating" @click="generate">
            Generate Suggestions
          </v-btn>
        </div>
      </div>
    </div>

    <v-progress-linear v-if="loading" color="info" indeterminate class="mb-3 rounded" />

    <!-- Summary chips -->
    <div v-if="items.length" class="d-flex flex-wrap mb-4" style="gap:8px">
      <div class="summary-chip summary-total">
        <v-icon size="16">mdi-clipboard-list-outline</v-icon>
        <span>{{ items.length }} suggestions</span>
      </div>
      <div class="summary-chip summary-pending">
        <v-icon size="16">mdi-clock-outline</v-icon>
        <span>{{ pendingCount }} pending</span>
      </div>
      <div class="summary-chip summary-cost" v-if="totalEstimated > 0">
        <v-icon size="16">mdi-cash-multiple</v-icon>
        <span>Est. total: {{ formatMoney(totalEstimated) }}</span>
      </div>
      <div class="summary-chip summary-out" v-if="outOfStockCount > 0">
        <v-icon size="16">mdi-package-variant-closed-remove</v-icon>
        <span>{{ outOfStockCount }} out of stock</span>
      </div>
    </div>

    <!-- Empty state -->
    <v-card v-if="!loading && !items.length" rounded="xl" elevation="0" class="pa-10 text-center empty-card">
      <div class="empty-icon-wrap">
        <v-icon size="56" color="info">mdi-clipboard-list-outline</v-icon>
      </div>
      <div class="text-h6 mt-4 font-weight-bold">No reorder suggestions</div>
      <div class="text-body-2 text-medium-emphasis mb-5">Click "Generate Suggestions" to scan stock levels and create recommendations.</div>
      <v-btn color="info" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-magic" size="large" @click="generate">Generate Now</v-btn>
    </v-card>

    <!-- Cards layout -->
    <v-row v-if="items.length" dense>
      <v-col v-for="(row, i) in items" :key="row.id" cols="12" md="6" lg="4">
        <v-card rounded="xl" elevation="0" class="suggestion-card pa-4 h-100" :class="stockLevelClass(row)">
          <!-- Card header -->
          <div class="d-flex align-start justify-space-between mb-3">
            <div class="d-flex align-center" style="gap:10px">
              <v-avatar :color="stockLevelColor(row)" variant="tonal" rounded="lg" size="40">
                <v-icon size="20">{{ stockLevelIcon(row) }}</v-icon>
              </v-avatar>
              <div>
                <div class="font-weight-bold text-body-1">{{ row.stock_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ row.stock_sku || '' }}</div>
              </div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="suggStatusColor(row.status)">{{ row.status }}</v-chip>
          </div>

          <!-- Category badge -->
          <v-chip v-if="row.stock_category" size="x-small" variant="outlined" class="mb-3 text-none" prepend-icon="mdi-shape-outline">
            {{ row.stock_category }}
          </v-chip>

          <!-- Stock levels visual -->
          <div class="stock-bars mb-3">
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-caption text-medium-emphasis">Current Stock</span>
              <span class="text-body-2 font-weight-bold" :class="stockLevelTextClass(row)">
                {{ Number(row.current_quantity).toLocaleString() }} {{ row.unit_name || '' }}
              </span>
            </div>
            <v-progress-linear
              :model-value="stockPct(row)"
              :color="stockLevelColor(row)"
              height="8"
              rounded
              class="mb-2"
            />
            <div class="d-flex align-center justify-space-between mb-1">
              <span class="text-caption text-medium-emphasis">
                <v-icon size="12" class="mr-1">mdi-bell-outline</v-icon>Reorder Level
              </span>
              <span class="text-body-2 font-weight-medium text-warning">{{ Number(row.reorder_level).toLocaleString() }}</span>
            </div>
          </div>

          <v-divider class="mb-3" />

          <!-- Suggestion details -->
          <div class="d-flex align-center justify-space-between mb-2">
            <div>
              <div class="text-caption text-medium-emphasis">Suggested Quantity</div>
              <div class="text-h6 font-weight-bold text-info">
                {{ Number(row.suggested_quantity).toLocaleString() }} {{ row.unit_name || '' }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Estimated Cost</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(row.estimated_cost) }}</div>
            </div>
          </div>

          <!-- Supplier -->
          <div class="d-flex align-center mt-2" style="gap:6px" v-if="row.recommended_supplier_name">
            <v-icon size="16" color="medium-emphasis">mdi-truck</v-icon>
            <span class="text-body-2 text-medium-emphasis">{{ row.recommended_supplier_name }}</span>
          </div>
          <div class="d-flex align-center mt-2" style="gap:6px" v-else>
            <v-icon size="16" color="warning">mdi-truck-alert</v-icon>
            <span class="text-body-2 text-warning">No supplier linked</span>
          </div>

          <!-- Actions -->
          <div class="d-flex mt-3" style="gap:6px" v-if="row.status === 'pending'">
            <v-btn size="small" color="success" variant="tonal" rounded="lg" class="text-none flex-grow-1" prepend-icon="mdi-check" @click="markOrdered(row)">
              Mark Ordered
            </v-btn>
            <v-btn size="small" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-close" @click="dismiss(row)">
              Dismiss
            </v-btn>
          </div>
          <div class="d-flex align-center mt-3" style="gap:6px" v-else>
            <v-icon size="18" :color="suggStatusColor(row.status)">mdi-check-circle</v-icon>
            <span class="text-body-2 text-medium-emphasis text-capitalize">{{ row.status }}</span>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch, reactive } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const auth = useAuthStore()
const suggRes = useResource('/purchase-orders/reorder-suggestions/')
const loading = computed(() => suggRes.loading.value)
const items = computed(() => suggRes.items.value || [])
const generating = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const isBranchLocked = computed(() => auth.role === 'branch_admin')
const branchFilter = ref(null)
const branchFilterItems = computed(() => {
  if (isBranchLocked.value) {
    const b = branchStore.currentBranch
    return b ? [{ id: b.id, name: b.name }] : []
  }
  const items = branchStore.activeBranches.map(b => ({ id: b.id, name: b.name }))
  items.unshift({ id: null, name: 'All Branches' })
  return items
})

const pendingCount = computed(() => items.value.filter(i => i.status === 'pending').length)
const totalEstimated = computed(() => items.value
  .filter(i => i.status === 'pending')
  .reduce((sum, i) => sum + Number(i.estimated_cost || 0), 0))
const outOfStockCount = computed(() => items.value.filter(i => Number(i.current_quantity) === 0).length)

function suggStatusColor(s) { return { pending: 'warning', ordered: 'success', dismissed: 'grey' }[s] || 'default' }

function stockLevelColor(row) {
  const qty = Number(row.current_quantity)
  if (qty === 0) return 'error'
  if (qty <= Number(row.reorder_level) * 0.5) return 'warning'
  return 'info'
}

function stockLevelIcon(row) {
  const qty = Number(row.current_quantity)
  if (qty === 0) return 'mdi-package-variant-closed-remove'
  if (qty <= Number(row.reorder_level) * 0.5) return 'mdi-package-variant-closed-alert'
  return 'mdi-package-variant-closed'
}

function stockLevelClass(row) {
  const qty = Number(row.current_quantity)
  if (qty === 0) return 'card-out-of-stock'
  return ''
}

function stockLevelTextClass(row) {
  const qty = Number(row.current_quantity)
  if (qty === 0) return 'text-error'
  if (qty <= Number(row.reorder_level) * 0.5) return 'text-warning'
  return ''
}

function stockPct(row) {
  const qty = Number(row.current_quantity)
  const reorder = Number(row.reorder_level)
  if (reorder === 0) return 0
  return Math.min(100, (qty / (reorder * 2)) * 100)
}

async function reload() {
  const params = { page_size: 500 }
  if (branchFilter.value) params.branch = branchFilter.value
  suggRes.list(params)
}

async function generate() {
  generating.value = true
  try {
    const params = {}
    if (branchFilter.value) params.branch = branchFilter.value
    const { data } = await $api.post('/purchase-orders/reorder-suggestions/generate/', params)
    snack.text = data.detail || 'Suggestions generated'
    snack.color = 'success'
    snack.show = true
    reload()
  } catch (e) {
    console.error(e)
    snack.text = 'Failed: ' + (e?.response?.data?.detail || e.message)
    snack.color = 'error'
    snack.show = true
  } finally {
    generating.value = false
  }
}

async function markOrdered(row) {
  try {
    await $api.post(`/purchase-orders/reorder-suggestions/${row.id}/mark_ordered/`)
    snack.text = 'Marked as ordered'
    snack.color = 'success'
    snack.show = true
    reload()
  } catch (e) {
    console.error(e)
    snack.text = 'Failed to update'
    snack.color = 'error'
    snack.show = true
  }
}

async function dismiss(row) {
  try {
    await $api.post(`/purchase-orders/reorder-suggestions/${row.id}/dismiss/`)
    snack.text = 'Suggestion dismissed'
    snack.color = 'info'
    snack.show = true
    reload()
  } catch (e) {
    console.error(e)
    snack.text = 'Failed to dismiss'
    snack.color = 'error'
    snack.show = true
  }
}

onMounted(async () => {
  await branchStore.load()
  if (isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  } else if (!isBranchLocked.value && branchStore.currentBranchId) {
    branchFilter.value = branchStore.currentBranchId
  }
  reload()
})
watch(branchFilter, () => reload())
watch(() => branchStore.currentBranchId, (newId) => {
  if (isBranchLocked.value) {
    branchFilter.value = newId
  }
})
</script>

<style scoped>
.reorder-page { max-width: 1400px; margin: 0 auto; }

.hero-header {
  border-radius: 16px;
  padding: 20px 24px;
  background: linear-gradient(135deg, rgba(0,184,212,0.05), rgba(99,102,241,0.03));
  border: 1px solid rgba(0,184,212,0.1);
}

/* Summary chips */
.summary-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
  border: 1px solid rgba(0,0,0,0.06);
  background: #fff;
  transition: transform 0.15s ease;
}
.summary-chip:hover { transform: translateY(-1px); }
.summary-total { color: #6366f1; border-color: rgba(99,102,241,0.2); }
.summary-pending { color: #f59e0b; border-color: rgba(245,158,11,0.2); }
.summary-cost { color: #10b981; border-color: rgba(16,185,129,0.2); }
.summary-out { color: #ef4444; border-color: rgba(239,68,68,0.2); }

/* Empty state */
.empty-card {
  border: 1px solid rgba(0,0,0,0.06);
  background: linear-gradient(135deg, rgba(0,184,212,0.03), rgba(99,102,241,0.02));
}
.empty-icon-wrap {
  width: 80px; height: 80px;
  margin: 0 auto;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  background: rgba(0,184,212,0.08);
}

/* Suggestion cards */
.suggestion-card {
  border: 1px solid rgba(0,0,0,0.06);
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
  display: flex;
  flex-direction: column;
}
.suggestion-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 10px 28px rgba(0,0,0,0.07);
  border-color: rgba(0,184,212,0.2);
}
.card-out-of-stock {
  border-color: rgba(239,68,68,0.25);
  background: linear-gradient(135deg, rgba(239,68,68,0.02), #fff);
}
.card-out-of-stock:hover {
  border-color: rgba(239,68,68,0.4);
  box-shadow: 0 10px 28px rgba(239,68,68,0.08);
}

.stock-bars { width: 100%; }
</style>
