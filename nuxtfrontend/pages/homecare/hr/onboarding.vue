<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Onboarding & Training"
      subtitle="Guide new hires through structured onboarding checklists, training programs, and competency assessments."
      eyebrow="HR · ONBOARDING"
      icon="mdi-school-outline"
      :chips="[
        { icon: 'mdi-account-clock', label: `${inProgress.length} in onboarding` },
        { icon: 'mdi-check-circle', label: `${completed.length} completed` },
        { icon: 'mdi-book-open-variant', label: `${programs.length} training programs` },
        { icon: 'mdi-certificate', label: `${certCount} certifications` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="openTemplateDialog">
          <span class="text-teal-darken-2 font-weight-bold">Onboarding template</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="In Onboarding" :value="inProgress.length" icon="mdi-account-clock" color="#0ea5e9" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Completed" :value="completed.length" icon="mdi-check-circle" color="#10b981" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Avg Days" :value="avgDays" suffix="days" icon="mdi-calendar-clock" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Overdue Tasks" :value="overdueTasks" icon="mdi-alert-circle" color="#ef4444" /></v-col>
    </v-row>

    <v-tabs v-model="tab" color="teal" density="compact" class="mb-3">
      <v-tab value="onboarding"><v-icon start icon="mdi-account-plus" />Onboarding</v-tab>
      <v-tab value="training"><v-icon start icon="mdi-book-open-variant" />Training Programs</v-tab>
    </v-tabs>

    <!-- ONBOARDING TAB -->
    <template v-if="tab === 'onboarding'">
      <v-row dense>
        <v-col v-for="emp in onboardingItems" :key="emp.id" cols="12" md="6">
          <v-card rounded="xl" elevation="0" class="hc-onboard-card pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar size="44" :color="avatarColor(emp.name)" variant="tonal" class="mr-3">
                <span class="font-weight-bold">{{ initials(emp.name) }}</span>
              </v-avatar>
              <div class="flex-grow-1">
                <div class="font-weight-bold text-subtitle-1">{{ emp.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ emp.role }} · {{ emp.department }}</div>
              </div>
              <v-chip size="small" variant="tonal" :color="emp.status === 'completed' ? 'success' : 'info'">
                {{ emp.status === 'completed' ? 'Completed' : `${emp.progress}%` }}
              </v-chip>
            </div>
            <v-progress-linear :model-value="emp.progress" color="teal" height="6" rounded class="mb-3" />
            <div class="text-overline text-medium-emphasis mb-1">Checklist ({{ completedTasks(emp) }}/{{ emp.tasks?.length || 0 }})</div>
            <v-list density="compact" class="bg-transparent pa-0">
              <v-list-item v-for="task in (emp.tasks || []).slice(0, 5)" :key="task.id" class="px-0">
                <template #prepend>
                  <v-checkbox-btn v-model="task.done" color="teal" hide-details density="compact"
                                   @update:model-value="toggleTask(emp, task)" />
                </template>
                <v-list-item-title :class="{ 'text-decoration-line-through text-medium-emphasis': task.done }"
                                   class="text-body-2">{{ task.title }}</v-list-item-title>
                <template #append>
                  <v-chip v-if="task.due_date" size="x-small" variant="tonal" :color="taskDueColor(task)">
                    {{ formatDate(task.due_date) }}
                  </v-chip>
                </template>
              </v-list-item>
            </v-list>
            <div v-if="(emp.tasks?.length || 0) > 5" class="text-caption text-teal-darken-2 mt-1">
              +{{ emp.tasks.length - 5 }} more tasks
            </div>
            <div class="d-flex justify-end mt-2">
              <v-btn variant="text" size="small" prepend-icon="mdi-eye" @click="viewOnboarding(emp)">Details</v-btn>
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!onboardingItems.length && !loading" cols="12">
          <EmptyState icon="mdi-account-off" title="No active onboarding" subtitle="New hires will appear here." />
        </v-col>
      </v-row>
    </template>

    <!-- TRAINING TAB -->
    <template v-if="tab === 'training'">
      <HomecarePanel title="Training Programs" subtitle="Enroll employees in training & certification courses" icon="mdi-book-open-variant" color="#7c3aed">
        <template #actions>
          <v-btn variant="tonal" color="teal" size="small" prepend-icon="mdi-plus" @click="openProgramDialog">Add program</v-btn>
        </template>
        <v-row dense>
          <v-col v-for="p in programs" :key="p.id" cols="12" md="6" lg="4">
            <v-card rounded="lg" variant="outlined" class="pa-4 h-100">
              <div class="d-flex align-center mb-2">
                <v-avatar size="40" :color="programColor(p)" variant="tonal" class="mr-3">
                  <v-icon :icon="programIcon(p)" size="20" />
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="font-weight-bold">{{ p.title }}</div>
                  <div class="text-caption text-medium-emphasis">{{ p.category }}</div>
                </div>
              </div>
              <p class="text-body-2 text-medium-emphasis mb-3">{{ p.description || 'No description.' }}</p>
              <div class="d-flex flex-wrap ga-2 mb-3">
                <v-chip size="small" variant="tonal" prepend-icon="mdi-clock-outline">{{ p.duration_hours || 0 }}h</v-chip>
                <v-chip size="small" variant="tonal" prepend-icon="mdi-account-group">{{ p.enrolled_count || 0 }} enrolled</v-chip>
                <v-chip size="small" variant="tonal" prepend-icon="mdi-certificate" :color="p.mandatory ? 'error' : 'grey'">
                  {{ p.mandatory ? 'Mandatory' : 'Optional' }}
                </v-chip>
              </div>
              <v-progress-linear v-if="p.completion_pct != null" :model-value="p.completion_pct" color="purple" height="4" rounded class="mb-2" />
              <div class="d-flex justify-end">
                <v-btn variant="text" size="small" prepend-icon="mdi-account-plus-outline" @click="openEnrollDialog(p)">Enroll</v-btn>
                <v-btn variant="text" size="small" prepend-icon="mdi-eye" @click="viewProgram(p)">View</v-btn>
              </div>
            </v-card>
          </v-col>
        </v-row>
        <EmptyState v-if="!programs.length" icon="mdi-book-off" title="No training programs yet" />
      </HomecarePanel>
    </template>

    <!-- Onboarding detail dialog -->
    <v-dialog v-model="detailDialog" max-width="700" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-account-plus" class="mr-2" />Onboarding — {{ detailItem?.name }}
        </v-card-title>
        <v-divider />
        <v-card-text v-if="detailItem" style="max-height:70vh">
          <v-row dense class="mb-3">
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Role</div><div class="font-weight-medium">{{ detailItem.role }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Department</div><div class="font-weight-medium">{{ detailItem.department }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Start date</div><div class="font-weight-medium">{{ formatDate(detailItem.start_date) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Mentor</div><div class="font-weight-medium">{{ detailItem.mentor || '—' }}</div></v-col>
          </v-row>
          <div class="text-overline text-medium-emphasis mb-1">Full checklist</div>
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="task in (detailItem.tasks || [])" :key="task.id" class="px-0">
              <template #prepend>
                <v-checkbox-btn v-model="task.done" color="teal" hide-details density="compact"
                                 @update:model-value="toggleTask(detailItem, task)" />
              </template>
              <v-list-item-title :class="{ 'text-decoration-line-through text-medium-emphasis': task.done }">{{ task.title }}</v-list-item-title>
              <v-list-item-subtitle v-if="task.notes">{{ task.notes }}</v-list-item-subtitle>
              <template #append>
                <v-chip v-if="task.due_date" size="x-small" variant="tonal" :color="taskDueColor(task)">{{ formatDate(task.due_date) }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Template dialog -->
    <v-dialog v-model="templateDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-format-list-checks" class="mr-2" />Onboarding Template</v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <v-text-field v-model="templateForm.name" label="Template name" density="comfortable" variant="outlined" class="mb-3" />
          <div class="text-overline text-medium-emphasis mb-1">Tasks (one per line)</div>
          <v-textarea v-model="templateForm.tasks" rows="8" density="comfortable" variant="outlined"
                      hint="Each line becomes a checklist task" persistent-hint />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="templateDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveTemplate">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Program dialog -->
    <v-dialog v-model="programDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-book-plus" class="mr-2" />Training Program</v-card-title>
        <v-divider />
        <v-card-text style="max-height:70vh">
          <v-text-field v-model="programForm.title" label="Title *" density="comfortable" variant="outlined" />
          <v-select v-model="programForm.category" :items="trainingCategories" label="Category"
                    density="comfortable" variant="outlined" />
          <v-textarea v-model="programForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model.number="programForm.duration_hours" label="Duration (hours)" type="number" density="comfortable" variant="outlined" /></v-col>
            <v-col cols="6">
              <v-select v-model="programForm.delivery_mode" :items="deliveryModes" item-title="label" item-value="value"
                        label="Delivery mode" density="comfortable" variant="outlined" />
            </v-col>
          </v-row>
          <v-switch v-model="programForm.mandatory" color="teal" label="Mandatory for all staff" density="compact" hide-details />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="programDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveProgram">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Enroll dialog -->
    <v-dialog v-model="enrollDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-account-plus-outline" class="mr-2" />Enroll Employees</v-card-title>
        <v-divider />
        <v-card-text>
          <div class="text-body-2 text-medium-emphasis mb-3">{{ enrollProgram?.title }}</div>
          <v-autocomplete v-model="enrollSelection" :items="employees" item-title="name" item-value="id"
                          label="Select employees" multiple chips closable-chips
                          density="comfortable" variant="outlined" />
          <v-text-field v-model="enrollDeadline" label="Completion deadline" type="date"
                        density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="enrollDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="confirmEnroll">Enroll</v-btn>
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

const tab = ref('onboarding')
const onboardingItems = ref([])
const programs = ref([])
const employees = ref([])
const loading = ref(false)
const saving = ref(false)
const detailDialog = ref(false)
const templateDialog = ref(false)
const programDialog = ref(false)
const enrollDialog = ref(false)
const detailItem = ref(null)
const enrollProgram = ref(null)
const enrollSelection = ref([])
const enrollDeadline = ref('')

const templateForm = reactive({ name: '', tasks: '' })
const blankProgram = () => ({ title: '', category: '', description: '', duration_hours: null, delivery_mode: 'online', mandatory: false })
const programForm = reactive(blankProgram())

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const trainingCategories = ['Clinical Skills', 'Compliance & Safety', 'Soft Skills', 'Technology', 'Leadership', 'First Aid', 'Patient Care', 'Infection Control']
const deliveryModes = [
  { value: 'online', label: 'Online' },
  { value: 'in_person', label: 'In-person' },
  { value: 'hybrid', label: 'Hybrid' },
  { value: 'self_paced', label: 'Self-paced' },
]

const inProgress = computed(() => onboardingItems.value.filter(e => e.status !== 'completed'))
const completed = computed(() => onboardingItems.value.filter(e => e.status === 'completed'))
const avgDays = computed(() => {
  if (!completed.value.length) return 0
  const days = completed.value.map(e => e.days_to_complete || 0).filter(Boolean)
  return days.length ? Math.round(days.reduce((a, b) => a + b, 0) / days.length) : 0
})
const overdueTasks = computed(() => {
  let count = 0
  onboardingItems.value.forEach(e => {
    (e.tasks || []).forEach(t => {
      if (!t.done && t.due_date && new Date(t.due_date) < new Date()) count++
    })
  })
  return count
})
const certCount = computed(() => programs.value.reduce((sum, p) => sum + (p.certified_count || 0), 0))

function completedTasks(emp) { return (emp.tasks || []).filter(t => t.done).length }
function initials(name) { return (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase() }
function avatarColor(name) {
  const colors = ['teal', 'blue', 'purple', 'orange', 'pink', 'indigo', 'green', 'cyan']
  let hash = 0
  for (let i = 0; i < (name || '').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return colors[Math.abs(hash) % colors.length]
}
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function taskDueColor(task) {
  if (task.done) return 'success'
  if (!task.due_date) return 'grey'
  return new Date(task.due_date) < new Date() ? 'error' : 'warning'
}
function programColor(p) {
  const map = { 'Clinical Skills': 'pink', 'Compliance & Safety': 'error', 'Soft Skills': 'teal', 'Technology': 'blue', 'Leadership': 'purple', 'First Aid': 'red', 'Patient Care': 'green', 'Infection Control': 'amber' }
  return map[p?.category] || 'teal'
}
function programIcon(p) {
  const map = { 'Clinical Skills': 'mdi-stethoscope', 'Compliance & Safety': 'mdi-shield-check', 'Soft Skills': 'mdi-account-voice', 'Technology': 'mdi-laptop', 'Leadership': 'mdi-account-tie', 'First Aid': 'mdi-medical-bag', 'Patient Care': 'mdi-hand-heart', 'Infection Control': 'mdi-virus' }
  return map[p?.category] || 'mdi-book'
}

async function load() {
  loading.value = true
  try {
    const [ob, prog, emp] = await Promise.all([
      $api.get('/homecare/hr/onboarding/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/training-programs/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/employees/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
    ])
    onboardingItems.value = ob.data?.results || ob.data || []
    programs.value = prog.data?.results || prog.data || []
    employees.value = (emp.data?.results || emp.data || []).map(e => ({ id: e.id, name: e.name }))
  } catch (e) {
    console.warn('load onboarding failed', e)
  } finally { loading.value = false }
}

function viewOnboarding(emp) {
  detailItem.value = emp
  detailDialog.value = true
}

async function toggleTask(emp, task) {
  try {
    await $api.patch(`/homecare/hr/onboarding/${emp.id}/tasks/${task.id}/`, { done: task.done })
    emp.progress = Math.round(((emp.tasks || []).filter(t => t.done).length / Math.max(emp.tasks?.length || 1, 1)) * 100)
    if (emp.progress === 100) {
      emp.status = 'completed'
      notify(`${emp.name} onboarding complete!`)
    }
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update task.', 'error')
    task.done = !task.done
  }
}

function openTemplateDialog() {
  templateForm.name = ''
  templateForm.tasks = 'Sign employment contract\nComplete tax forms (PIN, NSSF, NHIF)\nIssue ID badge & uniform\nIT account setup\nHealth & safety briefing\nPatient privacy (HIPAA) training\nShadow senior caregiver (3 shifts)\nFirst aid certification check'
  templateDialog.value = true
}
async function saveTemplate() {
  if (!templateForm.name || !templateForm.tasks) { notify('Name and tasks required.', 'error'); return }
  saving.value = true
  try {
    const tasks = templateForm.tasks.split('\n').filter(Boolean).map(title => ({ title }))
    await $api.post('/homecare/hr/onboarding-templates/', { name: templateForm.name, tasks })
    notify('Template saved.')
    templateDialog.value = false
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save template.', 'error')
  } finally { saving.value = false }
}

function openProgramDialog() {
  Object.assign(programForm, blankProgram())
  programDialog.value = true
}
async function saveProgram() {
  if (!programForm.title) { notify('Title required.', 'error'); return }
  saving.value = true
  try {
    const payload = { ...programForm }
    Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
    await $api.post('/homecare/hr/training-programs/', payload)
    notify('Program created.')
    programDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save.', 'error')
  } finally { saving.value = false }
}

function openEnrollDialog(program) {
  enrollProgram.value = program
  enrollSelection.value = []
  enrollDeadline.value = ''
  enrollDialog.value = true
}
async function confirmEnroll() {
  if (!enrollSelection.value.length) { notify('Select at least one employee.', 'error'); return }
  saving.value = true
  try {
    await $api.post(`/homecare/hr/training-programs/${enrollProgram.value.id}/enroll/`, {
      employees: enrollSelection.value,
      deadline: enrollDeadline.value || null,
    })
    notify(`${enrollSelection.value.length} employees enrolled.`)
    enrollDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to enroll.', 'error')
  } finally { saving.value = false }
}

function viewProgram(p) { notify(`${p.title}: ${p.enrolled_count || 0} enrolled`, 'info') }

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-onboard-card { background: white; border: 1px solid rgba(15,23,42,0.06); }
:global(.v-theme--dark .hc-onboard-card) { background: #1e293b; border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }
</style>
