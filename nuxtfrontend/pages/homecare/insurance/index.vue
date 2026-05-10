<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Insurance"
      subtitle="Patient policies and claims processed for homecare services."
      eyebrow="REVENUE CYCLE"
      icon="mdi-shield-check"
      :chips="[
        { icon: 'mdi-file-document', label: `${stats.totalClaims} claims` },
        { icon: 'mdi-check-decagram', label: `${formatMoney(stats.approved)} approved` },
        { icon: 'mdi-percent',        label: `${stats.approvalRate}% approval` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreateClaim">
          <span class="text-teal-darken-2 font-weight-bold">New claim</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-tabs v-model="tab" color="teal" align-tabs="start" class="mt-2">
      <v-tab value="claims" prepend-icon="mdi-file-document-multiple">Claims</v-tab>
      <v-tab value="policies" prepend-icon="mdi-shield-account">Policies</v-tab>
    </v-tabs>

    <v-window v-model="tab" class="mt-3">
      <!-- CLAIMS -->
      <v-window-item value="claims">
        <v-row dense>
          <v-col cols="12" lg="8">
            <HomecarePanel title="All claims" icon="mdi-file-document-multiple" color="#0d9488">
              <v-row dense class="mb-2">
                <v-col cols="12" md="6">
                  <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                                placeholder="Search claim number, patient…" density="compact"
                                variant="outlined" hide-details rounded="lg" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-select v-model="filterClaimStatus" :items="claimStatusOptions"
                            label="Status" density="compact" variant="outlined"
                            hide-details clearable rounded="lg" />
                </v-col>
              </v-row>

              <v-progress-linear v-if="loadingClaims" indeterminate color="teal" class="mb-2" rounded />

              <div v-if="filteredClaims.length">
                <v-card v-for="c in filteredClaims" :key="c.id" class="hc-claim-card mb-2"
                        rounded="xl" :elevation="0">
                  <div class="hc-claim-band" :style="{ background: claimColor(c.status).hex }" />
                  <div class="pa-4">
                    <div class="d-flex align-center ga-3">
                      <v-avatar size="44" :color="claimColor(c.status).vuetify" variant="tonal">
                        <v-icon :icon="claimIcon(c.status)" />
                      </v-avatar>
                      <div class="flex-grow-1 min-w-0">
                        <div class="d-flex align-center ga-2 flex-wrap">
                          <div class="text-subtitle-1 font-weight-bold">
                            {{ c.claim_number || `CL-${c.id}` }}
                          </div>
                          <v-chip size="x-small" :color="claimColor(c.status).vuetify" variant="tonal">
                            {{ c.status }}
                          </v-chip>
                          <v-chip size="x-small" variant="text">{{ c.claim_type }}</v-chip>
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          <v-icon icon="mdi-account" size="12" /> {{ c.patient_name }}
                          <span class="mx-1">·</span>
                          <v-icon icon="mdi-shield" size="12" /> {{ c.policy_provider || '—' }}
                          <span class="mx-1">·</span>
                          <v-icon icon="mdi-calendar" size="12" />
                          {{ formatDate(c.service_start_date) }}
                          → {{ formatDate(c.service_end_date) }}
                        </div>
                      </div>
                      <div class="text-right">
                        <div class="text-subtitle-1 font-weight-bold text-teal">
                          {{ formatMoney(c.requested_amount) }}
                        </div>
                        <div v-if="c.approved_amount" class="text-caption text-medium-emphasis">
                          Approved {{ formatMoney(c.approved_amount) }}
                        </div>
                      </div>
                      <v-menu>
                        <template #activator="{ props }">
                          <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                        </template>
                        <v-list density="compact">
                          <v-list-item v-if="c.status === 'draft'" prepend-icon="mdi-send"
                                       title="Submit" @click="submit(c)" />
                          <v-list-item v-if="['submitted','under_review'].includes(c.status)"
                                       prepend-icon="mdi-message-arrow-left"
                                       title="Record response" @click="openResponse(c)" />
                        </v-list>
                      </v-menu>
                    </div>
                  </div>
                </v-card>
              </div>
              <EmptyState v-else icon="mdi-file-document-off" title="No claims"
                          message="Create one to get started." />
            </HomecarePanel>
          </v-col>

          <v-col cols="12" lg="4">
            <HomecarePanel title="Claims by status" icon="mdi-chart-donut" color="#7c3aed">
              <DonutRing :segments="claimSegments" :size="180" :thickness="18">
                <div class="text-h4 font-weight-bold">{{ claims.length }}</div>
                <div class="text-caption text-medium-emphasis">claims</div>
              </DonutRing>
              <v-divider class="my-3" />
              <div v-for="r in claimRows" :key="r.label"
                   class="d-flex align-center pa-2 rounded-lg mb-1"
                   :style="{ background: r.bg }">
                <v-avatar size="28" :color="r.color" variant="flat" class="mr-2">
                  <v-icon :icon="r.icon" color="white" size="14" />
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="text-body-2 font-weight-bold">{{ r.label }}</div>
                  <div class="text-caption text-medium-emphasis">{{ r.count }} claim(s)</div>
                </div>
              </div>
            </HomecarePanel>

            <HomecarePanel title="Top providers" icon="mdi-shield-star" color="#0284c7" class="mt-3">
              <v-list density="compact" class="bg-transparent pa-0">
                <v-list-item v-for="(p, idx) in topProviders" :key="p.name" rounded="lg">
                  <template #prepend>
                    <v-avatar size="32" color="info" variant="tonal">
                      <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-bold">{{ p.name }}</v-list-item-title>
                  <v-list-item-subtitle>
                    {{ p.count }} claims · {{ formatMoney(p.amount) }}
                  </v-list-item-subtitle>
                </v-list-item>
                <EmptyState v-if="!topProviders.length" icon="mdi-shield-off" title="No data" dense />
              </v-list>
            </HomecarePanel>
          </v-col>
        </v-row>
      </v-window-item>

      <!-- POLICIES -->
      <v-window-item value="policies">
        <HomecarePanel title="Active policies" icon="mdi-shield-account" color="#0d9488">
          <v-progress-linear v-if="loadingPolicies" indeterminate color="teal" class="mb-2" rounded />
          <v-table density="comfortable" class="rounded-lg">
            <thead>
              <tr>
                <th>Patient</th><th>Provider</th><th>Member ID</th>
                <th>Plan</th><th>Validity</th><th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in policies" :key="p.id">
                <td class="font-weight-bold">{{ p.patient_name }}</td>
                <td>{{ p.provider_name }}</td>
                <td><code class="text-caption">{{ p.member_id }}</code></td>
                <td>{{ p.plan_name || '—' }}</td>
                <td class="text-caption">
                  {{ formatDate(p.effective_date) }} → {{ formatDate(p.expiry_date) }}
                </td>
                <td>
                  <v-chip size="x-small" :color="p.is_active ? 'success' : 'grey'" variant="tonal">
                    {{ p.is_active ? 'active' : 'inactive' }}
                  </v-chip>
                </td>
              </tr>
              <tr v-if="!policies.length">
                <td colspan="6" class="text-center text-medium-emphasis py-6">No policies</td>
              </tr>
            </tbody>
          </v-table>
        </HomecarePanel>
      </v-window-item>
    </v-window>

    <!-- New claim dialog -->
    <v-dialog v-model="claimDialog" max-width="720" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-file-document-plus" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">NEW</div>
              <h3 class="text-h6 ma-0">Submit insurance claim</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="claimDialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="createClaim">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.patient" :items="patients"
                                item-title="name" item-value="id"
                                label="Patient *" variant="outlined" density="comfortable"
                                rounded="lg" prepend-inner-icon="mdi-account"
                                :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.policy" :items="patientPolicies"
                                item-title="label" item-value="id"
                                label="Policy *" variant="outlined" density="comfortable"
                                rounded="lg" prepend-inner-icon="mdi-shield"
                                :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.claim_type" :items="claimTypeOptions"
                          label="Claim type" variant="outlined" density="comfortable"
                          rounded="lg" prepend-inner-icon="mdi-tag" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.service_start_date" label="Start date"
                              type="date" variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.service_end_date" label="End date"
                              type="date" variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model.number="form.requested_amount" label="Requested amount (KES) *"
                              type="number" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-cash" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.diagnosis_code" label="Diagnosis code"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-stethoscope" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="claimDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-check" @click="createClaim">
            Save claim
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Record response dialog -->
    <v-dialog v-model="responseDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-message-arrow-left" color="teal" class="mr-1" /> Record response
        </v-card-title>
        <v-card-text>
          <v-select v-model="responseForm.status" :items="responseStatusOptions"
                    label="Status *" variant="outlined" density="comfortable" rounded="lg" />
          <v-text-field v-model.number="responseForm.approved_amount" label="Approved amount (KES)"
                        type="number" variant="outlined" density="comfortable" rounded="lg"
                        prepend-inner-icon="mdi-cash" />
          <v-textarea v-model="responseForm.denial_reason" label="Denial reason / notes"
                      rows="3" auto-grow variant="outlined" density="comfortable" rounded="lg" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="responseDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="recording" @click="recordResponse">Record</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const tab = ref('claims')
const claims = ref([])
const policies = ref([])
const patients = ref([])
const loadingClaims = ref(false)
const loadingPolicies = ref(false)
const saving = ref(false)
const recording = ref(false)

const search = ref('')
const filterClaimStatus = ref(null)
const claimDialog = ref(false)
const responseDialog = ref(false)
const formRef = ref(null)
const target = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const claimStatusOptions = [
  { value: 'draft',         title: 'Draft' },
  { value: 'submitted',     title: 'Submitted' },
  { value: 'under_review',  title: 'Under review' },
  { value: 'approved',      title: 'Approved' },
  { value: 'partially_approved', title: 'Partially approved' },
  { value: 'denied',        title: 'Denied' },
  { value: 'paid',          title: 'Paid' }
]
const claimTypeOptions = [
  { value: 'visit',        title: 'Home visit' },
  { value: 'medication',   title: 'Medication' },
  { value: 'equipment',    title: 'Equipment' },
  { value: 'lab',          title: 'Lab' },
  { value: 'teleconsult',  title: 'Teleconsult' }
]
const responseStatusOptions = [
  { value: 'approved',           title: 'Approved' },
  { value: 'partially_approved', title: 'Partially approved' },
  { value: 'denied',             title: 'Denied' },
  { value: 'paid',               title: 'Paid' }
]

const blank = () => ({
  patient: null, policy: null, claim_type: 'visit',
  service_start_date: new Date().toISOString().slice(0, 10),
  service_end_date: new Date().toISOString().slice(0, 10),
  requested_amount: 0, diagnosis_code: '', notes: ''
})
const form = reactive(blank())
const responseForm = reactive({ status: 'approved', approved_amount: 0, denial_reason: '' })

async function loadAll() {
  loadingClaims.value = true; loadingPolicies.value = true
  try {
    const [c, p] = await Promise.all([
      $api.get('/homecare/insurance-claims/', { params: { page_size: 200 } }),
      $api.get('/homecare/insurance-policies/', { params: { page_size: 200 } })
    ])
    claims.value = c.data?.results || c.data || []
    policies.value = p.data?.results || p.data || []
  } catch {
    snack.text = 'Failed to load insurance data'; snack.color = 'error'; snack.show = true
  } finally { loadingClaims.value = false; loadingPolicies.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    const list = data?.results || data || []
    patients.value = list.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`
    }))
  } catch { /* ignore */ }
}
onMounted(() => { loadAll(); loadPatients() })

const patientPolicies = computed(() => {
  if (!form.patient) return []
  return policies.value
    .filter(p => p.patient === form.patient || p.patient_id === form.patient)
    .map(p => ({ id: p.id, label: `${p.provider_name} · ${p.member_id}` }))
})

const filteredClaims = computed(() => {
  const q = search.value.trim().toLowerCase()
  return claims.value.filter(c => {
    if (filterClaimStatus.value && c.status !== filterClaimStatus.value) return false
    if (!q) return true
    return [c.claim_number, c.patient_name, c.policy_provider]
      .filter(Boolean).some(s => s.toLowerCase().includes(q))
  })
})

const stats = computed(() => {
  const total = claims.value.length
  const requested = claims.value.reduce((a, c) => a + (+c.requested_amount || 0), 0)
  const approved = claims.value.reduce((a, c) => a + (+c.approved_amount || 0), 0)
  const approvedCount = claims.value.filter(c => ['approved', 'partially_approved', 'paid'].includes(c.status)).length
  const decisioned = claims.value.filter(c => ['approved', 'partially_approved', 'paid', 'denied'].includes(c.status)).length
  const approvalRate = decisioned ? Math.round((approvedCount / decisioned) * 100) : 0
  return { totalClaims: total, requested, approved, approvalRate }
})
const summary = computed(() => [
  { label: 'Total claims', value: stats.value.totalClaims, color: 'teal',    icon: 'mdi-file-document-multiple' },
  { label: 'Requested',    value: formatMoney(stats.value.requested), color: 'warning', icon: 'mdi-cash-clock' },
  { label: 'Approved',     value: formatMoney(stats.value.approved),  color: 'success', icon: 'mdi-cash-check' },
  { label: 'Approval rate', value: `${stats.value.approvalRate}%`,    color: 'info',    icon: 'mdi-percent' }
])

const claimRows = computed(() => claimStatusOptions.map(o => ({
  label: o.title, count: claims.value.filter(c => c.status === o.value).length,
  color: claimColor(o.value).hex, bg: `${claimColor(o.value).hex}14`,
  icon: claimIcon(o.value)
})))
const claimSegments = computed(() => claimStatusOptions.map(o => ({
  label: o.title, value: claims.value.filter(c => c.status === o.value).length,
  color: claimColor(o.value).vuetify
})))

const topProviders = computed(() => {
  const map = {}
  for (const c of claims.value) {
    const k = c.policy_provider || '—'
    if (!map[k]) map[k] = { count: 0, amount: 0 }
    map[k].count += 1
    map[k].amount += (+c.requested_amount || 0)
  }
  return Object.entries(map).map(([name, v]) => ({ name, ...v }))
    .sort((a, b) => b.amount - a.amount).slice(0, 5)
})

function claimColor(s) {
  return ({
    draft:                { hex: '#94a3b8', vuetify: 'grey' },
    submitted:            { hex: '#0ea5e9', vuetify: 'info' },
    under_review:         { hex: '#f59e0b', vuetify: 'warning' },
    approved:             { hex: '#10b981', vuetify: 'success' },
    partially_approved:   { hex: '#a855f7', vuetify: 'purple' },
    denied:               { hex: '#ef4444', vuetify: 'error' },
    paid:                 { hex: '#0d9488', vuetify: 'teal' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}
function claimIcon(s) {
  return ({
    draft: 'mdi-file-document-edit', submitted: 'mdi-send',
    under_review: 'mdi-magnify', approved: 'mdi-check-decagram',
    partially_approved: 'mdi-check', denied: 'mdi-close-circle', paid: 'mdi-cash'
  })[s] || 'mdi-circle'
}
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function formatMoney(v) {
  const n = +v || 0
  return `KSh ${n.toLocaleString(undefined, { maximumFractionDigits: 0 })}`
}

function openCreateClaim() { Object.assign(form, blank()); claimDialog.value = true }
async function createClaim() {
  if (!form.patient || !form.policy) {
    snack.text = 'Patient and policy required'; snack.color = 'warning'; snack.show = true; return
  }
  saving.value = true
  try {
    const { data } = await $api.post('/homecare/insurance-claims/', form)
    claims.value.unshift(data)
    claimDialog.value = false
    snack.text = 'Claim saved'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}
async function submit(c) {
  try {
    const { data } = await $api.post(`/homecare/insurance-claims/${c.id}/submit/`)
    const i = claims.value.findIndex(x => x.id === c.id)
    if (i >= 0) claims.value.splice(i, 1, data)
    snack.text = 'Submitted to provider'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Submit failed'; snack.color = 'error'; snack.show = true
  }
}
function openResponse(c) {
  target.value = c
  responseForm.status = 'approved'
  responseForm.approved_amount = c.requested_amount || 0
  responseForm.denial_reason = ''
  responseDialog.value = true
}
async function recordResponse() {
  if (!target.value) return
  recording.value = true
  try {
    const { data } = await $api.post(
      `/homecare/insurance-claims/${target.value.id}/record_response/`, responseForm)
    const i = claims.value.findIndex(x => x.id === target.value.id)
    if (i >= 0) claims.value.splice(i, 1, data)
    responseDialog.value = false
    snack.text = 'Response recorded'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Record failed'; snack.color = 'error'; snack.show = true
  } finally { recording.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-claim-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
}
.hc-claim-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.hc-form-hero { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-claim-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
