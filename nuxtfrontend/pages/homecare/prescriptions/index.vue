<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Prescriptions"
      subtitle="E-prescriptions issued for homecare patients and routed to partner pharmacies."
      eyebrow="MEDICATION ORDERS"
      icon="mdi-prescription"
      :chips="[
        { icon: 'mdi-file-document-edit', label: `${stats.draft} drafts` },
        { icon: 'mdi-clock-outline',      label: `${stats.pending} pending` },
        { icon: 'mdi-pill',               label: `${stats.dispensed} dispensed` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-plus" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">New prescription</span>
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

    <v-row dense>
      <v-col cols="12" lg="8">
        <HomecarePanel title="All prescriptions" subtitle="Search, filter and manage Rx orders"
                       icon="mdi-clipboard-text-clock" color="#0d9488">
          <v-row dense class="mb-2">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search Rx number, patient…" density="compact"
                            variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterStatus" :items="statusOptions"
                        label="Status" density="compact" variant="outlined"
                        hide-details clearable rounded="lg" />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="filterPharmacyStatus" :items="pharmacyStatusOptions"
                        label="Pharmacy status" density="compact" variant="outlined"
                        hide-details clearable rounded="lg" />
            </v-col>
          </v-row>

          <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

          <div v-if="filtered.length">
            <v-card v-for="rx in filtered" :key="rx.id" class="hc-rx-card mb-2"
                    rounded="xl" :elevation="0" @click="select(rx)">
              <div class="hc-rx-band" :style="{ background: pharmacyColor(rx.pharmacy_status).hex }" />
              <div class="pa-4">
                <div class="d-flex align-center ga-3">
                  <v-avatar size="44" color="teal" variant="tonal">
                    <v-icon icon="mdi-prescription" />
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ rx.rx_number || `RX-${rx.id}` }}</div>
                      <v-chip size="x-small" :color="statusColor(rx.status)" variant="tonal">
                        {{ rx.status }}
                      </v-chip>
                      <v-chip size="x-small"
                              :color="pharmacyColor(rx.pharmacy_status).vuetify"
                              variant="tonal">
                        Pharmacy: {{ rx.pharmacy_status }}
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-account" size="12" /> {{ rx.patient_name }}
                      <span class="mx-1">·</span>
                      <v-icon icon="mdi-doctor" size="12" /> {{ rx.prescribing_doctor_name || '—' }}
                      <span class="mx-1">·</span>
                      <v-icon icon="mdi-calendar" size="12" /> {{ formatDate(rx.issued_at || rx.created_at) }}
                    </div>
                  </div>
                  <v-menu>
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text"
                             size="small" @click.stop />
                    </template>
                    <v-list density="compact">
                      <v-list-item prepend-icon="mdi-eye" title="View"
                                   @click="select(rx)" />
                      <v-list-item v-if="rx.status === 'active' && rx.pharmacy_status === 'draft'"
                                   prepend-icon="mdi-send" title="Forward to pharmacy"
                                   @click="openForward(rx)" />
                      <v-list-item v-if="rx.pharmacy_status === 'substituted'"
                                   prepend-icon="mdi-check" title="Approve substitution"
                                   @click="approveSub(rx)" />
                    </v-list>
                  </v-menu>
                </div>
                <div v-if="rx.items?.length" class="mt-2 hc-items">
                  <v-chip v-for="(it, idx) in rx.items.slice(0, 4)" :key="idx"
                          size="x-small" variant="tonal" color="teal" class="mr-1 mb-1">
                    <v-icon start icon="mdi-pill" size="12" />
                    {{ it.medication_name }} · {{ it.dose }} {{ it.dose_unit }}
                  </v-chip>
                  <v-chip v-if="rx.items.length > 4" size="x-small" variant="text">
                    +{{ rx.items.length - 4 }} more
                  </v-chip>
                </div>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-prescription" title="No prescriptions"
                      message="Create one to get started." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="Pharmacy pipeline" icon="mdi-chart-donut" color="#7c3aed">
          <DonutRing :segments="pipelineSegments" :size="180" :thickness="18">
            <div class="text-h4 font-weight-bold">{{ items.length }}</div>
            <div class="text-caption text-medium-emphasis">total Rx</div>
          </DonutRing>
          <v-divider class="my-3" />
          <div v-for="r in pipelineRows" :key="r.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: r.bg }">
            <v-avatar size="28" :color="r.color" variant="flat" class="mr-2">
              <v-icon :icon="r.icon" color="white" size="14" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ r.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.count }} Rx</div>
            </div>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Top medications" icon="mdi-pill" color="#0284c7" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="(m, idx) in topMeds" :key="idx" rounded="lg">
              <template #prepend>
                <v-avatar size="32" color="info" variant="tonal">
                  <span class="text-caption font-weight-bold">{{ idx + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ m.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ m.count }} prescriptions</v-list-item-subtitle>
            </v-list-item>
            <EmptyState v-if="!topMeds.length" icon="mdi-pill-off" title="No data" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="720" scrollable>
      <v-card v-if="active" rounded="xl" class="overflow-hidden">
        <div class="hc-detail-hero pa-5 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="56" color="white" variant="flat">
              <v-icon icon="mdi-prescription" color="teal-darken-2" size="28" />
            </v-avatar>
            <div class="flex-grow-1 min-w-0">
              <div class="text-overline" style="opacity:.85;">PRESCRIPTION</div>
              <h2 class="text-h5 font-weight-bold ma-0">{{ active.rx_number || `RX-${active.id}` }}</h2>
              <div class="text-body-2" style="opacity:.85;">
                <v-icon icon="mdi-account" size="14" /> {{ active.patient_name }}
                · <v-icon icon="mdi-calendar" size="14" /> {{ formatDate(active.issued_at || active.created_at) }}
              </div>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="detailDialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <div class="d-flex flex-wrap ga-2 mb-3">
            <v-chip :color="statusColor(active.status)" variant="tonal">
              <v-icon start icon="mdi-circle-medium" /> Status: {{ active.status }}
            </v-chip>
            <v-chip :color="pharmacyColor(active.pharmacy_status).vuetify" variant="tonal">
              <v-icon start icon="mdi-store" /> Pharmacy: {{ active.pharmacy_status }}
            </v-chip>
            <v-chip v-if="active.pharmacy_name" variant="tonal" color="indigo">
              <v-icon start icon="mdi-store-marker" /> {{ active.pharmacy_name }}
            </v-chip>
          </div>

          <h4 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-pill" color="teal" /> Items ({{ active.items?.length || 0 }})
          </h4>
          <v-table density="compact" class="rounded-lg">
            <thead>
              <tr>
                <th>Medication</th><th>Dose</th><th>Frequency</th>
                <th>Duration</th><th>Qty</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(it, idx) in active.items || []" :key="idx">
                <td class="font-weight-bold">{{ it.medication_name }}</td>
                <td>{{ it.dose }} {{ it.dose_unit }}</td>
                <td>{{ it.frequency || '—' }}</td>
                <td>{{ it.duration_days ? it.duration_days + ' d' : '—' }}</td>
                <td>{{ it.quantity || '—' }}</td>
              </tr>
              <tr v-if="!active.items?.length">
                <td colspan="5" class="text-center text-medium-emphasis py-4">No items</td>
              </tr>
            </tbody>
          </v-table>

          <div v-if="active.notes" class="mt-3 hc-info-block pa-3 rounded-lg">
            <div class="text-caption text-medium-emphasis">Notes</div>
            <div class="text-body-2">{{ active.notes }}</div>
          </div>

          <!-- Safety alerts -->
          <div class="mt-4">
            <div class="d-flex align-center mb-2">
              <h4 class="text-subtitle-1 font-weight-bold">
                <v-icon icon="mdi-shield-alert" :color="safetyTopColor" /> Safety check
                <span v-if="safetyAlerts.length" class="text-caption text-medium-emphasis ml-1">
                  ({{ safetyAlerts.length }} alert{{ safetyAlerts.length === 1 ? '' : 's' }})
                </span>
              </h4>
              <v-spacer />
              <v-btn size="small" variant="tonal" color="teal" rounded="lg"
                     class="text-none" prepend-icon="mdi-shield-search"
                     :loading="safetyLoading" @click="runSafetyCheck(true)">Re-run check</v-btn>
            </div>
            <div v-if="!safetyAlerts.length" class="text-body-2 text-success">
              <v-icon icon="mdi-check-circle" /> No safety issues detected.
            </div>
            <v-alert v-for="a in safetyAlerts" :key="a.id || a.message"
                     :type="alertType(a.severity)" variant="tonal" class="mb-2"
                     density="comfortable" :icon="alertIcon(a.kind)">
              <div class="d-flex align-center ga-2">
                <strong class="flex-grow-1">{{ a.message }}</strong>
                <v-chip size="x-small" :color="severityColor(a.severity)" variant="flat">
                  {{ a.severity_label || a.severity }}
                </v-chip>
                <v-chip v-if="a.overridden" size="x-small" color="grey" variant="tonal">
                  overridden
                </v-chip>
              </div>
              <div v-if="a.detail" class="text-caption mt-1">{{ a.detail }}</div>
              <div v-if="a.id && !a.overridden" class="mt-2">
                <v-btn size="x-small" variant="text" color="warning"
                       prepend-icon="mdi-alert-octagon" @click="openOverride(a)">
                  Override
                </v-btn>
              </div>
              <div v-if="a.overridden" class="text-caption text-medium-emphasis mt-1">
                Overridden by {{ a.overridden_by_name || 'staff' }}: {{ a.override_reason }}
              </div>
            </v-alert>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="detailDialog = false">Close</v-btn>
          <v-btn v-if="active.pharmacy_status === 'draft'"
                 color="teal" variant="flat" rounded="lg" class="text-none"
                 prepend-icon="mdi-send" @click="openForward(active)">Forward to pharmacy</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- New / forward dialog -->
    <v-dialog v-model="dialog" max-width="780" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-prescription" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">NEW</div>
              <h3 class="text-h6 ma-0">Create prescription</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="dialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="create">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.patient" :items="patients"
                                item-title="name" item-value="id"
                                label="Patient *" variant="outlined" density="comfortable"
                                rounded="lg" prepend-inner-icon="mdi-account"
                                :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.rx_number" label="Rx number"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-pound" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
            </v-row>

            <v-divider class="my-3" />
            <div class="d-flex align-center mb-2">
              <h4 class="text-subtitle-1 font-weight-bold">
                <v-icon icon="mdi-pill" color="teal" class="mr-1" /> Items
              </h4>
              <v-spacer />
              <v-btn size="small" variant="tonal" color="teal" rounded="lg"
                     class="text-none" prepend-icon="mdi-plus" @click="addItem">Add item</v-btn>
            </div>
            <v-card v-for="(it, idx) in form.items" :key="idx"
                    class="pa-3 mb-2" rounded="lg" :elevation="0"
                    style="background: rgba(13,148,136,0.05);">
              <v-row dense>
                <v-col cols="12" md="4">
                  <v-text-field v-model="it.medication_name" label="Medication *"
                                variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="2">
                  <v-text-field v-model="it.dose" label="Dose" variant="outlined"
                                density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="2">
                  <v-text-field v-model="it.dose_unit" label="Unit" variant="outlined"
                                density="compact" rounded="lg" placeholder="mg" />
                </v-col>
                <v-col cols="6" md="2">
                  <v-text-field v-model="it.frequency" label="Frequency"
                                variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="1">
                  <v-text-field v-model.number="it.duration_days" label="Days"
                                type="number" variant="outlined" density="compact"
                                rounded="lg" />
                </v-col>
                <v-col cols="12" md="1" class="d-flex align-center">
                  <v-btn icon="mdi-delete" variant="text" color="error" size="small"
                         @click="form.items.splice(idx, 1)" />
                </v-col>
              </v-row>
            </v-card>
            <EmptyState v-if="!form.items.length" icon="mdi-pill-off" title="No items"
                        message="Add at least one medication." dense />
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-check" @click="create">
            Create prescription
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Forward dialog -->
    <v-dialog v-model="forwardDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-send" color="teal" class="mr-1" /> Forward to pharmacy
        </v-card-title>
        <v-card-text>
          <v-autocomplete v-model="forwardForm.pharmacy" :items="pharmacies"
                          item-title="name" item-value="id" label="Pharmacy *"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-store"
                          return-object />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="forwardDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="forwarding" @click="forward">Forward</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Override safety alert -->
    <v-dialog v-model="overrideDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-alert-octagon" color="warning" class="mr-1" />
          Override safety alert
        </v-card-title>
        <v-card-text>
          <v-alert v-if="overrideTarget" type="warning" variant="tonal" class="mb-3" density="compact">
            {{ overrideTarget.message }}
          </v-alert>
          <v-textarea v-model="overrideReason" label="Clinical reason *"
                      rows="3" auto-grow variant="outlined" rounded="lg" density="comfortable"
                      placeholder="Document why this alert is being overridden…" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="overrideDialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" class="text-none"
                 :disabled="!overrideReason.trim()" @click="submitOverride">Override</v-btn>
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

const items = ref([])
const patients = ref([])
const pharmacies = ref([])
const loading = ref(false)
const saving = ref(false)
const forwarding = ref(false)

const search = ref('')
const filterStatus = ref(null)
const filterPharmacyStatus = ref(null)

const dialog = ref(false)
const detailDialog = ref(false)
const forwardDialog = ref(false)
const active = ref(null)
const formRef = ref(null)
const target = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

// Safety
const safetyAlerts = ref([])
const safetyLoading = ref(false)
const overrideDialog = ref(false)
const overrideTarget = ref(null)
const overrideReason = ref('')
const safetyTopColor = computed(() => {
  const sev = (safetyAlerts.value[0] || {}).severity
  return sev === 'contraindicated' ? 'red'
       : sev === 'major' ? 'red'
       : sev === 'moderate' ? 'orange'
       : sev === 'minor' ? 'amber' : 'success'
})

const statusOptions = [
  { value: 'draft',     title: 'Draft' },
  { value: 'active',    title: 'Active' },
  { value: 'completed', title: 'Completed' },
  { value: 'cancelled', title: 'Cancelled' }
]
const pharmacyStatusOptions = [
  { value: 'draft',       title: 'Draft' },
  { value: 'pending',     title: 'Pending' },
  { value: 'accepted',    title: 'Accepted' },
  { value: 'substituted', title: 'Substituted' },
  { value: 'declined',    title: 'Declined' },
  { value: 'dispensed',   title: 'Dispensed' },
  { value: 'cancelled',   title: 'Cancelled' }
]

const blank = () => ({
  patient: null, rx_number: '', notes: '',
  items: [{ medication_name: '', dose: '', dose_unit: 'mg',
            frequency: '', duration_days: null, quantity: null }]
})
const form = reactive(blank())
const forwardForm = reactive({ pharmacy: null })

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/prescriptions/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load prescriptions'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
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
async function loadPharmacies() {
  try {
    const { data } = await $api.get('/tenants/', { params: { type: 'pharmacy', page_size: 100 } })
    const list = data?.results || data || []
    pharmacies.value = list.map(t => ({ id: t.id, name: t.name }))
  } catch { /* ignore */ }
}
onMounted(() => { load(); loadPatients(); loadPharmacies() })

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return items.value.filter(rx => {
    if (filterStatus.value && rx.status !== filterStatus.value) return false
    if (filterPharmacyStatus.value && rx.pharmacy_status !== filterPharmacyStatus.value) return false
    if (!q) return true
    return [rx.rx_number, rx.patient_name].filter(Boolean)
      .some(s => s.toLowerCase().includes(q))
  })
})

const stats = computed(() => {
  const list = items.value
  return {
    total: list.length,
    draft: list.filter(rx => rx.pharmacy_status === 'draft').length,
    pending: list.filter(rx => rx.pharmacy_status === 'pending').length,
    dispensed: list.filter(rx => rx.pharmacy_status === 'dispensed').length,
    declined: list.filter(rx => rx.pharmacy_status === 'declined').length
  }
})
const summary = computed(() => [
  { label: 'Total',     value: stats.value.total,     color: 'teal',    icon: 'mdi-prescription' },
  { label: 'Pending',   value: stats.value.pending,   color: 'warning', icon: 'mdi-clock-outline' },
  { label: 'Dispensed', value: stats.value.dispensed, color: 'success', icon: 'mdi-pill' },
  { label: 'Declined',  value: stats.value.declined,  color: 'error',   icon: 'mdi-alert' }
])

const pipelineRows = computed(() => pharmacyStatusOptions.map(o => ({
  label: o.title,
  color: pharmacyColor(o.value).hex,
  bg: `${pharmacyColor(o.value).hex}14`,
  icon: pharmacyIcon(o.value),
  count: items.value.filter(rx => rx.pharmacy_status === o.value).length
})))
const pipelineSegments = computed(() => pharmacyStatusOptions.map(o => ({
  label: o.title,
  value: items.value.filter(rx => rx.pharmacy_status === o.value).length,
  color: pharmacyColor(o.value).vuetify
})))

const topMeds = computed(() => {
  const tally = {}
  for (const rx of items.value) {
    for (const it of rx.items || []) {
      const k = (it.medication_name || '').trim()
      if (!k) continue
      tally[k] = (tally[k] || 0) + 1
    }
  }
  return Object.entries(tally)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count).slice(0, 5)
})

function statusColor(s) {
  return ({ draft: 'grey', active: 'teal', completed: 'info', cancelled: 'error' })[s] || 'grey'
}
function pharmacyColor(s) {
  return ({
    draft:       { hex: '#94a3b8', vuetify: 'grey' },
    pending:     { hex: '#f59e0b', vuetify: 'warning' },
    accepted:    { hex: '#0ea5e9', vuetify: 'info' },
    substituted: { hex: '#a855f7', vuetify: 'purple' },
    declined:    { hex: '#ef4444', vuetify: 'error' },
    dispensed:   { hex: '#10b981', vuetify: 'success' },
    cancelled:   { hex: '#64748b', vuetify: 'grey' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}
function pharmacyIcon(s) {
  return ({
    draft: 'mdi-file-document-edit', pending: 'mdi-clock-outline',
    accepted: 'mdi-check', substituted: 'mdi-swap-horizontal',
    declined: 'mdi-close-circle', dispensed: 'mdi-pill', cancelled: 'mdi-cancel'
  })[s] || 'mdi-circle'
}
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}

function select(rx) {
  active.value = rx
  detailDialog.value = true
  safetyAlerts.value = []
  runSafetyCheck(false)
}
function openCreate() { Object.assign(form, blank()); dialog.value = true }
function addItem() {
  form.items.push({ medication_name: '', dose: '', dose_unit: 'mg',
                    frequency: '', duration_days: null, quantity: null })
}
async function create() {
  if (!form.patient || !form.items.length) {
    snack.text = 'Pick a patient and add at least one item'; snack.color = 'warning'; snack.show = true; return
  }
  saving.value = true
  try {
    const { data } = await $api.post('/homecare/prescriptions/', form)
    items.value.unshift(data)
    dialog.value = false
    snack.text = 'Prescription created'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Create failed'
    snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}

function openForward(rx) {
  target.value = rx
  forwardForm.pharmacy = null
  forwardDialog.value = true
}

// ===== Safety check =====
function severityColor(s) {
  return ({ contraindicated: 'red', major: 'red', moderate: 'orange',
            minor: 'amber', info: 'grey' })[s] || 'grey'
}
function alertType(s) {
  return ({ contraindicated: 'error', major: 'error', moderate: 'warning',
            minor: 'info', info: 'info' })[s] || 'info'
}
function alertIcon(k) {
  return ({ allergy: 'mdi-allergy', interaction: 'mdi-pill-multiple',
            duplicate: 'mdi-content-duplicate' })[k] || 'mdi-shield-alert'
}
async function runSafetyCheck(persist = false) {
  if (!active.value?.id) return
  safetyLoading.value = true
  try {
    const url = `/homecare/prescriptions/${active.value.id}/safety-check/`
    const { data } = persist ? await $api.post(url) : await $api.get(url)
    safetyAlerts.value = data.alerts || []
  } catch {
    snack.text = 'Safety check failed'; snack.color = 'error'; snack.show = true
  } finally { safetyLoading.value = false }
}
function openOverride(alert) {
  overrideTarget.value = alert
  overrideReason.value = ''
  overrideDialog.value = true
}
async function submitOverride() {
  if (!overrideTarget.value || !overrideReason.value.trim()) return
  try {
    const { data } = await $api.post(
      `/homecare/prescriptions/${active.value.id}/alerts/${overrideTarget.value.id}/override/`,
      { reason: overrideReason.value.trim() }
    )
    const idx = safetyAlerts.value.findIndex(a => a.id === data.id)
    if (idx >= 0) safetyAlerts.value.splice(idx, 1, data)
    snack.text = 'Alert overridden'; snack.color = 'success'; snack.show = true
    overrideDialog.value = false
  } catch {
    snack.text = 'Override failed'; snack.color = 'error'; snack.show = true
  }
}
async function forward() {
  if (!target.value || !forwardForm.pharmacy) return
  forwarding.value = true
  try {
    const { data } = await $api.post(
      `/homecare/prescriptions/${target.value.id}/forward_to_pharmacy/`,
      { pharmacy_tenant_id: forwardForm.pharmacy.id, pharmacy_name: forwardForm.pharmacy.name }
    )
    const i = items.value.findIndex(x => x.id === target.value.id)
    if (i >= 0) items.value.splice(i, 1, data)
    if (active.value?.id === target.value.id) active.value = data
    snack.text = 'Forwarded to pharmacy'; snack.color = 'success'; snack.show = true
    forwardDialog.value = false
  } catch {
    snack.text = 'Forward failed'; snack.color = 'error'; snack.show = true
  } finally { forwarding.value = false }
}
async function approveSub(rx) {
  try {
    const { data } = await $api.post(`/homecare/prescriptions/${rx.id}/approve_substitution/`)
    const i = items.value.findIndex(x => x.id === rx.id)
    if (i >= 0) items.value.splice(i, 1, data)
    snack.text = 'Substitution approved'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Action failed'; snack.color = 'error'; snack.show = true
  }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(124,58,237,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
  transition: transform .15s ease, box-shadow .15s ease;
}
.hc-stat:hover { transform: translateY(-2px); box-shadow: 0 10px 28px -16px rgba(15,23,42,0.25); }
.hc-rx-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  cursor: pointer;
  overflow: hidden;
  transition: transform .12s ease, box-shadow .12s ease;
}
.hc-rx-card:hover { transform: translateY(-1px); box-shadow: 0 14px 28px -18px rgba(15,23,42,0.25); }
.hc-rx-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.hc-detail-hero { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
.hc-form-hero  { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
.hc-info-block {
  background: rgba(13,148,136,0.06);
  border: 1px dashed rgba(13,148,136,0.3);
}
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-rx-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
