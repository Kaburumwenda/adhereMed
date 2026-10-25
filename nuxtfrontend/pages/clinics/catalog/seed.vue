<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero header -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="teal-darken-2" size="32">mdi-database-import</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Catalog Seed Data</div>
              <div class="text-body-2" style="opacity:0.9">
                Populate your clinic catalog with default reference data — categories &amp; units.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0">
          <v-btn variant="flat" color="white" prepend-icon="mdi-refresh" class="text-teal-darken-3"
                 :loading="loading" @click="loadCatalog">Refresh</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Info alert -->
    <v-alert type="info" variant="tonal" rounded="xl" class="mb-4" closable>
      All seed commands are <strong>idempotent</strong> — safe to re-run. Existing records won't be duplicated.
    </v-alert>

    <!-- Seed cards -->
    <v-row>
      <v-col v-for="seed in seeds" :key="seed.key" cols="12" md="6" lg="4">
        <v-card rounded="xl" elevation="0" border class="fill-height d-flex flex-column">
          <v-card-item>
            <template #prepend>
              <v-avatar :color="iconFor(seed.key).color" variant="tonal" rounded="lg" size="44">
                <v-icon>{{ iconFor(seed.key).icon }}</v-icon>
              </v-avatar>
            </template>
            <v-card-title class="font-weight-bold">{{ seed.label }}</v-card-title>
            <v-card-subtitle class="text-wrap">{{ seed.description }}</v-card-subtitle>
          </v-card-item>

          <v-spacer />

          <v-card-actions class="pa-4 pt-0">
            <v-chip v-if="results[seed.key] === 'success'" color="success" variant="tonal" size="small"
                    prepend-icon="mdi-check-circle">
              Seeded
            </v-chip>
            <v-chip v-else-if="results[seed.key] === 'error'" color="error" variant="tonal" size="small"
                    prepend-icon="mdi-alert-circle">
              Failed
            </v-chip>
            <v-chip v-else-if="lastRunByKey[seed.key]" size="small" variant="tonal"
                    :color="lastRunByKey[seed.key].status === 'success' ? 'success' : 'error'"
                    prepend-icon="mdi-history">
              {{ formatWhen(lastRunByKey[seed.key].created_at) }}
            </v-chip>
            <v-spacer />
            <v-btn color="primary" variant="flat" rounded="lg" class="text-none"
                   prepend-icon="mdi-play"
                   :loading="busy[seed.key]"
                   :disabled="anyBusy"
                   @click="confirmSeed(seed)">
              Seed
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>
    </v-row>

    <!-- Empty state -->
    <v-card v-if="!loading && !seeds.length" rounded="xl" elevation="0" border class="pa-8 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-database-off</v-icon>
      <div class="text-h6 mt-3 text-grey">No seed commands available</div>
      <div class="text-body-2 text-grey-darken-1">Contact your administrator if you expected setup options here.</div>
    </v-card>

    <!-- Run history (persisted server-side) -->
    <v-card flat rounded="xl" border class="mt-6">
      <div class="d-flex flex-wrap align-center pa-4 ga-2">
        <v-icon color="grey" class="mr-2">mdi-history</v-icon>
        <div>
          <div class="text-subtitle-1 font-weight-bold">Run history</div>
          <div class="text-caption text-medium-emphasis">
            Saved to this clinic — survives page reloads
          </div>
        </div>
        <v-spacer />
        <v-chip v-if="historyCount" size="small" variant="tonal" color="primary">
          {{ historyCount }} run{{ historyCount === 1 ? '' : 's' }}
        </v-chip>
        <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-refresh"
               :loading="historyLoading" @click="loadHistory">Refresh</v-btn>
        <v-btn size="small" variant="text" class="text-none" color="error"
               prepend-icon="mdi-trash-can-outline" :disabled="!history.length"
               @click="clearDialog = true">Clear</v-btn>
      </div>
      <v-divider />

      <div v-if="historyLoading && !history.length" class="d-flex justify-center pa-8">
        <v-progress-circular indeterminate color="primary" size="28" />
      </div>

      <v-list v-else-if="history.length" density="compact" class="pa-0">
        <v-list-item v-for="h in history" :key="h.id">
          <template #prepend>
            <v-avatar :color="historyColor(h)" variant="tonal" rounded="lg" size="34" class="mr-3">
              <v-icon size="18">{{ historyIcon(h) }}</v-icon>
            </v-avatar>
          </template>
          <v-list-item-title class="text-body-2 font-weight-medium">
            {{ h.label || h.command_key }}
          </v-list-item-title>
          <v-list-item-subtitle class="text-caption">
            {{ formatWhen(h.created_at) }}
            <template v-if="h.run_by_label"> · {{ h.run_by_label }}</template>
            <template v-if="h.duration_ms"> · {{ formatDuration(h.duration_ms) }}</template>
            <template v-if="h.records_created"> · {{ h.records_created }} created</template>
          </v-list-item-subtitle>
          <template #append>
            <v-chip size="x-small" :color="historyColor(h)" variant="tonal">
              {{ h.status === 'success' ? 'OK' : 'Failed' }}
            </v-chip>
            <v-tooltip v-if="h.detail" location="left" max-width="360">
              <template #activator="{ props }">
                <v-icon v-bind="props" size="16" class="ml-2 text-medium-emphasis">mdi-information-outline</v-icon>
              </template>
              <span class="text-caption">{{ h.detail }}</span>
            </v-tooltip>
          </template>
        </v-list-item>
      </v-list>

      <div v-else class="text-center pa-8 text-medium-emphasis">
        <v-icon size="40" color="grey-lighten-1">mdi-history</v-icon>
        <div class="text-body-2 mt-2">No seed runs recorded yet</div>
        <div class="text-caption">Run a seed above and it will be saved here automatically.</div>
      </div>
    </v-card>

    <!-- Clear history dialog -->
    <v-dialog v-model="clearDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="error" variant="tonal" size="44">
              <v-icon>mdi-trash-can-outline</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Clear run history?</v-card-title>
        </v-card-item>
        <v-card-text class="text-body-2 text-medium-emphasis">
          This permanently deletes all {{ historyCount }} recorded seed run
          {{ historyCount === 1 ? 'entry' : 'entries' }} for this clinic.
          Seeded data itself is not affected.
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="clearDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" prepend-icon="mdi-delete"
                 :loading="clearing" @click="clearHistory">Clear history</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed confirmation dialog -->
    <v-dialog v-model="confirmDialog" max-width="480">
      <v-card v-if="confirmTarget" rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar :color="iconFor(confirmTarget.key).color" variant="tonal" size="44">
              <v-icon>{{ iconFor(confirmTarget.key).icon }}</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Seed {{ confirmTarget.label }}?</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-alert type="info" variant="tonal" rounded="lg" class="mb-3">
            <div class="text-body-2">{{ confirmTarget.description }}</div>
          </v-alert>
          <ul class="text-body-2 text-medium-emphasis pl-4">
            <li>This will populate your clinic catalog with default reference data.</li>
            <li>Existing records will <strong>not</strong> be duplicated (safe to re-run).</li>
            <li>The process may take a few seconds to complete.</li>
          </ul>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="confirmDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" prepend-icon="mdi-play"
                 @click="confirmDialog = false; runSeed(confirmTarget.key)">
            Proceed
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack" :color="snackColor" timeout="4000" rounded="pill" location="bottom">
      {{ snackText }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()

const loading = ref(false)
const seeds = ref([])
const busy = ref({})
const results = ref({})

// ── Persisted run history (server-side) ──────────────────────────────
const history = ref([])
const historyCount = ref(0)
const historyLoading = ref(false)
const clearDialog = ref(false)
const clearing = ref(false)

const snack = ref(false)
const snackText = ref('')
const snackColor = ref('success')

const anyBusy = computed(() => Object.values(busy.value).some(Boolean))

// Most recent run per seed key — drives the "last seeded" chip on each card.
const lastRunByKey = computed(() => {
  const map = {}
  for (const run of history.value) {
    if (!map[run.command_key]) map[run.command_key] = run
  }
  return map
})

const confirmDialog = ref(false)
const confirmTarget = ref(null)
function confirmSeed(seed) {
  confirmTarget.value = seed
  confirmDialog.value = true
}

const ICONS = {
  categories_units: { icon: 'mdi-shape', color: 'purple' },
  allergies: { icon: 'mdi-alert-octagon', color: 'red' },
  chronic_conditions: { icon: 'mdi-heart-pulse', color: 'blue' },
}

function iconFor(key) {
  return ICONS[key] || { icon: 'mdi-database', color: 'grey' }
}

async function loadCatalog() {
  loading.value = true
  try {
    const { data } = await $api.get('/inventory/catalog/seed/')
    seeds.value = data
  } catch {
    showSnack('Failed to load seed catalog', 'error')
  } finally {
    loading.value = false
  }
}

async function runSeed(key) {
  const seed = seeds.value.find(s => s.key === key)
  busy.value[key] = true
  results.value[key] = null
  try {
    const { data } = await $api.post('/inventory/catalog/seed/run/', { command: key })
    results.value[key] = 'success'
    const created = data?.records_created
    showSnack(
      `${seed?.label || key} seeded successfully${created ? ` — ${created} new record${created === 1 ? '' : 's'}` : ''}!`,
      'success',
    )
  } catch (e) {
    results.value[key] = 'error'
    showSnack(e.response?.data?.detail || 'Seed failed', 'error')
  } finally {
    busy.value[key] = false
    // The backend records every attempt — reload so the saved history is current.
    await loadHistory()
  }
}

async function loadHistory() {
  historyLoading.value = true
  try {
    const { data } = await $api.get('/inventory/catalog/seed/history/', {
      params: { limit: 25 },
    })
    history.value = data?.results || []
    historyCount.value = data?.count ?? history.value.length
  } catch {
    // Non-fatal — the page still works without history.
  } finally {
    historyLoading.value = false
  }
}

async function clearHistory() {
  clearing.value = true
  try {
    await $api.delete('/inventory/catalog/seed/history/')
    clearDialog.value = false
    showSnack('Run history cleared', 'success')
    await loadHistory()
  } catch (e) {
    showSnack(e.response?.data?.detail || 'Failed to clear history', 'error')
  } finally {
    clearing.value = false
  }
}

// ── History presentation helpers ─────────────────────────────────────
function historyColor(h) {
  return h.status === 'success' ? 'success' : 'error'
}

function historyIcon(h) {
  return h.status === 'success' ? 'mdi-check-circle' : 'mdi-close-circle'
}

function formatWhen(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d)) return iso
  const diffMin = Math.round((Date.now() - d.getTime()) / 60000)
  if (diffMin < 1) return 'Just now'
  if (diffMin < 60) return `${diffMin}m ago`
  if (diffMin < 1440) return `${Math.floor(diffMin / 60)}h ago`
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' }) +
         ' · ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

function formatDuration(ms) {
  if (!ms) return ''
  return ms < 1000 ? `${ms} ms` : `${(ms / 1000).toFixed(1)} s`
}

function showSnack(text, color = 'success') {
  snackText.value = text
  snackColor.value = color
  snack.value = true
}

onMounted(() => {
  loadCatalog()
  loadHistory()
})
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #00897B 0%, #26A69A 100%);
}
</style>
