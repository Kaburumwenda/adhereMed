<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="purple-lighten-5" size="48" class="mr-3">
          <v-icon color="purple-darken-2" size="28">mdi-pill-multiple</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">{{ $t('interactions.title') }}</h1>
          <div class="text-body-2 text-medium-emphasis">Maintain interaction database · Run safety checks</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-magnify-plus" @click="openCheck">Check Drugs</v-btn>
      <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-plus" @click="openCreate">{{ $t('interactions.newInteraction') }}</v-btn>
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

    <v-card flat rounded="xl" border class="mb-3">
      <v-card-text class="d-flex flex-wrap" style="gap:12px">
        <v-text-field v-model="search" label="Search" prepend-inner-icon="mdi-magnify"
                      variant="outlined" density="comfortable" hide-details style="min-width:240px"
                      @update:model-value="reload" />
        <v-select v-model="severityFilter" :items="severityOptions" label="Severity"
                  variant="outlined" density="comfortable" hide-details clearable
                  style="min-width:180px" @update:model-value="reload" />
      </v-card-text>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="items" :loading="loading" items-per-page="10">
        <template #item.pair="{ item }">
          <div class="font-weight-bold">{{ item.drug_a_name }} ↔ {{ item.drug_b_name }}</div>
        </template>
        <template #item.severity="{ item }">
          <v-chip size="small" variant="flat" :color="severityColor(item.severity)" class="text-capitalize">
            {{ item.severity }}
          </v-chip>
        </template>
        <template #item.description="{ item }">
          <span class="text-truncate d-inline-block" style="max-width:320px">{{ item.description }}</span>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="remove(item)" />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create/Edit -->
    <v-dialog v-model="formDialog" max-width="640" persistent>
      <v-card rounded="xl">
        <v-card-title>
          <v-icon class="mr-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          {{ form.id ? 'Edit' : 'New' }} Interaction
        </v-card-title>
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-autocomplete v-model="form.drug_a" :items="medOptions" :loading="medSearching"
                              label="Drug A *" item-title="generic_name" item-value="id"
                              variant="outlined" density="comfortable"
                              :search="medSearch" @update:search="searchMeds" />
            </v-col>
            <v-col cols="12" md="6">
              <v-autocomplete v-model="form.drug_b" :items="medOptions" :loading="medSearching"
                              label="Drug B *" item-title="generic_name" item-value="id"
                              variant="outlined" density="comfortable"
                              :search="medSearch" @update:search="searchMeds" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.severity" :items="severityOptions" label="Severity *"
                        variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.source" label="Source (e.g. BNF, FDA)"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="Mechanism / description *"
                          rows="2" auto-grow variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.clinical_advice" label="Clinical advice"
                          rows="2" auto-grow variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ $t('common.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Check dialog -->
    <v-dialog v-model="checkDialog" max-width="720">
      <v-card rounded="xl">
        <v-card-title><v-icon class="mr-2" color="primary">mdi-magnify-plus</v-icon>Check Drug Interactions</v-card-title>
        <v-card-text>
          <v-autocomplete v-model="checkSelected" :items="medOptions" :loading="medSearching"
                          label="Add medications" item-title="generic_name" item-value="id"
                          multiple chips closable-chips variant="outlined" density="comfortable"
                          :search="medSearch" @update:search="searchMeds" />
          <v-btn color="primary" class="mt-2" :loading="checking" @click="runCheck"
                 prepend-icon="mdi-shield-search" :disabled="checkSelected.length < 2">{{ $t('interactions.runCheck') }}</v-btn>

          <v-divider class="my-3" />
          <div v-if="checkResult">
            <v-alert v-if="checkResult.count === 0" type="success" variant="tonal" class="mb-2">
              No interactions detected among {{ checkResult.resolved_count }} drugs.
            </v-alert>
            <v-alert v-else
                     :type="checkResult.highest_severity === 'contraindicated' ? 'error' : checkResult.highest_severity === 'major' ? 'warning' : 'info'"
                     variant="tonal" class="mb-2">
              Found <strong>{{ checkResult.count }}</strong> interaction(s).
              Highest severity: <strong class="text-capitalize">{{ checkResult.highest_severity }}</strong>.
            </v-alert>
            <v-list density="compact">
              <v-list-item v-for="r in checkResult.interactions" :key="r.id">
                <template #prepend>
                  <v-chip size="small" variant="flat" :color="severityColor(r.severity)" class="text-capitalize mr-2">
                    {{ r.severity }}
                  </v-chip>
                </template>
                <v-list-item-title>{{ r.drug_a_name }} ↔ {{ r.drug_b_name }}</v-list-item-title>
                <v-list-item-subtitle>{{ r.description }}</v-list-item-subtitle>
                <div v-if="r.clinical_advice" class="text-caption text-primary mt-1">
                  💡 {{ r.clinical_advice }}
                </div>
              </v-list-item>
            </v-list>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="checkDialog = false">{{ $t('common.close') }}</v-btn>
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
const checking = ref(false)
const items = ref([])
const search = ref('')
const severityFilter = ref(null)
const formDialog = ref(false)
const checkDialog = ref(false)
const checkSelected = ref([])
const checkResult = ref(null)
const form = ref({})
const medOptions = ref([])
const medSearch = ref('')
const medSearching = ref(false)
const snack = ref({ show: false, color: 'success', text: '' })

const severityOptions = [
  { title: 'Minor', value: 'minor' },
  { title: 'Moderate', value: 'moderate' },
  { title: 'Major', value: 'major' },
  { title: 'Contraindicated', value: 'contraindicated' },
]

const headers = [
  { title: 'Drug Pair', key: 'pair' },
  { title: 'Severity', key: 'severity', width: 150 },
  { title: 'Description', key: 'description' },
  { title: 'Source', key: 'source', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 110 },
]

const kpis = computed(() => {
  const by = (s) => items.value.filter(i => i.severity === s).length
  return [
    { label: 'Total Pairs', value: items.value.length, icon: 'mdi-database', color: 'purple' },
    { label: 'Contraindicated', value: by('contraindicated'), icon: 'mdi-cancel', color: 'red' },
    { label: 'Major', value: by('major'), icon: 'mdi-alert', color: 'orange' },
    { label: 'Moderate', value: by('moderate'), icon: 'mdi-alert-circle-outline', color: 'amber' },
  ]
})

function severityColor(s) {
  return ({ minor: 'blue', moderate: 'amber', major: 'orange', contraindicated: 'red' })[s] || 'grey'
}

async function reload() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (search.value) params.set('search', search.value)
    if (severityFilter.value) params.set('severity', severityFilter.value)
    const r = await $api.get(`/medications/interactions/?${params.toString()}`)
    items.value = r.data?.results || r.data || []
  } catch { showSnack('Failed to load', 'error') }
  finally { loading.value = false }
}

let searchTimer = null
function searchMeds(q) {
  medSearch.value = q
  clearTimeout(searchTimer)
  if (!q || q.length < 2) return
  searchTimer = setTimeout(async () => {
    medSearching.value = true
    try {
      const r = await $api.get(`/medications/search/?q=${encodeURIComponent(q)}`)
      medOptions.value = r.data?.results || r.data || []
    } finally { medSearching.value = false }
  }, 300)
}

function openCreate() {
  form.value = { drug_a: null, drug_b: null, severity: 'moderate', description: '', clinical_advice: '', source: '' }
  formDialog.value = true
}
function openEdit(item) {
  form.value = { ...item }
  // ensure dropdowns can render
  medOptions.value = [
    { id: item.drug_a, generic_name: item.drug_a_name },
    { id: item.drug_b, generic_name: item.drug_b_name },
  ]
  formDialog.value = true
}

async function save() {
  saving.value = true
  try {
    if (form.value.id) await $api.patch(`/medications/interactions/${form.value.id}/`, form.value)
    else await $api.post('/medications/interactions/', form.value)
    showSnack('Saved', 'success')
    formDialog.value = false
    await reload()
  } catch (e) {
    showSnack(JSON.stringify(e?.response?.data || 'Failed'), 'error')
  } finally { saving.value = false }
}

async function remove(item) {
  if (!confirm(`Delete interaction ${item.drug_a_name} ↔ ${item.drug_b_name}?`)) return
  try {
    await $api.delete(`/medications/interactions/${item.id}/`)
    showSnack('Deleted', 'success'); await reload()
  } catch { showSnack('Failed', 'error') }
}

function openCheck() { checkSelected.value = []; checkResult.value = null; checkDialog.value = true }

async function runCheck() {
  checking.value = true
  try {
    const r = await $api.post('/medications/check-interactions/', { medication_ids: checkSelected.value })
    checkResult.value = r.data
  } catch { showSnack('Check failed', 'error') }
  finally { checking.value = false }
}

function showSnack(text, color = 'success') { snack.value = { show: true, color, text } }
onMounted(reload)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

</style>
