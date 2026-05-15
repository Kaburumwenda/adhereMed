<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="amber-lighten-5" size="48" class="mr-3">
          <v-icon color="amber-darken-2" size="28">mdi-star-circle</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('posLoyalty.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Tier-based rewards · Earn points from purchases · Redeem at checkout</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openAdjust">{{ $t('posLoyalty.adjustPoints') }}</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh" :loading="loading" @click="load">{{ $t('common.refresh') }}</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <v-col cols="12" md="4">
        <v-card flat rounded="xl" border>
          <v-card-title class="text-subtitle-1"><v-icon class="mr-2">mdi-account-group</v-icon>Members by Tier</v-card-title>
          <v-card-text>
            <div v-for="t in tiers" :key="t.tier" class="d-flex align-center mb-3">
              <v-chip size="small" variant="flat" :color="tierColor(t.tier)" class="text-capitalize mr-3" style="min-width:90px">{{ t.tier }}</v-chip>
              <div class="flex-grow-1">
                <div class="d-flex justify-space-between text-caption">
                  <span>{{ t.count }} members</span>
                  <span>{{ Number(t.total_points || 0).toLocaleString() }} pts</span>
                </div>
                <v-progress-linear :model-value="totalCustomers ? (t.count / totalCustomers) * 100 : 0"
                                   :color="tierColor(t.tier)" height="6" rounded class="mt-1" />
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="8">
        <v-card flat rounded="xl" border>
          <v-card-title class="text-subtitle-1"><v-icon class="mr-2">mdi-trophy</v-icon>Top Members</v-card-title>
          <v-list density="comfortable">
            <v-list-item v-for="m in stats?.top_members || []" :key="m.id">
              <template #prepend>
                <v-avatar :color="tierColor(m.loyalty_tier)" size="36" class="text-white">
                  {{ (m.full_name || m.phone || '?').charAt(0).toUpperCase() }}
                </v-avatar>
              </template>
              <v-list-item-title>{{ m.full_name || '—' }}</v-list-item-title>
              <v-list-item-subtitle>{{ m.phone }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="small" variant="flat" :color="tierColor(m.loyalty_tier)" class="text-capitalize mr-2">{{ m.loyalty_tier }}</v-chip>
                <strong>{{ Number(m.loyalty_points).toLocaleString() }} pts</strong>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <v-card flat rounded="xl" border class="mt-4">
      <v-card-title class="text-subtitle-1"><v-icon class="mr-2">mdi-history</v-icon>Recent Loyalty Transactions</v-card-title>
      <v-data-table :headers="headers" :items="transactions" :loading="loading" items-per-page="10">
        <template #item.created_at="{ item }">{{ new Date(item.created_at).toLocaleString() }}</template>
        <template #item.type="{ item }">
          <v-chip size="small" variant="flat" :color="typeColor(item.type)" class="text-capitalize">{{ item.type }}</v-chip>
        </template>
        <template #item.points="{ item }">
          <span :class="item.points >= 0 ? 'text-success' : 'text-error'" class="font-weight-bold">
            {{ item.points > 0 ? '+' : '' }}{{ item.points }}
          </span>
        </template>
      </v-data-table>
    </v-card>

    <!-- Adjust dialog -->
    <v-dialog v-model="adjustDialog" max-width="540" persistent>
      <v-card rounded="xl">
        <v-card-title><v-icon class="mr-2">mdi-plus</v-icon>Adjust Loyalty Points</v-card-title>
        <v-card-text>
          <v-autocomplete v-model="form.customer" :items="customerOptions" :loading="custSearching"
                          label="Customer *" item-title="display" item-value="id"
                          variant="outlined" density="comfortable"
                          :search="custSearch" @update:search="searchCustomers" />
          <v-select v-model="form.type" :items="typeOptions" label="Type *"
                    variant="outlined" density="comfortable" />
          <v-text-field v-model.number="form.points" type="number" label="Points *"
                        variant="outlined" density="comfortable" hint="Negative for redemptions" persistent-hint />
          <v-text-field v-model="form.notes" label="Notes" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="adjustDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ $t('common.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const transactions = ref([])
const stats = ref(null)
const adjustDialog = ref(false)
const form = ref({})
const customerOptions = ref([])
const custSearch = ref('')
const custSearching = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })

const typeOptions = [
  { title: 'Earn', value: 'earn' },
  { title: 'Redeem', value: 'redeem' },
  { title: 'Adjust', value: 'adjust' },
  { title: 'Expire', value: 'expire' },
]

const headers = [
  { title: 'Date', key: 'created_at', width: 170 },
  { title: 'Customer', key: 'customer_name' },
  { title: 'Type', key: 'type', width: 110 },
  { title: 'Points', key: 'points', align: 'end', width: 100 },
  { title: 'Balance After', key: 'balance_after', align: 'end', width: 130 },
  { title: 'Notes', key: 'notes' },
]

const tiers = computed(() => stats.value?.by_tier || [])
const totalCustomers = computed(() => stats.value?.total_customers || 0)

const kpis = computed(() => [
  { label: 'Members', value: totalCustomers.value, icon: 'mdi-account-group', color: 'amber' },
  { label: 'Points Outstanding', value: Number(stats.value?.total_points_outstanding || 0).toLocaleString(), icon: 'mdi-star', color: 'orange' },
  { label: 'Platinum', value: tiers.value.find(t => t.tier === 'platinum')?.count || 0, icon: 'mdi-crown', color: 'deep-purple' },
  { label: 'Gold', value: tiers.value.find(t => t.tier === 'gold')?.count || 0, icon: 'mdi-medal', color: 'yellow-darken-2' },
])

function tierColor(t) { return ({ bronze: 'brown', silver: 'blue-grey', gold: 'amber', platinum: 'deep-purple' })[t] || 'grey' }
function typeColor(t) { return ({ earn: 'success', redeem: 'orange', adjust: 'blue', expire: 'grey' })[t] || 'grey' }

async function load() {
  loading.value = true
  try {
    const [tx, st] = await Promise.all([
      $api.get('/pos/loyalty/').then(r => r.data?.results || r.data || []),
      $api.get('/pos/loyalty/stats/').then(r => r.data),
    ])
    transactions.value = tx
    stats.value = st
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

let searchTimer = null
function searchCustomers(q) {
  custSearch.value = q
  clearTimeout(searchTimer)
  if (!q || q.length < 2) return
  searchTimer = setTimeout(async () => {
    custSearching.value = true
    try {
      const r = await $api.get(`/pos/customers/?search=${encodeURIComponent(q)}`)
      const list = r.data?.results || r.data || []
      customerOptions.value = list.map(c => ({ ...c, display: `${c.full_name || '—'} · ${c.phone || ''}` }))
    } finally { custSearching.value = false }
  }, 300)
}

function openAdjust() {
  form.value = { customer: null, type: 'adjust', points: 0, notes: '' }
  adjustDialog.value = true
}

async function save() {
  saving.value = true
  try {
    await $api.post('/pos/loyalty/', form.value)
    showSnack('Saved', 'success')
    adjustDialog.value = false
    await load()
  } catch (e) { showSnack(JSON.stringify(e?.response?.data || 'Failed'), 'error') }
  finally { saving.value = false }
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
