<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-school-outline"
      eyebrow="OHSMS · Competence"
      title="Training & Competence"
      subtitle="Mandatory safety training, certificate currency and expiry tracking across every site."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus" @click="openCreate">
          Record training
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-book-open-variant</v-icon>
        <b>{{ courses.count.value }}</b> courses</span>
      <span class="ohs-chip"><v-icon size="12">mdi-certificate-outline</v-icon>
        <b>{{ records.count.value }}</b> records</span>
      <span v-if="stats.expiring" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-clock</v-icon>
        <b>{{ stats.expiring }}</b> expiring &lt; 60d</span>
      <span v-if="stats.expired" class="ohs-chip ohs-chip-danger">
        <v-icon size="12">mdi-certificate-outline</v-icon>
        <b>{{ stats.expired }}</b> expired</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Certificate currency" :value="`${stats.currency}%`" icon="mdi-shield-check-outline"
              :tone="stats.currency >= 90 ? 'ok' : stats.currency >= 70 ? 'warn' : 'err'"
              sub="valid vs records held" />
      <OhsKpi label="Mandatory courses" :value="stats.mandatory" icon="mdi-book-lock-open-outline" tone="primary"
              :sub="`${courses.count.value} total courses`" />
      <OhsKpi label="Expiring soon" :value="stats.expiring" icon="mdi-calendar-alert"
              :tone="stats.expiring ? 'warn' : 'ok'" sub="within 60 days" />
      <OhsKpi label="Expired" :value="stats.expired" icon="mdi-certificate-outline"
              :tone="stats.expired ? 'err' : 'ok'" sub="refresher required" />
      <OhsKpi label="Pass rate" :value="`${stats.passRate}%`" icon="mdi-check-decagram-outline"
              :tone="stats.passRate >= 90 ? 'ok' : 'warn'" sub="completed attempts" />
    </div>

    <v-row dense>
      <v-col cols="12" lg="4">
        <OhsPanel title="Course currency" subtitle="Valid certificates per course" icon="mdi-book-open-variant">
          <div v-for="c in courseStats" :key="c.id" class="mb-2">
            <div class="d-flex align-center justify-space-between" style="gap:8px">
              <span class="text-caption font-weight-medium text-truncate">
                {{ c.name }}
                <v-icon v-if="c.mandatory" size="11" color="warning" class="ml-1">mdi-lock</v-icon>
              </span>
              <span class="text-caption ohs-tabular" :style="{ color: pctColor(c.pct) }">{{ c.pct }}%</span>
            </div>
            <div class="ohs-meter mt-1" :style="{ color: pctColor(c.pct) }">
              <div class="ohs-meter-fill" :style="{ width: c.pct + '%' }" />
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ c.valid }} valid · {{ c.total }} records
            </div>
          </div>
          <div v-if="!courseStats.length" class="ohs-empty">No courses defined.</div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="8">
        <OhsPanel title="Training records" :subtitle="`${filtered.length} shown`"
                  icon="mdi-account-school-outline" flush>
          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search employee or certificate…"
                          prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                          hide-details single-line clearable style="max-width:250px" />
            <v-select v-model="courseFilter" :items="courseOptions" item-title="label" item-value="value"
                      placeholder="All courses" density="compact" variant="outlined" rounded="lg" hide-details
                      clearable style="max-width:250px" />
            <v-select v-model="expiryFilter" :items="expiryOptions" item-title="label" item-value="value"
                      placeholder="Any status" density="compact" variant="outlined" rounded="lg" hide-details
                      clearable style="max-width:190px" />
          </div>

          <div class="ohs-scroll" style="max-height:60vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th style="width:210px">Course</th>
                  <th style="width:110px">Completed</th>
                  <th style="width:110px">Expires</th>
                  <th style="width:80px" class="num">Score</th>
                  <th style="width:110px">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in filtered" :key="r.id">
                  <td>
                    <div class="d-flex align-center" style="gap:8px">
                      <span class="avatar-sm" :style="avatarStyle(r.employee_name)">{{ initialsOf(r.employee_name) }}</span>
                      <div>
                        <div class="font-weight-medium">{{ r.employee_name }}</div>
                        <div class="text-caption text-medium-emphasis ohs-mono">{{ r.employee_ref || '—' }}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-caption font-weight-medium">{{ r.course_name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ r.site_name || 'All sites' }}</div>
                  </td>
                  <td class="text-caption">{{ formatDate(r.completed_on) }}</td>
                  <td class="text-caption">{{ r.expires_on ? formatDate(r.expires_on) : 'No expiry' }}</td>
                  <td class="num">{{ r.score ?? '—' }}</td>
                  <td>
                    <span v-if="r.is_expired" class="ohs-badge ohs-badge--err">Expired</span>
                    <span v-else-if="r.days_to_expiry !== null && r.days_to_expiry <= 60"
                          class="ohs-badge ohs-badge--warn">
                      {{ r.days_to_expiry }}d left
                    </span>
                    <span v-else class="ohs-badge ohs-badge--ok">Valid</span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filtered.length" class="ohs-empty">No records match these filters.</div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- Create record -->
    <v-dialog v-model="createDialog" max-width="620">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-school-outline" title="Record a training completion"
                           subtitle="Expiry is calculated from the course validity period." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12">
              <v-select v-model="form.course" :items="courseOptions" item-title="label" item-value="value"
                        label="Course" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_name" label="Employee" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_ref" label="Employee ref" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.completed_on" type="date" label="Completed on"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="form.score" type="number" min="0" max="100" label="Score"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.certificate_ref" label="Certificate ref" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="records.saving.value"
                 :disabled="!form.course || !form.employee_name" @click="save">Save record</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'Training · OHSMS' })

const ohs = useOhs()

const records = ohs.resource('training-records')
const courses = ohs.resource('training-courses')
const lookups = ref({})
const search = ref('')
const courseFilter = ref(null)
const expiryFilter = ref(null)
const createDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  course: null, employee_name: '', employee_ref: '', site: null,
  completed_on: new Date().toISOString().slice(0, 10), score: 85, certificate_ref: '',
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const courseOptions = computed(() => (courses.items.value || []).map((c) => ({
  label: `${c.name}${c.code ? ` (${c.code})` : ''}`, value: c.id,
})))
const expiryOptions = [
  { label: 'Valid', value: 'valid' },
  { label: 'Expiring ≤ 60d', value: 'expiring' },
  { label: 'Expired', value: 'expired' },
]

const rows = computed(() => records.items.value || [])

const filtered = computed(() => rows.value.filter((r) => {
  if (courseFilter.value && r.course !== courseFilter.value) return false
  if (expiryFilter.value === 'expired' && !r.is_expired) return false
  if (expiryFilter.value === 'expiring' && !(r.days_to_expiry !== null && r.days_to_expiry >= 0 && r.days_to_expiry <= 60)) return false
  if (expiryFilter.value === 'valid' && r.is_expired) return false
  const q = search.value.trim().toLowerCase()
  if (q) {
    const hay = `${r.employee_name} ${r.employee_ref} ${r.course_name} ${r.certificate_ref}`.toLowerCase()
    if (!hay.includes(q)) return false
  }
  return true
}))

const stats = computed(() => {
  const all = rows.value
  const expired = all.filter((r) => r.is_expired).length
  const expiring = all.filter((r) => r.days_to_expiry !== null && r.days_to_expiry >= 0 && r.days_to_expiry <= 60).length
  const passed = all.filter((r) => r.result === 'pass').length
  const attempted = all.filter((r) => r.result !== 'pending').length
  return {
    expired,
    expiring,
    currency: all.length ? Math.round(((all.length - expired) / all.length) * 100) : 100,
    mandatory: (courses.items.value || []).filter((c) => c.is_mandatory).length,
    passRate: attempted ? Math.round((passed / attempted) * 100) : 100,
  }
})

const courseStats = computed(() => (courses.items.value || [])
  .map((c) => {
    const rs = rows.value.filter((r) => r.course === c.id)
    const valid = rs.filter((r) => !r.is_expired).length
    return {
      id: c.id, name: c.name, mandatory: c.is_mandatory,
      valid, total: rs.length,
      pct: rs.length ? Math.round((valid / rs.length) * 100) : 0,
    }
  })
  .sort((a, b) => (Number(b.mandatory) - Number(a.mandatory)) || (a.pct - b.pct))
  .slice(0, 10))

function pctColor(pct) {
  if (pct >= 90) return '#16a34a'
  if (pct >= 70) return '#f59e0b'
  return '#dc2626'
}
function avatarStyle(name) {
  const hue = hueOf(name)
  return { background: `hsl(${hue} 62% 92%)`, color: `hsl(${hue} 55% 32%)` }
}

async function load() {
  await Promise.all([
    records.list({ ordering: '-completed_on' }),
    courses.list(),
  ])
  lookups.value = await ohs.loadLookups()
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    course: courseOptions.value[0]?.value || null, employee_name: '', employee_ref: '',
    site: null, completed_on: new Date().toISOString().slice(0, 10), score: 85,
    certificate_ref: '',
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.site) delete payload.site
    await records.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Training record saved.' }
    await load()
  } catch (e) {
    error.value = records.message(e)
  }
}

function exportData() {
  exportCsv(`training_records_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'employee_name', label: 'Employee' },
    { key: 'employee_ref', label: 'Ref' },
    { key: 'course_name', label: 'Course' },
    { key: 'site_name', label: 'Site' },
    { key: 'completed_on', label: 'Completed' },
    { key: 'expires_on', label: 'Expires' },
    { key: 'score', label: 'Score' },
    { key: 'result_display', label: 'Result' },
    { value: (r) => (r.is_expired ? 'Expired' : 'Valid'), label: 'Currency' },
  ])
}

watch([courseFilter, expiryFilter], load)
onMounted(load)
</script>

<style scoped>
.avatar-sm {
  width: 26px; height: 26px; border-radius: 8px;
  display: inline-flex; align-items: center; justify-content: center;
  font-size: 10px; font-weight: 800; flex-shrink: 0;
}
</style>
