<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="success" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-ruler</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Units of Measurement</h1>
          <div class="text-body-2 text-medium-emphasis">Define how stock items are counted (tablets, ml, boxes…)</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="reload">{{ $t('common.refresh') }}</v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" to="/inventory/units/new">{{ $t('unitsPage.newUnit') }}</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(34,197,94,0.07), rgba(34,197,94,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-ruler</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Units</div>
              <div class="text-h6 font-weight-bold">{{ units.length.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(59,130,246,0.06), rgba(59,130,246,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-cube-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">SKUs using units</div>
              <div class="text-h6 font-weight-bold">{{ skusWithUnits.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(245,158,11,0.07), rgba(245,158,11,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-help-rhombus</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Without unit</div>
              <div class="text-h6 font-weight-bold">{{ skusWithoutUnit.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3" style="border:1px solid rgba(0,0,0,0.06); background: linear-gradient(135deg, rgba(168,85,247,0.07), rgba(168,85,247,0.01))">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="purple" variant="tonal" rounded="lg" size="40"><v-icon>mdi-counter</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Total on hand</div>
              <div class="text-h6 font-weight-bold">{{ totalOnHand.toLocaleString() }}</div>
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
          placeholder="Search units…"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filtered.length }} of {{ units.length }}</span>
      </div>
    </v-card>

    <div v-if="!loading && !filtered.length" class="pa-10 text-center text-medium-emphasis">
      <v-icon size="64" color="grey">mdi-inbox-outline</v-icon>
      <div class="text-h6 mt-3">No units</div>
      <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Create your first unit of measurement.' }}</div>
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/inventory/units/new">{{ $t('unitsPage.newUnit') }}</v-btn>
    </div>

    <!-- Table -->
    <v-card v-else rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Unit</th>
              <th>Abbreviation</th>
              <th class="text-right">SKUs</th>
              <th class="text-right">Total on hand</th>
              <th>Usage</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(u, i) in pagedItems" :key="u.id">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="success" variant="tonal" rounded="lg" size="34"><v-icon size="18">mdi-ruler</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ u.name }}</div>
                    <div class="text-caption text-medium-emphasis">ID #{{ u.id }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="small" variant="tonal" color="success">{{ u.abbreviation || u.symbol || '—' }}</v-chip>
              </td>
              <td class="text-right font-weight-medium">{{ countByUnit(u.id).toLocaleString() }}</td>
              <td class="text-right">{{ unitsByUnit(u.id).toLocaleString() }} <span class="text-caption text-medium-emphasis">{{ u.abbreviation || '' }}</span></td>
              <td style="min-width:160px">
                <v-progress-linear :model-value="usagePct(u.id)" color="success" height="6" rounded />
                <div class="text-caption text-medium-emphasis mt-1">{{ usagePct(u.id) }}% of SKUs</div>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-pencil" variant="text" size="small" :to="`/inventory/units/${u.id}/edit`" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>

    <div v-if="filtered.length" class="d-flex flex-wrap align-center mt-3" style="gap:12px">
      <span class="text-caption text-medium-emphasis">
        Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filtered.length }}</strong>
      </span>
      <v-spacer />
      <div class="d-flex align-center" style="gap:6px">
        <span class="text-caption text-medium-emphasis">Per page</span>
        <v-select v-model="pageSize" :items="[10, 25, 50, 100]" density="compact" variant="outlined" rounded="lg" hide-details style="width:92px" />
      </div>
      <v-pagination v-if="totalPages > 1" v-model="page" :length="totalPages" :total-visible="5" density="comfortable" rounded="lg" color="primary" />
    </div>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted, watch } from 'vue'
import { useResource } from '~/composables/useResource'

const unitRes = useResource('/inventory/units/')
const stockRes = useResource('/inventory/stocks/')

const units = computed(() => unitRes.items.value || [])
const stocks = computed(() => stockRes.items.value || [])
const loading = computed(() => unitRes.loading.value || stockRes.loading.value)

const search = ref('')
const page = ref(1)
const pageSize = ref(25)

const filtered = computed(() => {
  const s = search.value.trim().toLowerCase()
  if (!s) return units.value
  return units.value.filter(u =>
    (u.name || '').toLowerCase().includes(s) ||
    (u.abbreviation || u.symbol || '').toLowerCase().includes(s)
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

function countByUnit(id) { return stocks.value.filter(s => s.unit === id).length }
function unitsByUnit(id) { return stocks.value.filter(s => s.unit === id).reduce((sum, s) => sum + Number(s.total_quantity || 0), 0) }
function usagePct(id) {
  const total = stocks.value.length || 1
  return Math.round((countByUnit(id) / total) * 100)
}
const skusWithUnits = computed(() => stocks.value.filter(s => s.unit).length)
const skusWithoutUnit = computed(() => stocks.value.filter(s => !s.unit).length)
const totalOnHand = computed(() => stocks.value.reduce((sum, s) => sum + Number(s.total_quantity || 0), 0))

function reload() {
  unitRes.list({ page_size: 2000 })
  stockRes.list({ page_size: 5000 })
}
onMounted(reload)
</script>

<style scoped>
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
