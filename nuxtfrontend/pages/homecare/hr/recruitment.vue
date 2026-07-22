<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Recruitment & Applicant Tracking"
      subtitle="Post job openings, track applicants through the hiring pipeline, and convert top candidates into team members."
      eyebrow="HR · RECRUITMENT"
      icon="mdi-account-plus-outline"
      :chips="[
        { icon: 'mdi-briefcase', label: `${jobs.length} jobs` },
        { icon: 'mdi-account-arrow-left', label: `${applicants.length} applicants` },
        { icon: 'mdi-account-clock', label: `${stageCounts.screening} in screening` },
        { icon: 'mdi-handshake', label: `${stageCounts.offer} offers` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="openJobDialog">
          <span class="text-teal-darken-2 font-weight-bold">Post a job</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Open Positions" :value="openJobs" icon="mdi-briefcase-open" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Total Applicants" :value="applicants.length" icon="mdi-account-arrow-left" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="In Interview" :value="stageCounts.interview" icon="mdi-account-question" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Hired This Month" :value="stageCounts.hired" icon="mdi-account-check" color="#10b981" /></v-col>
    </v-row>

    <v-row dense>
      <!-- Job Openings -->
      <v-col cols="12" lg="5">
        <HomecarePanel title="Job Openings" subtitle="Active requisitions" icon="mdi-briefcase" color="#0d9488">
          <v-text-field v-model="jobSearch" prepend-inner-icon="mdi-magnify" placeholder="Search jobs…"
                        density="compact" variant="outlined" hide-details clearable class="mb-2" />
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="job in filteredJobs" :key="job.id" rounded="lg" class="mb-1 hc-job-item"
                         :class="{ 'hc-job-active': selectedJob?.id === job.id }"
                         @click="selectJob(job)">
              <template #prepend>
                <v-avatar size="36" :color="jobColor(job)" variant="tonal">
                  <v-icon :icon="jobIcon(job)" size="18" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ job.title }}</v-list-item-title>
              <v-list-item-subtitle>{{ job.department }} · {{ job.employment_type }}</v-list-item-subtitle>
              <template #append>
                <v-chip size="x-small" variant="tonal" :color="job.status === 'open' ? 'success' : 'grey'">
                  {{ job.applicant_count || 0 }} applicants
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!filteredJobs.length" icon="mdi-briefcase-off" title="No jobs found" dense />
          </v-list>
        </HomecarePanel>
      </v-col>

      <!-- Applicants for selected job -->
      <v-col cols="12" lg="7">
        <HomecarePanel :title="selectedJob ? `Applicants — ${selectedJob.title}` : 'Applicant Pipeline'"
                       subtitle="Drag candidates through hiring stages" icon="mdi-account-group" color="#7c3aed">
          <div v-if="!selectedJob" class="text-center pa-6">
            <v-icon icon="mdi-arrow-left-bold" size="40" class="text-medium-emphasis mb-2" />
            <div class="text-body-1 text-medium-emphasis">Select a job opening to view applicants</div>
          </div>
          <template v-else>
            <div class="d-flex flex-wrap ga-2 mb-3">
              <v-select v-model="stageFilter" :items="stageOptions" item-title="label" item-value="value"
                        label="Stage" density="compact" variant="outlined" hide-details clearable
                        style="max-width:180px;" />
              <v-text-field v-model="applicantSearch" prepend-inner-icon="mdi-magnify" placeholder="Search name…"
                            density="compact" variant="outlined" hide-details clearable style="max-width:260px;" />
            </div>

            <v-data-table :headers="applicantHeaders" :items="filteredApplicants" :loading="loading" item-value="id" class="hc-table">
              <template #[`item.name`]="{ item }">
                <div class="d-flex align-center py-1">
                  <v-avatar size="32" :color="avatarColor(item.name)" variant="tonal" class="mr-2">
                    <span class="text-caption font-weight-bold">{{ initials(item.name) }}</span>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ item.name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ item.email }}</div>
                  </div>
                </div>
              </template>
              <template #[`item.applied_date`]="{ item }">
                {{ formatDate(item.applied_date) }}
              </template>
              <template #[`item.rating`]="{ item }">
                <v-rating :model-value="item.rating || 0" size="small" color="amber" density="compact" readonly />
              </template>
              <template #[`item.stage`]="{ item }">
                <v-select v-model="item.stage" :items="stageOptions" item-title="label" item-value="value"
                          density="compact" variant="outlined" hide-details
                          style="max-width:140px;" @update:model-value="moveApplicant(item)" />
              </template>
              <template #[`item.actions`]="{ item }">
                <v-menu location="bottom end">
                  <template #activator="{ props }">
                    <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
                  </template>
                  <v-list density="compact" min-width="200">
                    <v-list-item prepend-icon="mdi-eye" title="View profile" @click="viewApplicant(item)" />
                    <v-list-item prepend-icon="mdi-file-account" title="Resume" @click="downloadResume(item)" />
                    <v-list-item prepend-icon="mdi-account-check" title="Move to Offer" @click="setStage(item, 'offer')" />
                    <v-list-item prepend-icon="mdi-account-arrow-right" title="Convert to Employee" @click="convertToEmployee(item)" />
                    <v-divider />
                    <v-list-item prepend-icon="mdi-account-remove" title="Reject" base-color="error" @click="setStage(item, 'declined')" />
                  </v-list>
                </v-menu>
              </template>
            </v-data-table>
          </template>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Post job dialog -->
    <v-dialog v-model="jobDialog" max-width="680" scrollable>
      <v-card rounded="xl">
        <v-card-title class="text-h6 d-flex align-center">
          <v-icon :icon="editingJobId ? 'mdi-pencil' : 'mdi-briefcase-plus'" class="mr-2" />
          {{ editingJobId ? 'Edit job' : 'Post a new job' }}
        </v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <v-text-field v-model="jobForm.title" label="Job title *" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="jobForm.department" :items="departmentOptions" label="Department *"
                        density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="jobForm.employment_type" :items="employmentTypes" item-title="label" item-value="value"
                        label="Employment type" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="jobForm.location" label="Location" density="comfortable" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="jobForm.salary_min" label="Salary min (KSh)" type="number"
                            density="comfortable" variant="outlined" prefix="KSh" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="jobForm.salary_max" label="Salary max (KSh)" type="number"
                            density="comfortable" variant="outlined" prefix="KSh" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="jobForm.closing_date" label="Closing date" type="date"
                            density="comfortable" variant="outlined" />
            </v-col>
          </v-row>
          <v-textarea v-model="jobForm.description" label="Job description" rows="3" density="comfortable" variant="outlined" />
          <v-textarea v-model="jobForm.requirements" label="Requirements (one per line)" rows="3" density="comfortable" variant="outlined" />
          <v-switch v-model="jobForm.is_published" color="teal" label="Publish immediately" density="compact" hide-details />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="jobDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveJob">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Applicant profile dialog -->
    <v-dialog v-model="applicantDialog" max-width="620" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-avatar v-if="viewApplicantItem" size="40" :color="avatarColor(viewApplicantItem.name)" variant="tonal" class="mr-3">
            <span class="font-weight-bold">{{ initials(viewApplicantItem.name) }}</span>
          </v-avatar>
          {{ viewApplicantItem?.name }}
        </v-card-title>
        <v-divider />
        <v-card-text v-if="viewApplicantItem" style="max-height:65vh">
          <div class="d-flex flex-wrap ga-2 mb-3">
            <v-chip size="small" variant="tonal" prepend-icon="mdi-email">{{ viewApplicantItem.email }}</v-chip>
            <v-chip v-if="viewApplicantItem.phone" size="small" variant="tonal" prepend-icon="mdi-phone">{{ viewApplicantItem.phone }}</v-chip>
            <v-chip size="small" variant="tonal" :color="stageColor(viewApplicantItem.stage)" prepend-icon="mdi-flag">{{ stageLabel(viewApplicantItem.stage) }}</v-chip>
          </div>
          <div v-if="viewApplicantItem.cover_letter" class="mb-3">
            <div class="text-overline text-medium-emphasis mb-1">Cover letter</div>
            <div class="text-body-2">{{ viewApplicantItem.cover_letter }}</div>
          </div>
          <div class="text-overline text-medium-emphasis mb-1">Notes</div>
          <v-textarea v-model="viewApplicantItem.notes" rows="3" density="comfortable" variant="outlined" />
          <div class="d-flex align-center mt-2">
            <span class="text-body-2 mr-2">Rating:</span>
            <v-rating v-model="viewApplicantItem.rating" color="amber" density="compact" />
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn variant="text" prepend-icon="mdi-file-account" @click="downloadResume(viewApplicantItem)">Resume</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="applicantDialog = false">Close</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveApplicantNotes">Save notes</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const jobs = ref([])
const applicants = ref([])
const selectedJob = ref(null)
const loading = ref(false)
const saving = ref(false)
const jobSearch = ref('')
const applicantSearch = ref('')
const stageFilter = ref(null)
const jobDialog = ref(false)
const applicantDialog = ref(false)
const editingJobId = ref(null)
const viewApplicantItem = ref(null)

const blankJob = () => ({
  title: '', department: '', employment_type: 'full_time', location: '',
  salary_min: null, salary_max: null, closing_date: '', description: '',
  requirements: '', is_published: true,
})
const jobForm = reactive(blankJob())

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const departmentOptions = ['Nursing', 'Caregiving', 'Administration', 'Pharmacy', 'Laboratory', 'Radiology', 'Finance', 'IT', 'Operations']
const employmentTypes = [
  { value: 'full_time', label: 'Full-time' },
  { value: 'part_time', label: 'Part-time' },
  { value: 'contract', label: 'Contract' },
  { value: 'internship', label: 'Internship' },
  { value: 'temporary', label: 'Temporary' },
]
const stageOptions = [
  { value: 'applied', label: 'Applied' },
  { value: 'screening', label: 'Screening' },
  { value: 'interview', label: 'Interview' },
  { value: 'offer', label: 'Offer' },
  { value: 'hired', label: 'Hired' },
  { value: 'declined', label: 'Declined' },
]
const stageMeta = {
  applied: { color: 'info', icon: 'mdi-email-outline' },
  screening: { color: 'teal', icon: 'mdi-account-search' },
  interview: { color: 'amber', icon: 'mdi-account-question' },
  offer: { color: 'purple', icon: 'mdi-handshake' },
  hired: { color: 'success', icon: 'mdi-account-check' },
  declined: { color: 'error', icon: 'mdi-account-remove' },
}
function stageColor(s) { return (stageMeta[s] || {}).color || 'grey' }
function stageLabel(s) { return stageOptions.find(o => o.value === s)?.label || s }

const applicantHeaders = [
  { title: 'Candidate', key: 'name' },
  { title: 'Applied', key: 'applied_date' },
  { title: 'Rating', key: 'rating', sortable: false },
  { title: 'Stage', key: 'stage', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const filteredJobs = computed(() => {
  const q = jobSearch.value.toLowerCase()
  return jobs.value.filter(j => !q || `${j.title} ${j.department}`.toLowerCase().includes(q))
})
const filteredApplicants = computed(() => {
  const q = applicantSearch.value.toLowerCase()
  return applicants.value.filter(a => {
    if (stageFilter.value && a.stage !== stageFilter.value) return false
    if (q && !`${a.name} ${a.email}`.toLowerCase().includes(q)) return false
    return true
  })
})
const openJobs = computed(() => jobs.value.filter(j => j.status === 'open').length)
const stageCounts = computed(() => {
  const c = { applied: 0, screening: 0, interview: 0, offer: 0, hired: 0, declined: 0 }
  applicants.value.forEach(a => { if (c[a.stage] !== undefined) c[a.stage]++ })
  return c
})

function jobColor(job) {
  const map = { Nursing: 'pink', Caregiving: 'teal', Administration: 'indigo', Pharmacy: 'green', Laboratory: 'purple', Radiology: 'cyan', Finance: 'amber', IT: 'blue', Operations: 'orange' }
  return map[job?.department] || 'teal'
}
function jobIcon(job) {
  const map = { Nursing: 'mdi-stethoscope', Caregiving: 'mdi-hand-heart', Administration: 'mdi-desk', Pharmacy: 'mdi-pill', Laboratory: 'mdi-test-tube', Radiology: 'mdi-radiology', Finance: 'mdi-finance', IT: 'mdi-laptop', Operations: 'mdi-cog' }
  return map[job?.department] || 'mdi-briefcase'
}
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }

async function loadJobs() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/hr/jobs/', { params: { page_size: 500 } })
    jobs.value = data?.results || data || []
    if (jobs.value.length && !selectedJob.value) selectJob(jobs.value[0])
  } catch (e) {
    console.warn('load jobs failed', e)
    jobs.value = []
  } finally { loading.value = false }
}
function selectJob(job) {
  selectedJob.value = job
  loadApplicants(job.id)
}
async function loadApplicants(jobId) {
  try {
    const { data } = await $api.get('/homecare/hr/applicants/', { params: { job: jobId, page_size: 500 } })
    applicants.value = data?.results || data || []
  } catch (e) {
    console.warn('load applicants failed', e)
    applicants.value = []
  }
}

function openJobDialog() {
  editingJobId.value = null
  Object.assign(jobForm, blankJob())
  jobDialog.value = true
}
function editJob(job) {
  editingJobId.value = job.id
  Object.assign(jobForm, {
    title: job.title || '', department: job.department || '', employment_type: job.employment_type || 'full_time',
    location: job.location || '', salary_min: job.salary_min ?? null, salary_max: job.salary_max ?? null,
    closing_date: job.closing_date || '', description: job.description || '',
    requirements: job.requirements || '', is_published: job.is_published ?? true,
  })
  jobDialog.value = true
}
async function saveJob() {
  if (!jobForm.title) { notify('Job title is required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...jobForm }
    if (payload.requirements) payload.requirements = payload.requirements.split('\n').filter(Boolean).join('\n')
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    if (editingJobId.value) {
      await $api.patch(`/homecare/hr/jobs/${editingJobId.value}/`, payload)
      notify('Job updated.')
    } else {
      await $api.post('/homecare/hr/jobs/', payload)
      notify('Job posted.')
    }
    jobDialog.value = false
    loadJobs()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save job.', 'error')
  } finally { saving.value = false }
}

async function moveApplicant(item) {
  try {
    await $api.patch(`/homecare/hr/applicants/${item.id}/`, { stage: item.stage })
    notify(`Moved to ${stageLabel(item.stage)}.`)
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update stage.', 'error')
  }
}
function setStage(item, stage) {
  item.stage = stage
  moveApplicant(item)
}
function viewApplicant(item) {
  viewApplicantItem.value = { ...item }
  applicantDialog.value = true
}
async function saveApplicantNotes() {
  if (!viewApplicantItem.value) return
  saving.value = true
  try {
    await $api.patch(`/homecare/hr/applicants/${viewApplicantItem.value.id}/`, {
      notes: viewApplicantItem.value.notes,
      rating: viewApplicantItem.value.rating,
    })
    notify('Notes saved.')
    applicantDialog.value = false
    if (selectedJob.value) loadApplicants(selectedJob.value.id)
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save.', 'error')
  } finally { saving.value = false }
}
function downloadResume(item) {
  if (item?.resume_url) window.open(item.resume_url, '_blank')
  else notify('No resume on file.', 'info')
}
async function convertToEmployee(item) {
  saving.value = true
  try {
    await $api.post(`/homecare/hr/applicants/${item.id}/convert/`, {})
    notify(`${item.name} converted to employee.`)
    if (selectedJob.value) loadApplicants(selectedJob.value.id)
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to convert.', 'error')
  } finally { saving.value = false }
}

onMounted(loadJobs)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
.hc-job-item { cursor: pointer; transition: background 0.15s; }
.hc-job-item:hover { background: rgba(13,148,136,0.06); }
.hc-job-active { background: rgba(13,148,136,0.1) !important; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
