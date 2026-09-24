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
              <div class="text-h5 text-md-h4 font-weight-bold">Pharmacy Setup</div>
              <div class="text-body-2" style="opacity:0.9">
                Seed default data for your new pharmacy — categories, units, medications &amp; stock.
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

    <!-- Run history -->
    <v-card v-if="history.length" flat rounded="xl" border class="mt-6">
      <div class="d-flex align-center pa-4">
        <v-icon color="grey" class="mr-2">mdi-history</v-icon>
        <div class="text-subtitle-1 font-weight-bold">Run history (this session)</div>
      </div>
      <v-divider />
      <v-list density="compact" class="pa-0">
        <v-list-item v-for="(h, i) in history" :key="i">
          <template #prepend>
            <v-icon :color="h.success ? 'success' : 'error'" size="small">
              {{ h.success ? 'mdi-check-circle' : 'mdi-close-circle' }}
            </v-icon>
          </template>
          <v-list-item-title class="text-body-2">{{ h.label }}</v-list-item-title>
          <v-list-item-subtitle class="text-caption">{{ h.time }}</v-list-item-subtitle>
          <template #append>
            <v-chip size="x-small" :color="h.success ? 'success' : 'error'" variant="tonal">
              {{ h.success ? 'OK' : 'Failed' }}
            </v-chip>
          </template>
        </v-list-item>
      </v-list>
    </v-card>

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
            <li>This will populate your pharmacy with default reference data.</li>
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
import { useNuxtApp } from '#app'

const { $api } = useNuxtApp()
// Inventory tenants use their own /ims API namespace.
const { setupSeed: setupSeedApi, setupSeedRun: setupSeedRunApi } = useTenantEndpoints()

const loading = ref(false)
const seeds = ref([])
const busy = ref({})
const results = ref({})
const history = ref([])

const snack = ref(false)
const snackText = ref('')
const snackColor = ref('success')

const anyBusy = computed(() => Object.values(busy.value).some(Boolean))

const confirmDialog = ref(false)
const confirmTarget = ref(null)
function confirmSeed(seed) {
  confirmTarget.value = seed
  confirmDialog.value = true
}

const ICONS = {
  categories_units: { icon: 'mdi-shape', color: 'purple' },
  medications: { icon: 'mdi-pill', color: 'blue' },
  interactions: { icon: 'mdi-swap-horizontal-circle', color: 'orange' },
}

function iconFor(key) {
  return ICONS[key] || { icon: 'mdi-database', color: 'grey' }
}

async function loadCatalog() {
  loading.value = true
  try {
    const { data } = await $api.get(setupSeedApi.value)
    seeds.value = data
  } catch (e) {
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
    await $api.post(setupSeedRunApi.value, { command: key })
    results.value[key] = 'success'
    history.value.unshift({
      label: seed?.label || key,
      success: true,
      time: new Date().toLocaleTimeString(),
    })
    showSnack(`${seed?.label || key} seeded successfully!`, 'success')
  } catch (e) {
    results.value[key] = 'error'
    history.value.unshift({
      label: seed?.label || key,
      success: false,
      time: new Date().toLocaleTimeString(),
    })
    showSnack(e.response?.data?.detail || 'Seed failed', 'error')
  } finally {
    busy.value[key] = false
  }
}

function showSnack(text, color = 'success') {
  snackText.value = text
  snackColor.value = color
  snack.value = true
}

onMounted(loadCatalog)
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #00897B 0%, #26A69A 100%);
}
</style>
