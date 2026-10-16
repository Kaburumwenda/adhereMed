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
        <v-card-item>
          <v-card-title class="d-flex align-center">
            <v-icon icon="mdi-help-circle-outline" color="deep-purple" class="mr-2" />
            Confirm Seeding
          </v-card-title>
        </v-card-item>
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
        <v-card-item>
          <v-card-title class="d-flex align-center">
            <v-icon icon="mdi-alert-circle-outline" color="error" class="mr-2" />
            Confirm Clear
          </v-card-title>
        </v-card-item>
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
</script>
