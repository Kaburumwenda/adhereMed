<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="info" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-shape</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Categories</h1>
          <div class="text-body-2 text-medium-emphasis">Group your stock items for easier filtering &amp; reporting</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="reload">Refresh</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" to="/inventory/categories/new">New Category</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(59,130,246,0.06), rgba(59,130,246,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-shape</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Categories</div>
              <div class="text-h6 font-weight-bold">{{ categories.length.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(34,197,94,0.07), rgba(34,197,94,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cube-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Total SKUs</div>
              <div class="text-h6 font-weight-bold">{{ stocks.length.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(245,158,11,0.07), rgba(245,158,11,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-tag-off</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Uncategorised</div>
              <div class="text-h6 font-weight-bold">{{ uncategorisedCount.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(139,92,246,0.07), rgba(139,92,246,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="purple" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cash-multiple</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Retail value</div>
              <div class="text-h6 font-weight-bold">{{ formatMoney(totalRetail) }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Toolbar -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          placeholder="Search categories…"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-btn-toggle v-model="viewMode" mandatory density="comfortable" variant="outlined" color="primary" rounded="lg">
          <v-btn value="grid" size="small" icon="mdi-view-grid-outline" />
          <v-btn value="table" size="small" icon="mdi-view-list-outline" />
        </v-btn-toggle>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filtered.length }} of {{ categories.length }}</span>
      </div>
    </v-card>

    <!-- Empty -->
    <div v-if="!loading && !filtered.length" class="pa-10 text-center text-medium-emphasis">
      <v-icon size="64" color="grey">mdi-inbox-outline</v-icon>
      <div class="text-h6 mt-3">No categories</div>
      <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Get started by creating your first category.' }}</div>
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/inventory/categories/new">New Category</v-btn>
    </div>

    <!-- Grid view -->
    <v-row v-else-if="viewMode === 'grid'" dense>
      <v-col v-for="cat in pagedItems" :key="cat.id" cols="12" sm="6" md="4" lg="3">
        <v-card rounded="lg" elevation="0" class="pa-4 h-100 cat-card" :style="{ borderLeft: `4px solid ${categoryColor(cat.id)}` }">
          <div class="d-flex align-start justify-space-between mb-2">
            <v-avatar :color="categoryColor(cat.id)" variant="tonal" rounded="lg" size="40">
              <v-icon>mdi-shape</v-icon>
            </v-avatar>
            <v-menu>
              <template #activator="{ props: p }">
                <v-btn v-bind="p" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item :to="`/inventory/categories/${cat.id}/edit`" prepend-icon="mdi-pencil" title="Edit" />
                <v-list-item :to="`/inventory?category=${cat.id}`" prepend-icon="mdi-eye" title="View items" />
              </v-list>
            </v-menu>
          </div>
          <div class="font-weight-bold text-h6">{{ cat.name }}</div>
          <div class="text-caption text-medium-emphasis text-truncate mb-3" style="min-height:18px">{{ cat.description || 'No description' }}</div>
          <v-divider class="mb-3" />
          <div class="d-flex justify-space-between mb-1">
            <span class="text-caption text-medium-emphasis">SKUs</span>
            <span class="font-weight-medium">{{ countByCategory(cat.id).toLocaleString() }}</span>
          </div>
          <div class="d-flex justify-space-between mb-1">
            <span class="text-caption text-medium-emphasis">Units on hand</span>
            <span class="font-weight-medium">{{ unitsByCategory(cat.id).toLocaleString() }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Retail value</span>
            <span class="font-weight-medium text-primary">{{ formatMoney(retailByCategory(cat.id)) }}</span>
          </div>
          <v-progress-linear
            :model-value="sharePctByCategory(cat.id)"
            :color="categoryColor(cat.id)"
            height="6" rounded
          />
          <div class="text-caption text-medium-emphasis mt-1">{{ sharePctByCategory(cat.id) }}% of inventory value</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Table view -->
    <v-card v-else rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Category</th>
              <th>Description</th>
              <th class="text-right">SKUs</th>
              <th class="text-right">Units</th>
              <th class="text-right">Retail value</th>
              <th>Share</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(cat, i) in pagedItems" :key="cat.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="categoryColor(cat.id)" variant="tonal" rounded="lg" size="34"><v-icon size="18">mdi-shape</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ cat.name }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ cat.id }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis" style="max-width:280px">
                <div class="text-truncate">{{ cat.description || '—' }}</div>
              </td>
              <td class="text-right font-weight-medium">{{ countByCategory(cat.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByCategory(cat.id).toLocaleString() }}</td>
              <td class="text-right font-weight-medium">{{ formatMoney(retailByCategory(cat.id)) }}</td>
              <td style="min-width:140px">
                <v-progress-linear :model-value="sharePctByCategory(cat.id)" :color="categoryColor(cat.id)" height="6" rounded />
                <div class="text-caption text-medium-emphasis mt-1">{{ sharePctByCategory(cat.id) }}%</div>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/categories/${cat.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>

    <!-- Pagination -->
    <div v-if="filtered.length" class="d-flex flex-wrap align-center mt-3" style="gap:12px">
      <span class="text-caption text-medium-emphasis">
        Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filtered.length }}</strong>
      </span>
      <v-spacer />
      <div class="d-flex align-center" style="gap:6px">
        <span class="text-caption text-medium-emphasis">Per page</span>
        <v-select v-model="pageSize" :items="[12, 24, 48, 96]" density="compact" variant="outlined" rounded="lg" hide-details style="width:92px" />
      </div>
      <v-pagination v-if="totalPages > 1" v-model="page" :length="totalPages" :total-visible="5" density="comfortable" rounded="lg" color="primary" />
    </div>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatMoney } from '~/utils/format'
import { useResource } from '~/composables/useResource'

const catRes = useResource('/inventory/categories/')
const stockRes = useResource('/inventory/stocks/')

const categories = computed(() => catRes.items.value || [])
const stocks = computed(() => stockRes.items.value || [])
const loading = computed(() => catRes.loading.value || stockRes.loading.value)

const search = ref('')
const viewMode = ref('grid')
const page = ref(1)
const pageSize = ref(12)

const filtered = computed(() => {
  const s = search.value.trim().toLowerCase()
  if (!s) return categories.value
  return categories.value.filter(c =>
    (c.name || '').toLowerCase().includes(s) ||
    (c.description || '').toLowerCase().includes(s)
  )
})
const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)))
const pagedItems = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})
const rangeStart = computed(() => filtered.value.length === 0 ? 0 : (page.value - 1) * pageSize.value + 1)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filtered.value.length))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }
watch([search, pageSize], () => { page.value = 1 })

function countByCategory(id) { return stocks.value.filter(s => s.category === id).length }
function unitsByCategory(id) {
  return stocks.value.filter(s => s.category === id).reduce((sum, s) => sum + Number(s.total_quantity || 0), 0)
}
function retailByCategory(id) {
  return stocks.value.filter(s => s.category === id).reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
}
const totalRetail = computed(() =>
  stocks.value.reduce((sum, s) => sum + Number(s.total_quantity || 0) * Number(s.selling_price || 0), 0)
)
const uncategorisedCount = computed(() => stocks.value.filter(s => !s.category).length)
function sharePctByCategory(id) {
  const total = totalRetail.value
  if (!total) return 0
  return Math.round((retailByCategory(id) / total) * 100)
}
const _palette = ['#3b82f6', '#22c55e', '#f59e0b', '#a855f7', '#ef4444', '#06b6d4', '#84cc16', '#ec4899', '#14b8a6', '#eab308']
function categoryColor(id) { return _palette[(Number(id) || 0) % _palette.length] }

function reload() {
  catRes.list({ page_size: 2000 })
  stockRes.list({ page_size: 5000 })
}
onMounted(reload)
</script>

<style scoped>
.cat-card { border: 1px solid rgba(0,0,0,0.06); transition: transform 0.18s ease, box-shadow 0.18s ease; }
.cat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(0,0,0,0.06); }
.table-wrap { overflow-x: auto; }
.inv-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.inv-table thead th {
  text-align: left; font-size: 12px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.06em;
  padding: 12px 14px; color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.04);
  border-bottom: 1px solid rgba(0,0,0,0.06);
}
.inv-table tbody td { padding: 12px 14px; border-bottom: 1px solid rgba(0,0,0,0.04); }
.inv-table tbody tr:hover { background: rgba(0,0,0,0.015); }
.row-num { width: 56px; text-align: center; font-variant-numeric: tabular-nums; }
.inv-table thead th.row-num { text-align: center; }
</style>
