<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Family Portal"
      subtitle="Invite family members to follow their loved one's care plan, doses and visits."
      eyebrow="ENGAGEMENT"
      icon="mdi-account-multiple-plus"
      :chips="[{ icon: 'mdi-email', label: `${members.length} active invites` }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-account-plus"
               class="text-none" @click="dialog = true">
          <span class="text-teal-darken-2 font-weight-bold">Invite family</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" md="4">
        <HomecareKpiCard label="Active members" :value="activeCount" icon="mdi-account-check" color="#10b981" />
      </v-col>
      <v-col cols="12" md="4">
        <HomecareKpiCard label="Pending invites" :value="pendingCount" icon="mdi-email-outline" color="#f59e0b" />
      </v-col>
      <v-col cols="12" md="4">
        <HomecareKpiCard label="Patients with family" :value="patientCoverage" icon="mdi-account-heart" color="#0d9488" />
      </v-col>
    </v-row>

    <HomecarePanel title="Family members" subtitle="Granted access to a patient's portal"
                   icon="mdi-account-multiple" color="#ec4899" class="mt-3">
      <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search by patient or member…"
                    density="compact" variant="outlined" hide-details class="mb-3" />
      <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id">
        <template #[`item.relationship`]="{ item }">
          <v-chip size="small" color="pink" variant="tonal">{{ item.relationship || 'Family' }}</v-chip>
        </template>
        <template #[`item.status`]="{ item }">
          <StatusChip :status="item.status || (item.accepted_at ? 'active' : 'pending')" />
        </template>
        <template #[`item.permissions`]="{ item }">
          <div class="d-flex flex-wrap ga-1">
            <v-chip v-for="p in (item.permissions || ['view'])" :key="p" size="x-small" variant="tonal" color="teal">
              {{ p }}
            </v-chip>
          </div>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn size="small" variant="text" color="error" prepend-icon="mdi-cancel"
                 @click="revoke(item)">Revoke</v-btn>
        </template>
      </v-data-table>
    </HomecarePanel>

    <v-dialog v-model="dialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title>Invite a family member</v-card-title>
        <v-card-text>
          <v-select v-model="form.patient" :items="patients" item-title="patient_name" item-value="id" label="Patient" />
          <v-text-field v-model="form.email" label="Family member email" />
          <v-text-field v-model="form.full_name" label="Full name" />
          <v-select v-model="form.relationship" :items="['Spouse','Parent','Child','Sibling','Guardian','Friend']" label="Relationship" />
          <v-select v-model="form.permissions" :items="['view','dose_alerts','vitals','teleconsult']"
                    multiple chips label="Permissions" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" :loading="saving" @click="invite">Send invite</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const members = ref([])
const patients = ref([])
const search = ref('')
const loading = ref(false)
const dialog = ref(false)
const saving = ref(false)
const form = reactive({ patient: null, email: '', full_name: '', relationship: 'Spouse', permissions: ['view'] })

const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Family member', key: 'full_name' },
  { title: 'Email', key: 'email' },
  { title: 'Relationship', key: 'relationship' },
  { title: 'Permissions', key: 'permissions', sortable: false },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]

const filtered = computed(() => {
  const q = (search.value || '').toLowerCase()
  if (!q) return members.value
  return members.value.filter(m =>
    (m.patient_name || '').toLowerCase().includes(q) ||
    (m.full_name || '').toLowerCase().includes(q) ||
    (m.email || '').toLowerCase().includes(q))
})
const activeCount = computed(() => members.value.filter(m => m.accepted_at || m.status === 'active').length)
const pendingCount = computed(() => members.value.filter(m => !m.accepted_at && m.status !== 'active').length)
const patientCoverage = computed(() => new Set(members.value.map(m => m.patient)).size)

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/family-members/')
    members.value = data?.results || data || []
  } catch { members.value = [] }
  finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}
async function invite() {
  saving.value = true
  try {
    await $api.post('/homecare/family-members/', form)
    dialog.value = false
    load()
  } catch (e) { console.warn('family-members endpoint missing', e) }
  finally { saving.value = false }
}
async function revoke(item) {
  try { await $api.delete(`/homecare/family-members/${item.id}/`); load() }
  catch { console.warn('revoke failed') }
}
onMounted(() => { load(); loadPatients() })
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
</style>
