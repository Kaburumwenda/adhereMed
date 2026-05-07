<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Seed Data"
      icon="mdi-database-import"
      subtitle="Populate the database with reference data and demo content"
    >
      <template #actions>
        <v-btn
          variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-refresh"
          :loading="loadingCatalog"
          @click="loadAll"
        >
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <!-- Stats -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <v-card rounded="xl" elevation="0" class="stat-card">
          <div class="d-flex align-center pa-4">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="44" class="mr-3">
              <v-icon>mdi-database</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Available seeders</div>
              <div class="text-h5 font-weight-bold">{{ seeds.length }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="xl" elevation="0" class="stat-card">
          <div class="d-flex align-center pa-4">
            <v-avatar color="info" variant="tonal" rounded="lg" size="44" class="mr-3">
              <v-icon>mdi-earth</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Public seeders</div>
              <div class="text-h5 font-weight-bold">{{ publicCount }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="xl" elevation="0" class="stat-card">
          <div class="d-flex align-center pa-4">
            <v-avatar color="success" variant="tonal" rounded="lg" size="44" class="mr-3">
              <v-icon>mdi-domain</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Tenant seeders</div>
              <div class="text-h5 font-weight-bold">{{ tenantCount }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="xl" elevation="0" class="stat-card">
          <div class="d-flex align-center pa-4">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="44" class="mr-3">
              <v-icon>mdi-history</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Runs this session</div>
              <div class="text-h5 font-weight-bold">{{ history.length }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row>
      <!-- Seeders list -->
      <v-col cols="12" lg="7">
        <v-card rounded="xl" elevation="0" class="section-card">
          <div class="d-flex align-center pa-4">
            <v-icon color="primary" class="mr-2">mdi-format-list-checkbox</v-icon>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Available seeders</div>
              <div class="text-caption text-medium-emphasis">All commands are idempotent — safe to re-run.</div>
            </div>
            <v-spacer />
            <v-btn
              color="primary" rounded="lg" class="text-none"
              prepend-icon="mdi-play-speed"
              :disabled="!selected.length || running"
              :loading="batchRunning"
              @click="runBatch"
            >
              Run selected ({{ selected.length }})
            </v-btn>
          </div>
          <v-divider />

          <v-progress-linear v-if="loadingCatalog" color="primary" indeterminate height="3" />

          <v-list v-if="seeds.length" class="pa-0" lines="three">
            <template v-for="(s, i) in seeds" :key="s.key">
              <v-list-item class="seed-row" :disabled="busy[s.key]">
                <template #prepend>
                  <v-checkbox-btn
                    :model-value="selected.includes(s.key)"
                    @update:model-value="toggleSelect(s.key)"
                  />
                  <v-avatar :color="iconFor(s).color" variant="tonal" rounded="lg" size="40" class="mr-3">
                    <v-icon>{{ iconFor(s).icon }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="d-flex align-center">
                  <span class="font-weight-medium">{{ s.label }}</span>
                  <v-chip
                    size="x-small" class="ml-2"
                    :color="s.scope === 'tenant' ? 'success' : 'info'"
                    variant="tonal"
                  >
                    {{ s.scope === 'tenant' ? 'tenant-scoped' : 'public' }}
                  </v-chip>
                  <v-chip v-if="s.supports_reset || s.supports_clear" size="x-small" class="ml-2" variant="outlined" color="warning">
                    destructive supported
                  </v-chip>
                </v-list-item-title>
                <v-list-item-subtitle class="mt-1">{{ s.description }}</v-list-item-subtitle>

                <template #append>
                  <v-btn
                    color="primary" variant="tonal" rounded="lg" class="text-none mr-2"
                    prepend-icon="mdi-play"
                    size="small"
                    :loading="busy[s.key]"
                    :disabled="running"
                    @click="openRun(s)"
                  >
                    Run
                  </v-btn>
                </template>
              </v-list-item>
              <v-divider v-if="i < seeds.length - 1" />
            </template>
          </v-list>

          <div v-else-if="!loadingCatalog" class="pa-8 text-center text-medium-emphasis">
            No seeders are exposed by the API.
          </div>
        </v-card>

        <!-- Batch settings -->
        <v-card rounded="xl" elevation="0" class="section-card mt-4">
          <div class="pa-4">
            <div class="d-flex align-center mb-3">
              <v-icon color="warning" class="mr-2">mdi-tune-variant</v-icon>
              <div class="text-subtitle-1 font-weight-bold">Batch defaults</div>
            </div>
            <v-row dense>
              <v-col cols="12" md="6">
                <v-select
                  v-model="batchTenant"
                  :items="tenantOptions"
                  item-title="label" item-value="value"
                  label="Default tenant for tenant-scoped seeders"
                  variant="outlined" density="comfortable" hide-details
                  prepend-inner-icon="mdi-domain"
                  clearable
                />
              </v-col>
              <v-col cols="12" md="6" class="d-flex align-center">
                <v-switch
                  v-model="batchAllTenants"
                  label="Run on every active tenant"
                  color="primary" inset hide-details
                />
              </v-col>
              <v-col cols="12">
                <v-switch
                  v-model="batchReset"
                  label="Pass destructive flag (--reset / --clear) where supported"
                  color="error" inset hide-details
                />
              </v-col>
            </v-row>
          </div>
        </v-card>
      </v-col>

      <!-- Quick actions + history -->
      <v-col cols="12" lg="5">
        <v-card rounded="xl" elevation="0" class="section-card">
          <div class="pa-4 d-flex align-center">
            <v-icon color="purple" class="mr-2">mdi-flash</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Quick actions</div>
          </div>
          <v-divider />
          <v-list class="pa-0">
            <v-list-item
              v-for="qa in quickActions" :key="qa.label"
              class="quick-row"
              @click="qa.run"
            >
              <template #prepend>
                <v-avatar :color="qa.color" variant="tonal" rounded="lg" size="40" class="mr-3">
                  <v-icon>{{ qa.icon }}</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-medium">{{ qa.label }}</v-list-item-title>
              <v-list-item-subtitle>{{ qa.desc }}</v-list-item-subtitle>
              <template #append>
                <v-btn icon="mdi-arrow-right" variant="text" size="small" />
              </template>
            </v-list-item>
          </v-list>
        </v-card>

        <v-card rounded="xl" elevation="0" class="section-card mt-4">
          <div class="pa-4 d-flex align-center">
            <v-icon color="info" class="mr-2">mdi-clipboard-text-clock</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Run history</div>
            <v-spacer />
            <v-btn
              v-if="history.length"
              variant="text" size="small" rounded="lg" class="text-none"
              prepend-icon="mdi-eraser"
              @click="history = []"
            >
              Clear
            </v-btn>
          </div>
          <v-divider />
          <div v-if="!history.length" class="pa-6 text-center text-caption text-medium-emphasis">
            Nothing run yet in this session.
          </div>
          <v-list v-else class="pa-0" density="compact">
            <template v-for="(h, i) in history" :key="i">
              <v-list-item>
                <template #prepend>
                  <v-icon :color="h.ok ? 'success' : 'error'" class="mr-3">
                    {{ h.ok ? 'mdi-check-circle' : 'mdi-alert-circle' }}
                  </v-icon>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">{{ h.label }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ h.scope === 'tenant' ? (h.tenant || 'all tenants') : 'public' }}
                  · {{ h.duration }}ms · {{ h.ts }}
                </v-list-item-subtitle>
                <template v-if="h.message" #append>
                  <v-tooltip :text="h.message" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-information-outline" variant="text" size="small" />
                    </template>
                  </v-tooltip>
                </template>
              </v-list-item>
              <v-divider v-if="i < history.length - 1" />
            </template>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Run dialog -->
    <v-dialog v-model="runDialog" max-width="520" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-avatar :color="iconFor(runTarget || {}).color" variant="tonal" rounded="lg" size="40" class="mr-3">
            <v-icon>{{ iconFor(runTarget || {}).icon }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-subtitle-1 font-weight-bold">Run {{ runTarget?.label }}</div>
            <div class="text-caption text-medium-emphasis">{{ runTarget?.description }}</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-alert v-if="runTarget?.scope === 'tenant'" type="info" variant="tonal" density="comfortable" class="mb-3">
            This is a tenant-scoped seeder. Pick the target tenant or run on all active tenants.
          </v-alert>

          <v-select
            v-if="runTarget?.scope === 'tenant' && !runAll"
            v-model="runTenant"
            :items="tenantOptions"
            item-title="label" item-value="value"
            label="Tenant"
            variant="outlined" density="comfortable" hide-details
            prepend-inner-icon="mdi-domain"
            class="mb-3"
          />

          <v-switch
            v-if="runTarget?.scope === 'tenant'"
            v-model="runAll"
            label="Run on every active tenant"
            color="primary" inset hide-details class="mb-2"
          />

          <v-switch
            v-if="runTarget?.supports_reset || runTarget?.supports_clear"
            v-model="runReset"
            :label="runTarget?.supports_reset ? 'Reset existing data first (destructive)' : 'Clear existing data first (destructive)'"
            color="error" inset hide-details
          />

          <v-alert v-if="runReset" type="warning" variant="tonal" density="comfortable" class="mt-3">
            <strong>Heads up:</strong> existing records will be deleted before the seed runs.
          </v-alert>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="running" @click="runDialog = false">Cancel</v-btn>
          <v-btn
            color="primary" rounded="lg" class="text-none"
            prepend-icon="mdi-play"
            :loading="running"
            :disabled="runTarget?.scope === 'tenant' && !runAll && !runTenant"
            @click="confirmRun"
          >
            Run seeder
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" timeout="4000" location="bottom right" rounded="pill">
      <v-icon class="mr-2">{{ snack.icon }}</v-icon>
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()
const router = useRouter()

const seeds = ref([])
const tenants = ref([])
const loadingCatalog = ref(false)
const busy = reactive({})
const running = ref(false)
const batchRunning = ref(false)

const selected = ref([])
const history = ref([])

const batchTenant = ref(null)
const batchAllTenants = ref(false)
const batchReset = ref(false)

const runDialog = ref(false)
const runTarget = ref(null)
const runTenant = ref(null)
const runAll = ref(false)
const runReset = ref(false)

const snack = ref({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })

const ICONS = {
  medications: { icon: 'mdi-pill', color: 'info' },
  clinical_catalog: { icon: 'mdi-medical-bag', color: 'primary' },
  pharmacy_stock: { icon: 'mdi-package-variant', color: 'success' },
  lab_tests: { icon: 'mdi-test-tube', color: 'purple' }
}

function iconFor(s) {
  return ICONS[s.key] || { icon: 'mdi-database', color: 'primary' }
}

const tenantOptions = computed(() => tenants.value.map(t => ({
  label: `${t.name}${t.type ? ` · ${t.type}` : ''}`,
  value: t.id
})))

const publicCount = computed(() => seeds.value.filter(s => s.scope === 'public').length)
const tenantCount = computed(() => seeds.value.filter(s => s.scope === 'tenant').length)

const quickActions = [
  {
    label: 'Seed everything (public)',
    desc: 'Run all public-scoped seeders in order',
    icon: 'mdi-earth',
    color: 'info',
    run: () => seedScope('public')
  },
  {
    label: 'Seed everything (active tenants)',
    desc: 'Run all tenant seeders for every active tenant',
    icon: 'mdi-domain',
    color: 'success',
    run: () => seedScope('tenant')
  },
  {
    label: 'Open Catalog Manager',
    desc: 'Browse the data you just seeded',
    icon: 'mdi-bookshelf',
    color: 'purple',
    run: () => router.push('/admin/catalog')
  },
  {
    label: 'Open Tenants',
    desc: 'Manage tenants & schemas',
    icon: 'mdi-domain',
    color: 'primary',
    run: () => router.push('/superadmin/tenants')
  }
]

function notify(text, color = 'success', icon = 'mdi-check-circle') {
  snack.value = { show: true, text, color, icon }
}

function toggleSelect(key) {
  if (selected.value.includes(key)) {
    selected.value = selected.value.filter(k => k !== key)
  } else {
    selected.value.push(key)
  }
}

async function loadCatalog() {
  loadingCatalog.value = true
  try {
    const { data } = await $api.get('/superadmin/seed/')
    seeds.value = data || []
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to load seeders', 'error', 'mdi-alert')
  } finally {
    loadingCatalog.value = false
  }
}

async function loadTenants() {
  try {
    const { data } = await $api.get('/tenants/', { params: { page_size: 200 } })
    const list = data?.results ?? data ?? []
    tenants.value = list.filter(t => t.schema_name && t.schema_name !== 'public')
  } catch (e) {
    /* non-fatal */
  }
}

async function loadAll() {
  await Promise.all([loadCatalog(), loadTenants()])
}

function openRun(s) {
  runTarget.value = s
  runTenant.value = batchTenant.value
  runAll.value = batchAllTenants.value && s.scope === 'tenant'
  runReset.value = false
  runDialog.value = true
}

function pushHistory(entry) {
  history.value = [entry, ...history.value].slice(0, 25)
}

async function runOne(s, { tenantId = null, allTenants = false, reset = false } = {}) {
  busy[s.key] = true
  const started = performance.now()
  try {
    const payload = { command: s.key, reset }
    if (s.scope === 'tenant') {
      if (allTenants) payload.all_tenants = true
      else if (tenantId) payload.tenant_id = tenantId
      else throw new Error('Tenant required')
    }
    const { data } = await $api.post('/superadmin/seed/run/', payload)
    pushHistory({
      key: s.key, label: s.label, scope: s.scope,
      tenant: tenants.value.find(t => t.id === tenantId)?.name || (allTenants ? null : null),
      ok: true, message: data?.detail || 'Done',
      duration: Math.round(performance.now() - started),
      ts: new Date().toLocaleTimeString()
    })
    notify(data?.detail || `${s.label} seeded`)
    return true
  } catch (e) {
    const msg = e?.response?.data?.detail || e?.message || 'Seed failed'
    pushHistory({
      key: s.key, label: s.label, scope: s.scope,
      tenant: tenants.value.find(t => t.id === tenantId)?.name || null,
      ok: false, message: msg,
      duration: Math.round(performance.now() - started),
      ts: new Date().toLocaleTimeString()
    })
    notify(msg, 'error', 'mdi-alert')
    return false
  } finally {
    busy[s.key] = false
  }
}

async function confirmRun() {
  if (!runTarget.value) return
  running.value = true
  await runOne(runTarget.value, {
    tenantId: runTenant.value,
    allTenants: runAll.value,
    reset: runReset.value
  })
  running.value = false
  runDialog.value = false
}

async function runBatch() {
  if (!selected.value.length) return
  batchRunning.value = true
  running.value = true
  try {
    for (const key of selected.value) {
      const s = seeds.value.find(x => x.key === key)
      if (!s) continue
      await runOne(s, {
        tenantId: batchTenant.value,
        allTenants: batchAllTenants.value && s.scope === 'tenant',
        reset: batchReset.value
      })
    }
    selected.value = []
  } finally {
    batchRunning.value = false
    running.value = false
  }
}

async function seedScope(scope) {
  const targets = seeds.value.filter(s => s.scope === scope)
  if (!targets.length) {
    notify(`No ${scope} seeders available`, 'info', 'mdi-information')
    return
  }
  if (scope === 'tenant' && !tenants.value.length) {
    notify('No active tenants', 'warning', 'mdi-alert')
    return
  }
  running.value = true
  try {
    for (const s of targets) {
      await runOne(s, {
        allTenants: scope === 'tenant',
        reset: false
      })
    }
  } finally {
    running.value = false
  }
}

onMounted(loadAll)
</script>

<style scoped>
.stat-card,
.section-card {
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.04) !important;
}
.seed-row { padding: 14px 16px; }
.quick-row { cursor: pointer; }
.quick-row:hover { background: rgba(var(--v-theme-primary), 0.04); }
</style>
