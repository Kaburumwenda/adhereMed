<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Demo Data" subtitle="Seed or clear demo data for this clinic"
      icon="mdi-database-plus" color="deep-purple">

      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none"
          prepend-icon="mdi-trash-can-outline" color="error"
          :loading="clearing" :disabled="clearing"
          @click="confirmClear = true">Clear Demo Data</v-btn>
      </template>
    </PageHeader>

    <!-- ── Summary cards ────────────────────────────────────────────── -->
    <v-row dense class="mb-4">
      <v-col v-for="card in summaryCards" :key="card.label" cols="6" md="4" lg="2">
        <v-card flat rounded="lg" variant="outlined" class="text-center pa-4">
          <v-icon :icon="card.icon" :color="card.color" size="32" class="mb-2" />
          <div class="text-h5 font-weight-bold">{{ card.count }}</div>
          <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Seed panel ────────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="mb-4">
      <v-card-item>
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-database-plus" color="deep-purple" class="mr-2" />
          Seed Demo Data
        </v-card-title>
        <v-card-subtitle>
          Populate this clinic with realistic demo records for testing and training.
          All demo users use the password <code class="text-primary">Demo@@12345</code>.
        </v-card-subtitle>
      </v-card-item>

      <v-card-text>
        <v-alert type="info" variant="tonal" rounded="lg" class="mb-4" prominent>
          <p class="text-body-2 mb-0">
            This will create demo records <strong>in the current tenant only</strong>.
            Existing data will not be affected. You can clear the demo data at any time
            using the "Clear Demo Data" button above.
          </p>
        </v-alert>

        <v-table density="comfortable" class="mb-4 rounded-lg border" v-if="!loading">
          <thead>
            <tr>
              <th>Record Type</th>
              <th class="text-center">Quantity</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in seedItems" :key="item.label">
              <td>
                <v-icon :icon="item.icon" size="small" :color="item.color" class="mr-2" />
                {{ item.label }}
              </td>
              <td class="text-center font-weight-bold">{{ item.count }}</td>
              <td class="text-medium-emphasis">{{ item.detail }}</td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>

      <v-card-actions class="px-4 pb-4">
        <v-spacer />
        <v-btn color="deep-purple" rounded="lg" size="large" class="text-none px-6"
          prepend-icon="mdi-database-plus" :loading="loading" :disabled="loading"
          @click="confirmSeed = true">
          Seed Demo Data
        </v-btn>
      </v-card-actions>
    </v-card>

    <!-- ── Equipment seed panel ───────────────────────────────────────── -->
    <v-card flat rounded="lg" variant="outlined" class="mb-4 eqseed">
      <v-card-item>
        <div class="eqseed-head">
          <div class="eqseed-title-wrap">
            <v-icon icon="mdi-cog-transfer" color="deep-purple" size="22" class="mr-2" />
            <div>
              <div class="eqseed-title">Equipment data</div>
              <div class="eqseed-sub">
                Reference categories are safe to run on a live clinic. The demo estate is for
                training and staging only.
              </div>
            </div>
          </div>

          <div class="eqseed-counts">
            <span class="eqseed-count">
              <b>{{ eqCounts.categories }}</b> categories
            </span>
            <span class="eqseed-count">
              <b>{{ eqCounts.assets }}</b> assets
            </span>
            <span class="eqseed-count">
              <b>{{ eqCounts.jobs }}</b> jobs
            </span>
            <span class="eqseed-count">
              <b>{{ eqCounts.faults }}</b> faults
            </span>
          </div>
        </div>
      </v-card-item>

      <v-card-text class="pt-0">
        <v-alert
          v-if="!eqCounts.assets"
          type="info"
          variant="tonal"
          density="compact"
          rounded="lg"
          class="mb-3"
        >
          No equipment registered yet. Seed the categories first, then add assets manually —
          or load the demo estate if this is a training environment.
        </v-alert>

        <div v-if="eqLoading" class="eqseed-loading">
          <v-progress-linear indeterminate color="deep-purple" rounded height="3" />
        </div>

        <div v-else class="eqseed-packs">
          <article
            v-for="pack in eqPacks"
            :key="pack.key"
            class="eqseed-pack"
            :class="{ 'is-demo': pack.creates_demo_assets }"
          >
            <div class="eqseed-pack-top">
              <span class="eqseed-pack-icon" :class="pack.creates_demo_assets ? 'is-demo' : 'is-safe'">
                <v-icon size="17">{{ pack.creates_demo_assets ? 'mdi-flask-outline' : 'mdi-shield-check-outline' }}</v-icon>
              </span>
              <div class="eqseed-pack-id">
                <div class="eqseed-pack-name">{{ pack.label }}</div>
                <span class="eqseed-badge" :class="pack.creates_demo_assets ? 'is-demo' : 'is-safe'">
                  {{ pack.creates_demo_assets ? 'Demo only' : 'Production safe' }}
                </span>
              </div>
            </div>

            <p class="eqseed-pack-desc">{{ pack.description }}</p>

            <div class="eqseed-pack-foot">
              <span class="eqseed-pack-meta">
                <v-icon size="13">{{ pack.creates_demo_assets ? 'mdi-alert-outline' : 'mdi-refresh' }}</v-icon>
                {{ pack.creates_demo_assets ? 'Adds fictional records' : 'Idempotent — safe to re-run' }}
              </span>
              <v-btn
                size="small"
                rounded="lg"
                class="text-none"
                :variant="pack.creates_demo_assets ? 'outlined' : 'flat'"
                :color="pack.creates_demo_assets ? 'deep-purple' : 'deep-purple'"
                :loading="eqRunning === pack.key"
                :disabled="!!eqRunning"
                :prepend-icon="pack.creates_demo_assets ? 'mdi-flask-outline' : 'mdi-database-plus'"
                @click="askSeedPack(pack)"
              >
                {{ pack.creates_demo_assets ? 'Load demo estate' : 'Seed categories' }}
              </v-btn>
            </div>
          </article>
        </div>

        <!-- Run history -->
        <div class="eqseed-history">
          <div class="eqseed-history-head">
            <span class="eqseed-history-title">Recent runs</span>
            <button
              v-if="eqHistory.length"
              type="button"
              class="eqseed-link"
              @click="clearEqHistory"
            >Clear history</button>
          </div>

          <div v-if="eqHistory.length" class="eqseed-history-list">
            <div v-for="run in eqHistory" :key="run.id" class="eqseed-run">
              <span class="eqseed-run-dot" :class="`is-${run.status}`" />
              <span class="eqseed-run-main">{{ run.label }}</span>
              <span class="eqseed-run-count">
                {{ run.records_created }} record{{ run.records_created === 1 ? '' : 's' }}
              </span>
              <span class="eqseed-run-by">{{ run.run_by_label || 'system' }}</span>
              <span class="eqseed-run-when">{{ eqRelative(run.created_at) }}</span>
            </div>
          </div>
          <div v-else class="eqseed-history-empty">No equipment seeds have run in this clinic yet.</div>
        </div>
      </v-card-text>
    </v-card>

    <!-- ── Confirm equipment seed dialog ─────────────────────────────── -->
    <v-dialog v-model="eqConfirm" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="eqTarget?.creates_demo_assets ? 'mdi-flask-outline' : 'mdi-database-plus'"
          :title="eqTarget?.label || 'Seed equipment'"
        />
        <v-card-text class="text-body-2">
          <template v-if="eqTarget?.creates_demo_assets">
            <v-alert type="warning" variant="tonal" density="compact" rounded="lg" class="mb-3">
              This creates <strong>44 fictional assets</strong>, maintenance history, faults and
              transfers. Do not run this on a live clinic — existing equipment will be untouched
              but the invented records will mix with real ones.
            </v-alert>
            <p class="mb-0">I understand this clinic is a demo or training environment.</p>
          </template>
          <template v-else>
            <p class="mb-2">
              This adds the equipment category catalogue (12 classes with servicing and
              calibration intervals).
            </p>
            <p class="mb-0 text-medium-emphasis">
              Existing categories are matched by code and left unchanged, so it is safe to re-run.
            </p>
          </template>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="eqConfirm = false">Cancel</v-btn>
          <v-btn
            :color="eqTarget?.creates_demo_assets ? 'warning' : 'deep-purple'"
            rounded="lg"
            class="text-none"
            :loading="!!eqRunning"
            :prepend-icon="eqTarget?.creates_demo_assets ? 'mdi-flask-outline' : 'mdi-database-plus'"
            @click="runEqSeed"
          >
            {{ eqTarget?.creates_demo_assets ? 'Load demo estate' : 'Seed categories' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Login credentials ─────────────────────────────────────────── -->
    <v-card flat rounded="lg" v-if="seedResult">
      <v-card-item>
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-check-circle" color="success" class="mr-2" />
          Demo Data Seeded Successfully
        </v-card-title>
      </v-card-item>
      <v-card-text>
        <v-table density="comfortable" class="rounded-lg border">
          <tbody>
            <tr v-for="(val, key) in seedResult.summary" :key="key">
              <td class="font-weight-medium text-capitalize">{{ key.replace('_', ' ') }}</td>
              <td class="font-weight-bold">{{ val }}</td>
            </tr>
          </tbody>
        </v-table>
        <v-alert type="success" variant="tonal" rounded="lg" class="mt-4">
          Demo users created with email pattern
          <code>demo.patient1@clinic.demo</code> ·
          <code>demo.doctor1@clinic.demo</code>
          (password: <code class="text-primary">Demo@@12345</code>)
        </v-alert>
      </v-card-text>
    </v-card>

    <!-- ── Confirm seed dialog ────────────────────────────────────────── -->
    <v-dialog v-model="confirmSeed" max-width="480">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-help-circle-outline" title="Confirm Seeding" />
        <v-card-text class="text-body-2">
          This will create <strong>5 doctors, 10 patients, 10 appointments,
          10 consultations, 5 prescriptions, and 5 lab orders</strong> in the current
          clinic. Continue?
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="confirmSeed = false">Cancel</v-btn>
          <v-btn color="deep-purple" rounded="lg" class="text-none"
            prepend-icon="mdi-database-plus" :loading="loading"
            @click="doSeed">Seed Data</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Confirm clear dialog ───────────────────────────────────────── -->
    <v-dialog v-model="confirmClear" max-width="480">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-alert-circle-outline" title="Confirm Clear" />
        <v-card-text class="text-body-2">
          This will permanently delete all demo data (patients with "DEMO" numbers,
          doctors with "@clinic.demo" emails, and related appointments, consultations,
          prescriptions, and lab orders). Continue?
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="confirmClear = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none"
            prepend-icon="mdi-trash-can" :loading="clearing"
            @click="doClear">Clear Data</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ───────────────────────────────────────────────────── -->
    <v-snackbar v-model="snackbar" :color="snackbarColor" :timeout="4000" location="top">
      {{ snackbarText }}
      <template #actions>
        <v-btn icon="mdi-close" variant="text" @click="snackbar = false" />
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()

const loading = ref(false)
const clearing = ref(false)
const confirmSeed = ref(false)
const confirmClear = ref(false)
const seedResult = ref(null)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('success')

const seedItems = [
  { label: 'Clinic Doctors', count: 5, icon: 'mdi-doctor', color: 'blue', detail: 'Doctor users with profiles' },
  { label: 'Patients', count: 10, icon: 'mdi-account-group', color: 'teal', detail: 'Patient users + records' },
  { label: 'Appointments', count: 10, icon: 'mdi-calendar-clock', color: 'orange', detail: 'Scheduled & completed' },
  { label: 'Consultations', count: 10, icon: 'mdi-stethoscope', color: 'purple', detail: 'With chief complaints' },
  { label: 'Prescriptions', count: 5, icon: 'mdi-pill-multiple', color: 'red', detail: 'With medication items' },
  { label: 'Lab Orders', count: 5, icon: 'mdi-test-tube', color: 'green', detail: 'With lab tests' },
]

const summaryCards = computed(() => [
  { label: 'Doctors', count: 5, icon: 'mdi-doctor', color: 'blue' },
  { label: 'Patients', count: 10, icon: 'mdi-account-group', color: 'teal' },
  { label: 'Appointments', count: 10, icon: 'mdi-calendar-clock', color: 'orange' },
  { label: 'Consultations', count: 10, icon: 'mdi-stethoscope', color: 'purple' },
  { label: 'Prescriptions', count: 5, icon: 'mdi-pill-multiple', color: 'red' },
  { label: 'Lab Orders', count: 5, icon: 'mdi-test-tube', color: 'green' },
])

function showSnack(text, color = 'success') {
  snackbarText.value = text
  snackbarColor.value = color
  snackbar.value = true
}

async function doSeed() {
  confirmSeed.value = false
  loading.value = true
  seedResult.value = null
  try {
    const { data } = await $api.post('/patients/seed-demo-data/')
    seedResult.value = data
    showSnack('Demo data seeded successfully!', 'success')
  } catch (err) {
    const existing = err?.response?.data?.existing
    if (existing) {
      showSnack(`Demo data already exists (${existing.doctors} doctors, ${existing.patients} patients). Clear it first.`, 'warning')
    } else {
      const msg = err?.response?.data?.error || 'Failed to seed demo data.'
      showSnack(msg, 'error')
    }
  } finally {
    loading.value = false
  }
}

async function doClear() {
  confirmClear.value = false
  clearing.value = true
  try {
    const { data } = await $api.delete('/patients/clear-demo-data/')
    seedResult.value = null
    showSnack('Demo data cleared successfully!', 'success')
  } catch (err) {
    const msg = err?.response?.data?.error || 'Failed to clear demo data.'
    showSnack(msg, 'error')
  } finally {
    clearing.value = false
  }
}

// ── Equipment seeding ───────────────────────────────────────────────────
const EQUIP_API = '/clinic-equipment/seed'

const eqPacks = ref([])
const eqCounts = ref({ categories: 0, assets: 0, jobs: 0, faults: 0, transfers: 0 })
const eqHistory = ref([])
const eqLoading = ref(false)
const eqRunning = ref('')
const eqConfirm = ref(false)
const eqTarget = ref(null)

async function loadEquipmentSeed() {
  eqLoading.value = true
  try {
    const [catalog, history] = await Promise.all([
      $api.get(`${EQUIP_API}/catalog/`).catch(() => null),
      $api.get(`${EQUIP_API}/history/`, { params: { limit: 6 } }).catch(() => null),
    ])
    if (catalog) {
      eqPacks.value = catalog.data?.packs || []
      eqCounts.value = catalog.data?.counts || eqCounts.value
    }
    if (history) eqHistory.value = history.data?.results || []
  } finally {
    eqLoading.value = false
  }
}

function askSeedPack(pack) {
  eqTarget.value = pack
  eqConfirm.value = true
}

async function runEqSeed() {
  const pack = eqTarget.value
  if (!pack) return
  eqConfirm.value = false
  eqRunning.value = pack.key
  try {
    const body = { pack: pack.key }
    // Demo packs are refused server-side without this acknowledgement.
    if (pack.creates_demo_assets) body.confirm_demo = true

    const { data } = await $api.post(`${EQUIP_API}/run/`, body)
    const created = data?.records_created ?? 0
    showSnack(
      created
        ? `${pack.label}: ${created} record${created === 1 ? '' : 's'} created.`
        : `${pack.label}: already up to date.`,
      'success',
    )
    await loadEquipmentSeed()
  } catch (err) {
    const detail = err?.response?.data?.detail
    showSnack(detail || `Failed to run ${pack.label.toLowerCase()}.`, 'error')
  } finally {
    eqRunning.value = ''
    eqTarget.value = null
  }
}

async function clearEqHistory() {
  try {
    await $api.delete(`${EQUIP_API}/history/`)
    eqHistory.value = []
    showSnack('Equipment seed history cleared.', 'success')
  } catch (err) {
    showSnack(err?.response?.data?.detail || 'Could not clear history.', 'error')
  }
}

function eqRelative(value) {
  if (!value) return '—'
  const then = new Date(value).getTime()
  if (Number.isNaN(then)) return '—'
  const mins = Math.floor((Date.now() - then) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return new Date(value).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(loadEquipmentSeed)
</script>

<style scoped>
/* ══ Equipment seed panel ══ */
.eqseed-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
.eqseed-title-wrap { display: flex; align-items: flex-start; min-width: 200px; flex: 1; }
.eqseed-title { font-size: 15px; font-weight: 800; letter-spacing: -0.2px; }
.eqseed-sub {
  margin-top: 2px;
  font-size: 11.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.eqseed-counts { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.eqseed-count {
  display: inline-flex;
  align-items: baseline;
  gap: 4px;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  white-space: nowrap;
}
.eqseed-count b {
  font-size: 12px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.9);
  font-variant-numeric: tabular-nums;
}

.eqseed-loading { padding: 10px 0; }

.eqseed-packs {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(288px, 1fr));
  gap: 10px;
}
.eqseed-pack {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px 13px 11px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgb(var(--v-theme-surface));
  transition: border-color 0.16s ease, box-shadow 0.16s ease;
}
.eqseed-pack:hover {
  border-color: rgba(103, 58, 183, 0.28);
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.06);
}
.eqseed-pack.is-demo { border-style: dashed; }
.eqseed-pack-top { display: flex; align-items: flex-start; gap: 9px; }
.eqseed-pack-icon {
  width: 30px; height: 30px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 9px;
}
.eqseed-pack-icon.is-safe { color: #047857; background: rgba(16, 185, 129, 0.12); }
.eqseed-pack-icon.is-demo { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.eqseed-pack-id { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.eqseed-pack-name { font-size: 13px; font-weight: 800; letter-spacing: -0.1px; }
.eqseed-badge {
  align-self: flex-start;
  display: inline-flex; align-items: center;
  height: 18px; padding: 0 7px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.4px; text-transform: uppercase;
  white-space: nowrap;
}
.eqseed-badge.is-safe { color: #047857; background: rgba(16, 185, 129, 0.13); }
.eqseed-badge.is-demo { color: #b45309; background: rgba(245, 158, 11, 0.16); }

.eqseed-pack-desc {
  margin: 0;
  font-size: 11.5px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.6);
  flex: 1;
}
.eqseed-pack-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  flex-wrap: wrap;
  padding-top: 8px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.eqseed-pack-meta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 10px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.44);
  white-space: nowrap;
}

/* History */
.eqseed-history {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.eqseed-history-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 7px;
}
.eqseed-history-title {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.9px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.44);
}
.eqseed-link {
  border: 0;
  background: none;
  padding: 0;
  cursor: pointer;
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
  text-decoration: underline;
  text-underline-offset: 2px;
}
.eqseed-history-list { display: flex; flex-direction: column; gap: 4px; }
.eqseed-run {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 9px;
  border-radius: 8px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  font-size: 11px;
}
.eqseed-run-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; background: #94a3b8; }
.eqseed-run-dot.is-success { background: #10b981; }
.eqseed-run-dot.is-failed { background: #ef4444; }
.eqseed-run-main { font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eqseed-run-count {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 6px;
  border-radius: 999px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-on-surface), 0.06);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.eqseed-run-by { color: rgba(var(--v-theme-on-surface), 0.44); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eqseed-run-when {
  margin-left: auto;
  color: rgba(var(--v-theme-on-surface), 0.44);
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.eqseed-history-empty {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.44);
  font-style: italic;
}

@media (max-width: 767px) {
  .eqseed-packs { grid-template-columns: minmax(0, 1fr); }
  .eqseed-run-by { display: none; }
}
</style>
