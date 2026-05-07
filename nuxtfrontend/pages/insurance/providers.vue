<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="cyan-darken-3" size="32">mdi-domain</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Insurance Providers</div>
              <div class="text-body-2" style="opacity:0.9">
                Manage insurance partners, contractual rates &amp; claim addresses.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0" style="gap:8px">
          <v-btn color="white" variant="elevated" class="text-cyan-darken-3"
                 prepend-icon="mdi-plus" @click="openCreate">New Provider</v-btn>
          <v-btn color="white" variant="outlined" prepend-icon="mdi-arrow-left" to="/insurance">Claims</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="items" :loading="loading" items-per-page="20">
        <template #item.name="{ item }">
          <div class="font-weight-bold">{{ item.name }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.code }}</div>
        </template>
        <template #item.contact="{ item }">
          <div>{{ item.contact_person || '—' }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.phone || item.email }}</div>
        </template>
        <template #item.discount_rate="{ item }">{{ item.discount_rate }}%</template>
        <template #item.payment_terms_days="{ item }">{{ item.payment_terms_days }} days</template>
        <template #item.open_claims="{ item }"><v-chip size="small" variant="tonal" color="blue">{{ item.open_claims }}</v-chip></template>
        <template #item.total_outstanding="{ item }">
          <strong :class="item.total_outstanding > 0 ? 'text-error' : ''">
            KSh {{ Number(item.total_outstanding || 0).toLocaleString() }}
          </strong>
        </template>
        <template #item.is_active="{ item }">
          <v-chip size="small" variant="flat" :color="item.is_active ? 'success' : 'grey'">
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="remove(item)" />
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="formDialog" max-width="640" persistent>
      <v-card rounded="xl">
        <v-card-title>
          <v-icon class="mr-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          {{ form.id ? 'Edit' : 'New' }} Provider
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="8">
              <v-text-field v-model="form.name" label="Name *" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model="form.code" label="Code (e.g. NHIF)" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.contact_person" label="Contact person" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.claim_email" label="Claims email" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.discount_rate" type="number" min="0" max="100"
                            label="Discount rate (%)" suffix="%" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="form.payment_terms_days" type="number" min="0"
                            label="Payment terms (days)" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-switch v-model="form.is_active" label="Active" color="success" hide-details density="compact" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const items = ref([])
const formDialog = ref(false)
const form = ref({})
const snack = ref({ show: false, color: 'success', text: '' })

const headers = [
  { title: 'Provider', key: 'name' },
  { title: 'Contact', key: 'contact' },
  { title: 'Discount', key: 'discount_rate', align: 'end', width: 100 },
  { title: 'Terms', key: 'payment_terms_days', align: 'end', width: 100 },
  { title: 'Open', key: 'open_claims', align: 'end', width: 80 },
  { title: 'Outstanding', key: 'total_outstanding', align: 'end', width: 150 },
  { title: 'Status', key: 'is_active', width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

async function load() {
  loading.value = true
  try {
    const r = await $api.get('/insurance/providers/')
    items.value = r.data?.results || r.data || []
  } catch { showSnack('Failed', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  form.value = { name: '', code: '', is_active: true, discount_rate: 0, payment_terms_days: 30 }
  formDialog.value = true
}
function openEdit(item) { form.value = { ...item }; formDialog.value = true }

async function save() {
  saving.value = true
  try {
    if (form.value.id) await $api.patch(`/insurance/providers/${form.value.id}/`, form.value)
    else await $api.post('/insurance/providers/', form.value)
    showSnack('Saved'); formDialog.value = false; await load()
  } catch (e) { showSnack(JSON.stringify(e?.response?.data || 'Failed'), 'error') }
  finally { saving.value = false }
}

async function remove(item) {
  if (!confirm(`Delete ${item.name}?`)) return
  try {
    await $api.delete(`/insurance/providers/${item.id}/`)
    showSnack('Deleted'); await load()
  } catch { showSnack('Failed', 'error') }
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
onMounted(load)
</script>

<style scoped>
.hero { background: linear-gradient(135deg, #155e75 0%, #0891b2 50%, #67e8f9 100%); }
</style>
