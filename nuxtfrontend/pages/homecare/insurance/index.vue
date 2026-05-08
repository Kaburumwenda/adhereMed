<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Insurance" icon="mdi-shield-account" subtitle="Patient policies and claims" />
    <v-card rounded="xl">
      <v-tabs v-model="tab" bg-color="transparent" color="teal" grow>
        <v-tab value="claims">Claims</v-tab>
        <v-tab value="policies">Policies</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4">
        <v-window-item value="claims">
          <v-data-table :headers="claimHeaders" :items="claims" :loading="loading" item-value="id">
            <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
            <template #[`item.actions`]="{ item }">
              <v-btn v-if="item.status === 'draft'" size="small" color="teal" variant="text"
                     prepend-icon="mdi-send" @click="submit(item)">Submit</v-btn>
            </template>
          </v-data-table>
        </v-window-item>
        <v-window-item value="policies">
          <v-data-table :headers="policyHeaders" :items="policies" :loading="loading" item-value="id">
            <template #[`item.is_active`]="{ item }"><StatusChip :status="item.is_active ? 'active' : 'closed'" /></template>
          </v-data-table>
        </v-window-item>
      </v-window>
    </v-card>
  </v-container>
</template>
<script setup>
const { $api } = useNuxtApp()
const tab = ref('claims')
const claims = ref([])
const policies = ref([])
const loading = ref(false)
const claimHeaders = [
  { title: 'Claim #', key: 'claim_number' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Provider', key: 'policy_provider' },
  { title: 'Type', key: 'claim_type' },
  { title: 'Amount', key: 'amount_requested' },
  { title: 'Approved', key: 'approved_amount' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const policyHeaders = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Provider', key: 'provider_name' },
  { title: 'Number', key: 'policy_number' },
  { title: 'Valid from', key: 'valid_from' },
  { title: 'Valid to', key: 'valid_to' },
  { title: 'Active', key: 'is_active' }
]
async function load() {
  loading.value = true
  try {
    const [c, p] = await Promise.all([
      $api.get('/homecare/insurance-claims/'),
      $api.get('/homecare/insurance-policies/')
    ])
    claims.value = c.data?.results || c.data || []
    policies.value = p.data?.results || p.data || []
  } finally { loading.value = false }
}
async function submit(item) {
  await $api.post(`/homecare/insurance-claims/${item.id}/submit/`)
  load()
}
onMounted(load)
</script>
