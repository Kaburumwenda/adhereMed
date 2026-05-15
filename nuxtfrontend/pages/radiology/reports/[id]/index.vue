<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <v-btn variant="text" class="text-none mb-1" prepend-icon="mdi-arrow-left" to="/radiology/reports">Back</v-btn>
        <h1 class="text-h5 font-weight-bold">Report #{{ reportId }}</h1>
      </div>
      <div v-if="report" class="d-flex" style="gap:8px">
        <v-btn v-if="report.report_status !== 'final'" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-pencil" @click="editing=true">Edit</v-btn>
        <v-btn v-if="report.report_status !== 'final'" color="success" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-check-decagram" @click="signReport">Sign (Final)</v-btn>
        <v-btn v-if="report.report_status === 'final'" variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-pencil-plus" @click="amendReport">Amend</v-btn>
      </div>
    </div>

    <v-row v-if="report">
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-5 mb-4" border>
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-subtitle-1 font-weight-bold">Report Details</h3>
            <v-chip size="small" :color="reportColor(report.report_status)" variant="tonal">{{ report.report_status_display }}</v-chip>
          </div>

          <template v-if="!editing">
            <div v-if="report.findings" class="mb-3"><div class="text-caption text-medium-emphasis mb-1">Findings</div><div style="white-space:pre-wrap">{{ report.findings }}</div></div>
            <div v-if="report.impression" class="mb-3"><div class="text-caption text-medium-emphasis mb-1">Impression</div><div style="white-space:pre-wrap">{{ report.impression }}</div></div>
            <div v-if="report.recommendation" class="mb-3"><div class="text-caption text-medium-emphasis mb-1">Recommendation</div><div style="white-space:pre-wrap">{{ report.recommendation }}</div></div>
          </template>

          <v-form v-else ref="editForm" @submit.prevent="saveEdit">
            <v-textarea v-model="editData.findings" label="Findings" rows="4" auto-grow variant="outlined" density="compact" class="mb-2" />
            <v-textarea v-model="editData.impression" label="Impression" rows="3" auto-grow variant="outlined" density="compact" class="mb-2" />
            <v-textarea v-model="editData.recommendation" label="Recommendation" rows="2" auto-grow variant="outlined" density="compact" class="mb-2" />
            <v-checkbox v-model="editData.critical_finding" label="Critical finding" density="compact" hide-details class="mb-2" />
            <div class="d-flex justify-end" style="gap:8px">
              <v-btn variant="tonal" class="text-none" @click="editing=false">Cancel</v-btn>
              <v-btn type="submit" color="primary" variant="flat" class="text-none" :loading="saving">Save</v-btn>
            </div>
          </v-form>

          <div class="text-caption text-medium-emphasis mt-3">Radiologist: {{ report.radiologist_name || '—' }} · Signed: {{ report.signed_at ? formatDate(report.signed_at) : 'Unsigned' }}</div>
        </v-card>

        <!-- Critical alerts -->
        <v-card v-if="alerts.length" rounded="lg" class="pa-5 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-3">
            <v-icon color="error" class="mr-1">mdi-alert-octagram</v-icon>Critical Finding Alerts
          </h3>
          <v-list density="compact" class="bg-transparent">
            <v-list-item v-for="a in alerts" :key="a.id" class="px-0">
              <v-list-item-title class="text-body-2 font-weight-medium">{{ a.finding_description }}</v-list-item-title>
              <v-list-item-subtitle class="text-caption">{{ a.severity_display }} · {{ a.communicated_to }} via {{ a.method }} · {{ formatDate(a.communicated_at) }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" :color="a.acknowledged ? 'success' : 'warning'" variant="tonal">{{ a.acknowledged ? 'Acknowledged' : 'Pending' }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 mb-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-2">Order Info</h3>
          <div class="text-caption text-medium-emphasis">Order #</div>
          <div class="font-weight-medium mb-1">{{ report.order }}</div>
          <v-btn variant="tonal" size="small" class="text-none" :to="`/radiology/orders/${report.order}`">View Order</v-btn>
        </v-card>
        <v-card v-if="report.template" rounded="lg" class="pa-4" border>
          <h3 class="text-subtitle-1 font-weight-bold mb-2">Template</h3>
          <div>{{ report.template }}</div>
        </v-card>
      </v-col>
    </v-row>
    <v-skeleton-loader v-else type="card,card" />
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const reportId = route.params.id
const report = ref(null)
const alerts = ref([])
const editing = ref(route.query.edit === '1')
const saving = ref(false)
const editData = reactive({ findings: '', impression: '', recommendation: '', critical_finding: false })

function reportColor(s) { return { draft: 'grey', preliminary: 'warning', final: 'success', amended: 'info', addendum: 'purple' }[s] || 'grey' }
function formatDate(d) { return d ? new Date(d).toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—' }

async function saveEdit() {
  saving.value = true
  try {
    await $api.patch(`/radiology/reports/${reportId}/`, editData)
    editing.value = false
    await load()
  } catch (e) { console.error(e) }
  saving.value = false
}

async function signReport() {
  try {
    await $api.post(`/radiology/reports/${reportId}/sign/`)
    await load()
  } catch (e) { console.error(e) }
}

async function amendReport() {
  editing.value = true
  editData.findings = report.value.findings
  editData.impression = report.value.impression
  editData.recommendation = report.value.recommendation
  editData.critical_finding = report.value.critical_finding
}

async function load() {
  try {
    const [rRes, aRes] = await Promise.allSettled([
      $api.get(`/radiology/reports/${reportId}/`),
      $api.get(`/radiology/critical-alerts/?report=${reportId}`),
    ])
    report.value = rRes.status === 'fulfilled' ? rRes.value.data : null
    if (report.value) Object.assign(editData, { findings: report.value.findings, impression: report.value.impression, recommendation: report.value.recommendation, critical_finding: report.value.critical_finding })
    alerts.value = aRes.status === 'fulfilled' ? (aRes.value.data?.results || aRes.value.data || []) : []
  } catch { }
}
onMounted(load)
</script>
