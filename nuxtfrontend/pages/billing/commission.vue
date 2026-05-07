<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="My Commission"
      icon="mdi-percent"
      subtitle="Platform commission on your consultations"
    >
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="error" type="error" variant="tonal" class="mb-4">{{ error }}</v-alert>

    <div v-if="data">
      <v-alert type="info" variant="tonal" class="mb-4" border="start">
        Patients use the system free of charge. Doctors are billed
        <strong>{{ data.commission_rate.percentage }}%</strong> of their consultation fees.
        Your consultation fee:
        <strong>{{ formatMoney(data.doctor.consultation_fee, data.doctor.currency) }}</strong>.
      </v-alert>

      <v-row dense>
        <v-col cols="12" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Consultations this month</div>
            <div class="text-h4 font-weight-bold mt-1">
              {{ data.current_month.consultations }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Fees this month</div>
            <div class="text-h5 font-weight-bold mt-1">
              {{ formatMoney(data.current_month.fees_total, data.doctor.currency) }}
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3">
          <v-card rounded="lg" class="pa-4" color="primary" variant="tonal">
            <div class="text-caption text-medium-emphasis">Commission owed (this month)</div>
            <div class="text-h5 font-weight-bold mt-1">
              {{ formatMoney(data.current_month.commission_owed, data.doctor.currency) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ data.commission_rate.percentage }}% of fees
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="3">
          <v-card rounded="lg" class="pa-4">
            <div class="text-caption text-medium-emphasis">Last month</div>
            <div class="text-h6 font-weight-bold mt-1">
              {{ formatMoney(data.previous_month.commission_owed, data.doctor.currency) }}
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ data.previous_month.consultations }} consultations ·
              {{ formatMoney(data.previous_month.fees_total, data.doctor.currency) }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-card rounded="lg" class="mt-4">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-history</v-icon>
          Last 6 months
        </v-card-title>
        <v-data-table
          :headers="headers"
          :items="data.monthly_history"
          density="comfortable"
          hide-default-footer
        >
          <template #item.fees_total="{ item }">
            {{ formatMoney(item.fees_total, data.doctor.currency) }}
          </template>
          <template #item.commission="{ item }">
            <strong>{{ formatMoney(item.commission, data.doctor.currency) }}</strong>
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
const error = ref(null)

const headers = [
  { title: 'Period', key: 'label' },
  { title: 'Consultations', key: 'consultations' },
  { title: 'Fees total', key: 'fees_total' },
  { title: 'Commission', key: 'commission' }
]

async function load() {
  loading.value = true
  error.value = null
  try {
    const { data: res } = await $api.get('/usage-billing/doctor/dashboard/')
    data.value = res
  } catch (e) {
    error.value = e?.response?.data?.detail || e.message || 'Failed to load commission data.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>
