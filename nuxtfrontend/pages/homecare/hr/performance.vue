<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Performance Management"
      subtitle="Set goals, run review cycles, track KPIs, and build a culture of continuous feedback."
      eyebrow="HR · PERFORMANCE"
      icon="mdi-chart-timeline-variant-shimmer"
      :chips="[
        { icon: 'mdi-target', label: `${activeGoals} active goals` },
        { icon: 'mdi-clipboard-check', label: `${pendingReviews} reviews due` },
        { icon: 'mdi-star', label: `${avgRating} avg rating` },
        { icon: 'mdi-trophy', label: `${topPerformers} top performers` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-clipboard-plus"
               class="text-none" @click="openReviewDialog">
          <span class="text-teal-darken-2 font-weight-bold">New review</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Active Goals" :value="activeGoals" icon="mdi-target" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Reviews Due" :value="pendingReviews" icon="mdi-clipboard-check" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Avg Rating" :value="avgRating" suffix="/5" icon="mdi-star" color="#8b5cf6" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Top Performers" :value="topPerformers" icon="mdi-trophy" color="#10b981" /></v-col>
    </v-row>

    <v-tabs v-model="tab" color="teal" density="compact" class="mb-3">
      <v-tab value="reviews"><v-icon start icon="mdi-clipboard-text" />Reviews</v-tab>
      <v-tab value="goals"><v-icon start icon="mdi-target" />Goals & OKRs</v-tab>
      <v-tab value="leaderboard"><v-icon start icon="mdi-trophy" />Leaderboard</v-tab>
    </v-tabs>

    <!-- REVIEWS TAB -->
    <template v-if="tab === 'reviews'">
      <HomecarePanel title="Performance Reviews" subtitle="Review cycles & feedback" icon="mdi-clipboard-text" color="#0d9488">
        <template #actions>
          <v-select v-model="reviewStatusFilter" :items="reviewStatuses" item-title="label" item-value="value"
                    density="compact" variant="outlined" hide-details clearable
                    placeholder="Status" style="max-width:160px;" />
        </template>
        <v-data-table :headers="reviewHeaders" :items="filteredReviews" :loading="loading" item-value="id" class="hc-table">
          <template #[`item.employee_name`]="{ item }">
            <div class="d-flex align-center">
              <v-avatar size="28" :color="avatarColor(item.employee_name)" variant="tonal" class="mr-2">
                <span class="text-caption font-weight-bold">{{ initials(item.employee_name) }}</span>
              </v-avatar>
              <div>
                <div class="font-weight-medium text-body-2">{{ item.employee_name }}</div>
                <div class="text-caption text-medium-emphasis">{{ item.job_title }}</div>
              </div>
            </div>
          </template>
          <template #[`item.cycle`]="{ item }">{{ item.cycle_name || '—' }}</template>
          <template #[`item.rating`]="{ item }">
            <v-rating :model-value="item.rating || 0" size="small" color="amber" density="compact" readonly />
          </template>
          <template #[`item.review_date`]="{ item }">{{ formatDate(item.review_date) }}</template>
          <template #[`item.status`]="{ item }"><StatusChip :status="item.status" /></template>
          <template #[`item.actions`]="{ item }">
            <v-btn size="small" variant="text" prepend-icon="mdi-pencil" @click="openReviewDialog(item)">Edit</v-btn>
          </template>
        </v-data-table>
      </HomecarePanel>
    </template>

    <!-- GOALS TAB -->
    <template v-if="tab === 'goals'">
      <HomecarePanel title="Goals & OKRs" subtitle="Track individual and team objectives" icon="mdi-target" color="#7c3aed">
        <template #actions>
          <v-btn variant="tonal" color="teal" size="small" prepend-icon="mdi-plus" @click="openGoalDialog">Set goal</v-btn>
        </template>
        <v-row dense>
          <v-col v-for="g in goals" :key="g.id" cols="12" md="6" lg="4">
            <v-card rounded="lg" variant="outlined" class="pa-4 h-100">
              <div class="d-flex align-center mb-2">
                <v-avatar size="32" :color="avatarColor(g.employee_name)" variant="tonal" class="mr-2">
                  <span class="text-caption font-weight-bold">{{ initials(g.employee_name) }}</span>
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="font-weight-bold text-body-2">{{ g.title }}</div>
                  <div class="text-caption text-medium-emphasis">{{ g.employee_name }} · {{ g.category }}</div>
                </div>
                <v-chip size="x-small" variant="tonal" :color="goalColor(g)">{{ g.progress }}%</v-chip>
              </div>
              <p class="text-body-2 text-medium-emphasis mb-3">{{ g.description }}</p>
              <v-progress-linear :model-value="g.progress" :color="goalColor(g)" height="6" rounded class="mb-2" />
              <div class="d-flex justify-space-between text-caption text-medium-emphasis">
                <span>Due: {{ formatDate(g.due_date) }}</span>
                <v-btn size="x-small" variant="text" @click="updateGoalProgress(g)">Update</v-btn>
              </div>
            </v-card>
          </v-col>
        </v-row>
        <EmptyState v-if="!goals.length" icon="mdi-target-off" title="No goals set" />
      </HomecarePanel>
    </template>

    <!-- LEADERBOARD TAB -->
    <template v-if="tab === 'leaderboard'">
      <HomecarePanel title="Performance Leaderboard" subtitle="Top performers this cycle" icon="mdi-trophy" color="#f59e0b">
        <v-list density="compact" class="bg-transparent pa-0">
          <v-list-item v-for="(p, idx) in leaderboard" :key="p.id" rounded="lg" class="mb-2">
            <template #prepend>
              <v-avatar size="40" :color="medalColor(idx)" variant="tonal">
                <v-icon :icon="medalIcon(idx)" size="20" />
              </v-avatar>
            </template>
            <v-list-item-title class="font-weight-bold">{{ p.name }}</v-list-item-title>
            <v-list-item-subtitle>{{ p.job_title }} · {{ p.department }}</v-list-item-subtitle>
            <template #append>
              <div class="text-right">
                <v-rating :model-value="p.avg_rating || 0" size="small" color="amber" density="compact" readonly />
                <div class="text-caption text-medium-emphasis">{{ p.goals_completed }} goals · {{ p.reviews }} reviews</div>
              </div>
            </template>
          </v-list-item>
          <EmptyState v-if="!leaderboard.length" icon="mdi-trophy-off" title="No data yet" dense />
        </v-list>
      </HomecarePanel>
    </template>

    <!-- Review dialog -->
    <v-dialog v-model="reviewDialog" max-width="620" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon :icon="editingReviewId ? 'mdi-pencil' : 'mdi-clipboard-plus'" class="mr-2" />
          {{ editingReviewId ? 'Edit review' : 'New performance review' }}
        </v-card-title>
        <v-divider />
        <v-card-text style="max-height:72vh">
          <v-select v-model="reviewForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Employee *" density="comfortable" variant="outlined" />
          <v-text-field v-model="reviewForm.cycle_name" label="Review cycle" placeholder="Q3 2026 Annual Review"
                        density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="reviewForm.review_date" label="Review date" type="date" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6">
              <v-select v-model="reviewForm.review_type" :items="reviewTypes" item-title="label" item-value="value"
                        label="Type" density="comfortable" variant="outlined" />
            </v-col>
          </v-row>
          <div class="text-overline text-medium-emphasis mt-2">Ratings</div>
          <div class="d-flex align-center mb-2">
            <span class="text-body-2 mr-3">Overall:</span>
            <v-rating v-model="reviewForm.rating" color="amber" density="compact" />
          </div>
          <v-row dense>
            <v-col cols="6" v-for="c in competencies" :key="c.key">
              <div class="text-caption text-medium-emphasis">{{ c.label }}</div>
              <v-rating v-model="reviewForm[c.key]" color="amber" size="small" density="compact" />
            </v-col>
          </v-row>
          <v-textarea v-model="reviewForm.strengths" label="Strengths" rows="2" density="comfortable" variant="outlined" class="mt-2" />
          <v-textarea v-model="reviewForm.areas_for_improvement" label="Areas for improvement" rows="2" density="comfortable" variant="outlined" />
          <v-textarea v-model="reviewForm.comments" label="Additional comments" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="reviewDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveReview">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Goal dialog -->
    <v-dialog v-model="goalDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-target" class="mr-2" />Set Goal</v-card-title>
        <v-divider />
        <v-card-text>
          <v-select v-model="goalForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Employee *" density="comfortable" variant="outlined" />
          <v-text-field v-model="goalForm.title" label="Goal title *" density="comfortable" variant="outlined" />
          <v-select v-model="goalForm.category" :items="goalCategories" label="Category"
                    density="comfortable" variant="outlined" />
          <v-textarea v-model="goalForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
          <v-text-field v-model="goalForm.due_date" label="Due date" type="date" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="goalDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveGoal">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Progress dialog -->
    <v-dialog v-model="progressDialog" max-width="400">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-update" class="mr-2" />Update Progress</v-card-title>
        <v-divider />
        <v-card-text>
          <div class="text-body-2 mb-2">{{ progressGoal?.title }}</div>
          <v-slider v-model="progressValue" :min="0" :max="100" :step="5" color="teal" thumb-label />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="progressDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveGoalProgress">Update</v-btn>
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

const tab = ref('reviews')
const reviews = ref([])
const goals = ref([])
const leaderboard = ref([])
const employees = ref([])
const loading = ref(false)
const saving = ref(false)
const reviewStatusFilter = ref(null)
const reviewDialog = ref(false)
const goalDialog = ref(false)
const progressDialog = ref(false)
const editingReviewId = ref(null)
const progressGoal = ref(null)
const progressValue = ref(0)

const competencies = [
  { key: 'quality_of_work', label: 'Quality of Work' },
  { key: 'teamwork', label: 'Teamwork' },
  { key: 'communication', label: 'Communication' },
  { key: 'punctuality', label: 'Punctuality' },
  { key: 'initiative', label: 'Initiative' },
  { key: 'patient_care', label: 'Patient Care' },
]
const blankReview = () => ({
  employee: null, cycle_name: '', review_date: new Date().toISOString().slice(0, 10),
  review_type: 'annual', rating: 3, strengths: '', areas_for_improvement: '', comments: '',
  quality_of_work: 3, teamwork: 3, communication: 3, punctuality: 3, initiative: 3, patient_care: 3,
})
const reviewForm = reactive(blankReview())
const blankGoal = () => ({ employee: null, title: '', category: '', description: '', due_date: '' })
const goalForm = reactive(blankGoal())

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const reviewStatuses = [
  { value: 'draft', label: 'Draft' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'completed', label: 'Completed' },
  { value: 'acknowledged', label: 'Acknowledged' },
]
const reviewTypes = [
  { value: 'annual', label: 'Annual' },
  { value: 'quarterly', label: 'Quarterly' },
  { value: 'probation', label: 'Probation' },
  { value: 'mid_year', label: 'Mid-year' },
  { value: '360', label: '360 Feedback' },
]
const goalCategories = ['Clinical Excellence', 'Operational', 'Leadership', 'Learning & Development', 'Patient Satisfaction', 'Innovation', 'Compliance']

const reviewHeaders = [
  { title: 'Employee', key: 'employee_name' },
  { title: 'Cycle', key: 'cycle' },
  { title: 'Rating', key: 'rating', sortable: false },
  { title: 'Date', key: 'review_date' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false },
]

const filteredReviews = computed(() => {
  if (!reviewStatusFilter.value) return reviews.value
  return reviews.value.filter(r => r.status === reviewStatusFilter.value)
})
const activeGoals = computed(() => goals.value.filter(g => g.progress < 100).length)
const pendingReviews = computed(() => reviews.value.filter(r => r.status === 'draft' || r.status === 'in_progress').length)
const avgRating = computed(() => {
  const rated = reviews.value.filter(r => r.rating)
  if (!rated.length) return '—'
  return (rated.reduce((s, r) => s + r.rating, 0) / rated.length).toFixed(1)
})
const topPerformers = computed(() => leaderboard.value.filter(p => p.avg_rating >= 4.5).length)

function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function goalColor(g) {
  if (g.progress >= 100) return 'success'
  if (g.progress >= 50) return 'teal'
  if (g.progress >= 25) return 'warning'
  return 'error'
}
function medalColor(idx) { return ['amber', 'grey', 'orange'][idx] || 'teal' }
function medalIcon(idx) { return ['mdi-medal', 'mdi-medal', 'mdi-medal'][idx] || `mdi-numeric-${idx + 1}-circle` }

async function load() {
  loading.value = true
  try {
    const [rev, gol, lb, emp] = await Promise.all([
      $api.get('/homecare/hr/performance-reviews/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/goals/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/performance/leaderboard/').catch(() => ({ data: [] })),
      $api.get('/homecare/hr/employees/', { params: { page_size: 500, status: 'active' } }).catch(() => ({ data: [] })),
    ])
    reviews.value = rev.data?.results || rev.data || []
    goals.value = gol.data?.results || gol.data || []
    leaderboard.value = lb.data?.results || lb.data || []
    employees.value = (emp.data?.results || emp.data || []).map(e => ({ id: e.id, name: e.name || `${e.first_name || ''} ${e.last_name || ''}`.trim() }))
  } catch (e) {
    console.warn('load performance failed', e)
  } finally { loading.value = false }
}

function openReviewDialog(item = null) {
  if (item) {
    editingReviewId.value = item.id
    Object.assign(reviewForm, blankReview(), { ...item, review_date: item.review_date || '' })
  } else {
    editingReviewId.value = null
    Object.assign(reviewForm, blankReview())
  }
  reviewDialog.value = true
}
async function saveReview() {
  if (!reviewForm.employee) { notify('Select an employee.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...reviewForm }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    if (editingReviewId.value) {
      await $api.patch(`/homecare/hr/performance-reviews/${editingReviewId.value}/`, payload)
      notify('Review updated.')
    } else {
      await $api.post('/homecare/hr/performance-reviews/', payload)
      notify('Review created.')
    }
    reviewDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save.', 'error')
  } finally { saving.value = false }
}

function openGoalDialog() {
  Object.assign(goalForm, blankGoal())
  goalDialog.value = true
}
async function saveGoal() {
  if (!goalForm.employee || !goalForm.title) { notify('Employee and title required.', 'error'); return }
  saving.value = true
  try {
    await $api.post('/homecare/hr/goals/', { ...goalForm })
    notify('Goal created.')
    goalDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  } finally { saving.value = false }
}
function updateGoalProgress(g) {
  progressGoal.value = g
  progressValue.value = g.progress || 0
  progressDialog.value = true
}
async function saveGoalProgress() {
  saving.value = true
  try {
    await $api.patch(`/homecare/hr/goals/${progressGoal.value.id}/`, { progress: progressValue.value })
    notify('Progress updated.')
    progressDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  } finally { saving.value = false }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
