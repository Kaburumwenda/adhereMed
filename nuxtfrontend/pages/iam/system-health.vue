<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar :color="statusColor + '-lighten-5'" size="48" class="mr-3">
          <v-icon :color="statusColor + '-darken-2'" size="28">mdi-heart-pulse</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">System Health</h1>
          <div class="text-body-2 text-medium-emphasis">
            {{ tenantName }} · {{ tenantSchema }} · Last checked {{ checkedAt }}
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-3" />

    <!-- Overall health banner -->
    <v-card flat rounded="xl" class="mb-4 pa-5" :color="statusColor + '-lighten-5'" border>
      <div class="d-flex align-center flex-wrap ga-4">
        <v-progress-circular :model-value="score" :size="80" :width="6"
                             :color="statusColor" class="mr-2">
          <span class="text-h6 font-weight-bold">{{ score }}</span>
        </v-progress-circular>
        <div class="flex-grow-1">
          <div class="d-flex align-center ga-2 mb-1">
            <v-icon :color="statusColor" size="24">{{ statusIcon }}</v-icon>
            <span class="text-h6 font-weight-bold" :class="'text-' + statusColor">{{ statusLabel }}</span>
          </div>
          <div class="text-body-2 text-medium-emphasis" v-if="issues.length">
            {{ issues.length }} issue(s) detected: {{ issues.join('; ') }}
          </div>
          <div class="text-body-2 text-medium-emphasis" v-else>
            All systems operating normally.
          </div>
        </div>
      </div>
    </v-card>

    <!-- KPI tiles -->
    <v-row dense class="mb-3">
      <!-- DB latency -->
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Database</div>
              <div class="text-h5 font-weight-bold mt-1" :class="'text-' + (dbOk ? 'success' : 'error')">
                {{ dbStatus }}
              </div>
              <div class="text-caption text-medium-emphasis mt-1">{{ dbLatency }}ms · {{ dbEngine }}</div>
            </div>
            <v-avatar size="40" :color="dbOk ? 'success' : 'error'" variant="tonal">
              <v-icon>mdi-database-check</v-icon>
            </v-avatar>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">{{ tableCount }} tables</div>
        </v-card>
      </v-col>

      <!-- Users -->
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Users</div>
              <div class="text-h5 font-weight-bold mt-1 text-primary">{{ userTotal }}</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ userActive }} active · {{ userStaff }} staff</div>
            </div>
            <v-avatar size="40" color="primary" variant="tonal">
              <v-icon>mdi-account-group</v-icon>
            </v-avatar>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">
            <v-icon size="12">mdi-clock</v-icon> {{ userActive24h }} active in last 24h
          </div>
        </v-card>
      </v-col>

      <!-- Stock -->
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Stock</div>
              <div class="text-h5 font-weight-bold mt-1" :class="stockColor">{{ stockHealthy }} healthy</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ stockLow }} low · {{ stockOut }} out · {{ stockExpired }} expired</div>
            </div>
            <v-avatar size="40" :color="stockColor" variant="tonal">
              <v-icon>mdi-package-variant-closed</v-icon>
            </v-avatar>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">
            <v-icon size="12" color="warning">mdi-clock-alert</v-icon> {{ stockExpiring }} expiring soon
          </div>
        </v-card>
      </v-col>

      <!-- Sales -->
      <v-col cols="6" md="3">
        <v-card flat rounded="xl" class="pa-4 kpi-card h-100" :loading="loading" border>
          <div class="d-flex align-start">
            <div class="flex-grow-1">
              <div class="text-caption text-medium-emphasis text-uppercase">Sales (7d)</div>
              <div class="text-h5 font-weight-bold mt-1 text-success">{{ sales7d }}</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ formatMoney(salesRevenue7d) }} revenue</div>
            </div>
            <v-avatar size="40" color="success" variant="tonal">
              <v-icon>mdi-cart-check</v-icon>
            </v-avatar>
          </div>
          <div class="text-caption text-medium-emphasis mt-2">
            <v-icon size="12">mdi-calendar-clock</v-icon> {{ sales24h }} in last 24h · {{ salesCancelled7d }} cancelled
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Services -->
    <v-card flat rounded="xl" class="mb-4" border>
      <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
        <v-icon class="mr-2" color="primary">mdi-server-network</v-icon>
        Service Status
      </v-card-title>
      <v-divider />
      <v-list density="comfortable">
        <v-list-item v-for="svc in services" :key="svc.name">
          <template #prepend>
            <v-avatar size="36" :color="svcColor(svc.status)" variant="tonal">
              <v-icon :color="svcColor(svc.status)">{{ svcIcon(svc.status) }}</v-icon>
            </v-avatar>
          </template>
          <v-list-item-title class="font-weight-medium">{{ svc.name }}</v-list-item-title>
          <v-list-item-subtitle>{{ svc.detail }}</v-list-item-subtitle>
          <template #append>
            <v-chip size="small" :color="svcColor(svc.status)" variant="tonal" label>
              {{ svcLabel(svc.status) }}
            </v-chip>
          </template>
        </v-list-item>
        <v-list-item v-if="!services.length">
          <v-list-item-title class="text-medium-emphasis">No services configured</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-card>

    <!-- User breakdown + Branch info -->
    <v-row dense>
      <v-col cols="12" md="7">
        <v-card flat rounded="xl" class="h-100" border>
          <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
            <v-icon class="mr-2" color="primary">mdi-account-group-outline</v-icon>
            User Role Distribution
          </v-card-title>
          <v-divider />
          <v-card-text>
            <div v-for="r in roleDistribution" :key="r.role" class="mb-2">
              <div class="d-flex align-center justify-space-between mb-1">
                <span class="text-body-2 font-weight-medium">{{ roleLabel(r.role) }}</span>
                <span class="text-body-2 text-medium-emphasis">{{ r.count }}</span>
              </div>
              <v-progress-linear :model-value="rolePercent(r.count)" height="6"
                                 color="primary" rounded />
            </div>
            <div v-if="!roleDistribution.length" class="text-medium-emphasis text-center pa-4">
              No user data available
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" md="5">
        <v-card flat rounded="xl" class="h-100" border>
          <v-card-title class="text-subtitle-1 font-weight-bold d-flex align-center">
            <v-icon class="mr-2" color="primary">mdi-store</v-icon>
            Branches
          </v-card-title>
          <v-divider />
          <v-card-text class="text-center pa-8">
            <div class="text-h3 font-weight-bold text-primary">{{ branchCount }}</div>
            <div class="text-caption text-medium-emphasis mt-1">Total branches</div>
          </v-card-text>
          <v-divider v-if="issues.length" />
          <v-card-text v-if="issues.length">
            <div class="text-subtitle-2 font-weight-bold mb-2">
              <v-icon size="16" color="warning">mdi-alert-circle</v-icon>
              Active Issues
            </div>
            <v-list density="compact" class="bg-transparent">
              <v-list-item v-for="(issue, i) in issues" :key="i" class="px-0">
                <template #prepend>
                  <v-icon size="16" color="warning">mdi-circle-medium</v-icon>
                </template>
                <v-list-item-title class="text-body-2">{{ issue }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useNuxtApp } from '#app'
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const data = ref(null)

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/superadmin/system-health/')
    data.value = res.data
  } catch (e) {
    console.error('Failed to load system health', e)
  } finally {
    loading.value = false
  }
}
onMounted(load)

// ── Computed properties ───────────────────────────────────────
const score = computed(() => data.value?.score ?? 0)
const statusLabel = computed(() => ({
  healthy: 'All Systems Healthy',
  warning: 'Attention Required',
  critical: 'Critical Issues',
}[data.value?.status] || 'Unknown'))
const statusColor = computed(() => ({
  healthy: 'success',
  warning: 'warning',
  critical: 'error',
}[data.value?.status] || 'grey'))
const statusIcon = computed(() => ({
  healthy: 'mdi-check-circle',
  warning: 'mdi-alert',
  critical: 'mdi-alert-octagon',
}[data.value?.status] || 'mdi-help-circle'))

const issues = computed(() => data.value?.issues || [])
const checkedAt = computed(() => {
  const d = data.value?.checked_at
  if (!d) return '—'
  return new Date(d).toLocaleString()
})

// Tenant
const tenantName = computed(() => data.value?.tenant?.name || '—')
const tenantSchema = computed(() => data.value?.tenant?.schema || '')

// Database
const dbOk = computed(() => data.value?.database?.status === 'healthy')
const dbStatus = computed(() => dbOk.value ? 'Healthy' : 'Error')
const dbLatency = computed(() => data.value?.database?.latency_ms ?? 0)
const dbEngine = computed(() => {
  const e = data.value?.database?.engine || ''
  return e.replace('_backend', '').toUpperCase()
})
const tableCount = computed(() => data.value?.database?.tables ?? 0)

// Users
const userTotal = computed(() => data.value?.users?.total ?? 0)
const userActive = computed(() => data.value?.users?.active ?? 0)
const userStaff = computed(() => data.value?.users?.staff ?? 0)
const userActive24h = computed(() => data.value?.users?.active_24h ?? 0)
const roleDistribution = computed(() => data.value?.users?.by_role || [])

function roleLabel(r) {
  return (r || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}
function rolePercent(count) {
  if (!userTotal.value) return 0
  return Math.round((count / userTotal.value) * 100)
}

// Stock
const stockHealthy = computed(() => data.value?.stock?.healthy ?? 0)
const stockLow = computed(() => data.value?.stock?.low_stock ?? 0)
const stockOut = computed(() => data.value?.stock?.out_of_stock ?? 0)
const stockExpired = computed(() => data.value?.stock?.expired ?? 0)
const stockExpiring = computed(() => data.value?.stock?.expiring_soon ?? 0)
const stockColor = computed(() => {
  if (stockExpired.value > 0 || stockOut.value > 100) return 'error'
  if (stockLow.value > 0) return 'warning'
  return 'success'
})

// Sales
const sales24h = computed(() => data.value?.sales?.last_24h ?? 0)
const sales7d = computed(() => data.value?.sales?.last_7d ?? 0)
const salesCancelled7d = computed(() => data.value?.sales?.cancelled_7d ?? 0)
const salesRevenue7d = computed(() => data.value?.sales?.revenue_7d ?? 0)

// Branches
const branchCount = computed(() => data.value?.branches?.count ?? 0)

// Services
const services = computed(() => data.value?.services || [])
function svcColor(s) {
  return { healthy: 'success', configured: 'success', eager: 'info',
           unreachable: 'error', not_configured: 'grey', smtp: 'success',
           console: 'info' }[s] || 'grey'
}
function svcIcon(s) {
  return { healthy: 'mdi-check-circle', configured: 'mdi-check-circle',
           eager: 'mdi-debug', unreachable: 'mdi-alert-circle',
           not_configured: 'mdi-cancel', smtp: 'mdi-email-check',
           console: 'mdi-console' }[s] || 'mdi-help-circle'
}
function svcLabel(s) {
  return (s || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}
</script>

<style scoped>
.kpi-card {
  transition: transform 0.15s ease;
}
.kpi-card:hover {
  transform: translateY(-2px);
}
</style>
