<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Doctor Commissions"
      icon="mdi-stethoscope"
      subtitle="Platform revenue from doctor consultations"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <div v-if="data">
      <v-card rounded="lg" class="pa-4 mb-4">
        <div class="d-flex flex-wrap align-center ga-2">
          <v-icon class="mr-1">mdi-percent</v-icon>
          <div>
            <div class="text-caption text-medium-emphasis">Current commission rate</div>
            <div class="text-h6 font-weight-bold">{{ data.commission_rate.percentage }}%</div>
          </div>
          <v-spacer />
          <v-text-field
            v-model.number="newRate"
            label="New rate %"
            type="number"
            min="0"
            max="100"
            step="0.5"
            density="compact"
            hide-details
            style="max-width: 160px"
          />
          <v-btn color="primary" :loading="saving" :disabled="!newRate || newRate === Number(data.commission_rate.percentage)" @click="updateRate">
            Update rate
          </v-btn>
        </div>
      </v-card>

      <v-row dense class="mb-2">
        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Doctors with consultations</div>
            <div class="text-h4 font-weight-bold">{{ data.totals.doctors_billable }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Consultations this month</div>
            <div class="text-h4 font-weight-bold">{{ data.totals.consultations }}</div>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card rounded="lg" class="pa-4" color="primary" variant="tonal">
            <div class="text-caption text-medium-emphasis">Total commission owed</div>
            <div class="text-h4 font-weight-bold">
              {{ formatMoney(data.totals.commission_owed, data.commission_rate.currency) }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-format-list-bulleted</v-icon>
          By doctor ({{ data.period.year }}-{{ String(data.period.month).padStart(2, '0') }})
        </v-card-title>
        <v-data-table
          :headers="headers"
          :items="data.doctors"
          density="comfortable"
          :items-per-page="20"
        >
          <template #item.consultation_fee="{ item }">
            {{ formatMoney(item.consultation_fee, data.commission_rate.currency) }}
          </template>
          <template #item.fees_total="{ item }">
            {{ formatMoney(item.fees_total, data.commission_rate.currency) }}
          </template>
          <template #item.commission_owed="{ item }">
            <strong>{{ formatMoney(item.commission_owed, data.commission_rate.currency) }}</strong>
          </template>
          <template #no-data>
            <div class="text-medium-emphasis py-4 text-center">
              No doctor consultations this month.
            </div>
          </template>
        </v-data-table>
      </v-card>
    </div>

    <v-progress-linear v-else-if="loading" indeterminate color="primary" />
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const data = ref(null)
const loading = ref(false)
const saving = ref(false)
const error = ref(null)
const newRate = ref(null)

const headers = [
  { title: 'Doctor', key: 'doctor_name' },
  { title: 'Specialization', key: 'specialization' },
  { title: 'Hospital', key: 'hospital' },
  { title: 'Fee', key: 'consultation_fee' },
  { title: 'Consultations', key: 'consultations' },
  { title: 'Fees total', key: 'fees_total' },
  { title: 'Commission', key: 'commission_owed' }
]

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: res } = await $api.get('/usage-billing/admin/doctor-commissions/')
    data.value = res
    newRate.value = Number(res.commission_rate.percentage)
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load.'
  } finally {
    loading.value = false
  }
}

async function updateRate() {
  saving.value = true
  try {
    await $api.post('/usage-billing/admin/doctor-rates/', {
      percentage: newRate.value,
      is_active: true
    })
    await load()
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to update rate.'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>
