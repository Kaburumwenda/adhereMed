<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="cg ? `Edit ${cg.user?.full_name || 'caregiver'}` : 'Edit caregiver'"
      :subtitle="cg?.user?.email || 'Update profile, category, specialties and employment.'"
      eyebrow="HOMECARE · TEAM"
      icon="mdi-account-edit"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-arrow-left" class="text-none"
               :to="cg ? `/homecare/caregivers/${cg.id}` : '/homecare/caregivers'">
          <span class="text-teal-darken-2 font-weight-bold">Back</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mt-4" justify="center">
      <v-col cols="12" md="10" lg="8">
        <v-skeleton-loader v-if="!cg && loading" type="article, article, article" />

        <template v-else-if="cg">
          <!-- Category -->
          <v-card rounded="xl" elevation="0" class="hc-card pa-4 mb-3">
            <div class="d-flex align-center ga-2 mb-3">
              <v-icon icon="mdi-account-heart" color="teal" />
              <div class="text-subtitle-1 font-weight-bold">Caregiver category</div>
            </div>
            <v-row dense>
              <v-col v-for="opt in categoryOptions" :key="opt.value" cols="12" sm="6">
                <v-card rounded="xl" elevation="0" class="hc-cat-pick pa-4 cursor-pointer h-100"
                        :class="{ 'hc-cat-pick--active': form.category === opt.value }"
                        :style="form.category === opt.value
                          ? { borderColor: opt.solid, boxShadow: `0 0 0 2px ${opt.solid}33` }
                          : {}"
                        @click="form.category = opt.value">
                  <div class="d-flex align-center ga-3">
                    <v-avatar size="48" :color="opt.color" variant="flat">
                      <v-icon :icon="opt.icon" size="24" color="white" />
                    </v-avatar>
                    <div class="flex-grow-1">
                      <div class="text-subtitle-1 font-weight-bold">{{ opt.title }}</div>
                      <div class="text-caption text-medium-emphasis">{{ opt.description }}</div>
                    </div>
                    <v-icon v-if="form.category === opt.value" icon="mdi-check-circle"
                            :color="opt.color" />
                  </div>
                </v-card>
              </v-col>
            </v-row>
          </v-card>

          <!-- Profile (read-only user info + editable license) -->
          <v-card rounded="xl" elevation="0" class="hc-card pa-4 mb-3">
            <div class="d-flex align-center ga-2 mb-3">
              <v-icon icon="mdi-account" color="teal" />
              <div class="text-subtitle-1 font-weight-bold">Identity</div>
              <v-spacer />
              <v-chip size="x-small" color="grey" variant="tonal">User account read-only</v-chip>
            </div>
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field :model-value="cg.user?.full_name" label="Full name"
                              prepend-inner-icon="mdi-account" variant="outlined"
                              rounded="lg" density="comfortable" readonly />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field :model-value="cg.user?.email" label="Email"
                              prepend-inner-icon="mdi-email" variant="outlined"
                              rounded="lg" density="comfortable" readonly />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field :model-value="cg.user?.phone" label="Phone"
                              prepend-inner-icon="mdi-phone" variant="outlined"
                              rounded="lg" density="comfortable" readonly />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.license_number"
                              :label="form.category === 'nurse' ? 'Nursing license #' : 'Certification #'"
                              prepend-inner-icon="mdi-card-account-details"
                              variant="outlined" rounded="lg" density="comfortable" />
              </v-col>
            </v-row>
          </v-card>

          <!-- Professional details -->
          <v-card rounded="xl" elevation="0" class="hc-card pa-4 mb-3">
            <div class="d-flex align-center ga-2 mb-3">
              <v-icon icon="mdi-medical-bag" color="teal" />
              <div class="text-subtitle-1 font-weight-bold">Professional details</div>
            </div>
            <v-row dense>
              <v-col cols="12">
                <v-combobox v-model="form.specialties" label="Specialties / skills"
                            :items="suggestedSpecialties" multiple chips closable-chips clearable
                            variant="outlined" rounded="lg" density="comfortable"
                            hint="Press Enter to add custom skills" persistent-hint />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.bio" label="Short bio"
                            variant="outlined" rounded="lg" rows="3" auto-grow density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model.number="form.hourly_rate" label="Hourly rate (KSh)"
                              type="number" min="0" prepend-inner-icon="mdi-cash"
                              variant="outlined" rounded="lg" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.hire_date" label="Hire date" type="date"
                              prepend-inner-icon="mdi-calendar"
                              variant="outlined" rounded="lg" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-select v-model="form.employment_status" label="Employment status"
                          :items="employmentOptions"
                          prepend-inner-icon="mdi-briefcase"
                          variant="outlined" rounded="lg" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6" class="d-flex align-center">
                <v-switch v-model="form.is_independent" label="Independent contractor"
                          color="teal" hide-details inset />
              </v-col>
              <v-col cols="12" md="6" class="d-flex align-center">
                <v-switch v-model="form.is_available" label="Available for visits"
                          color="success" hide-details inset />
              </v-col>
            </v-row>
          </v-card>

          <v-alert v-if="topError" type="error" variant="tonal" density="compact" rounded="lg" class="mb-3">
            {{ topError }}
          </v-alert>

          <div class="d-flex align-center ga-2">
            <v-btn variant="tonal" color="error" rounded="lg" class="text-none"
                   prepend-icon="mdi-delete" @click="confirmDelete = true">
              Delete
            </v-btn>
            <v-btn variant="tonal" color="purple-darken-2" rounded="lg" class="text-none"
                   prepend-icon="mdi-lock-reset" @click="openResetPw">
              Reset password
            </v-btn>
            <v-spacer />
            <v-btn variant="text" rounded="lg" class="text-none"
                   :to="`/homecare/caregivers/${cg.id}`">Cancel</v-btn>
            <v-btn color="teal" rounded="lg" class="text-none" :loading="saving"
                   prepend-icon="mdi-content-save" @click="save">
              Save changes
            </v-btn>
          </div>
        </template>
      </v-col>
    </v-row>

    <!-- Delete confirmation -->
    <v-dialog v-model="confirmDelete" max-width="440">
      <v-card rounded="xl" class="pa-4">
        <div class="d-flex align-center ga-2 mb-2">
          <v-icon icon="mdi-alert-circle" color="error" />
          <div class="text-h6 font-weight-bold">Delete caregiver?</div>
        </div>
        <div class="text-body-2 text-medium-emphasis">
          This will remove <b>{{ cg?.user?.full_name }}</b> from the homecare team.
          Their visit history will be preserved. This cannot be undone.
        </div>
        <div class="d-flex justify-end ga-2 mt-4">
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="confirmDelete = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" class="text-none"
                 :loading="deleting" prepend-icon="mdi-delete" @click="remove">
            Delete
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>

    <!-- Reset password dialog -->
    <v-dialog v-model="resetPw.show" max-width="520" persistent>
      <v-card rounded="xl" class="pa-4">
        <div class="d-flex align-center ga-2 mb-2">
          <v-avatar size="36" color="purple-darken-2" variant="tonal">
            <v-icon icon="mdi-lock-reset" />
          </v-avatar>
          <div>
            <div class="text-h6 font-weight-bold">Reset caregiver password</div>
            <div class="text-caption text-medium-emphasis">
              {{ cg?.user?.full_name }} · {{ cg?.user?.email }}
            </div>
          </div>
        </div>

        <v-alert v-if="resetPw.generated" type="success" variant="tonal" rounded="lg"
                 density="compact" class="my-3">
          <div class="text-body-2 font-weight-bold mb-1">New password generated</div>
          <div class="d-flex align-center ga-2">
            <code class="hc-pw-code flex-grow-1">{{ resetPw.generated }}</code>
            <v-btn icon="mdi-content-copy" size="small" variant="text"
                   @click="copyGenerated" />
          </div>
          <div class="text-caption mt-1">
            Copy and share securely. It will not be shown again.
          </div>
        </v-alert>

        <template v-else>
          <v-btn-toggle v-model="resetPw.mode" mandatory color="purple-darken-2"
                        density="comfortable" variant="outlined" rounded="lg" class="mb-3">
            <v-btn value="manual" class="text-none" prepend-icon="mdi-form-textbox">
              Set manually
            </v-btn>
            <v-btn value="auto" class="text-none" prepend-icon="mdi-auto-fix">
              Auto-generate
            </v-btn>
          </v-btn-toggle>

          <template v-if="resetPw.mode === 'manual'">
            <v-text-field v-model="resetPw.password"
                          :type="resetPw.show1 ? 'text' : 'password'"
                          label="New password"
                          :append-inner-icon="resetPw.show1 ? 'mdi-eye-off' : 'mdi-eye'"
                          @click:append-inner="resetPw.show1 = !resetPw.show1"
                          prepend-inner-icon="mdi-lock"
                          variant="outlined" rounded="lg" density="comfortable"
                          hint="At least 8 characters" persistent-hint />
            <v-text-field v-model="resetPw.confirm"
                          :type="resetPw.show2 ? 'text' : 'password'"
                          label="Confirm password" class="mt-2"
                          :append-inner-icon="resetPw.show2 ? 'mdi-eye-off' : 'mdi-eye'"
                          @click:append-inner="resetPw.show2 = !resetPw.show2"
                          prepend-inner-icon="mdi-lock-check"
                          :error-messages="resetPw.confirm && resetPw.confirm !== resetPw.password
                            ? ['Passwords do not match'] : []"
                          variant="outlined" rounded="lg" density="comfortable" />
          </template>
          <v-alert v-else type="info" variant="tonal" rounded="lg" density="compact">
            A secure 10-character password will be generated and shown once.
          </v-alert>

          <v-alert v-if="resetPw.error" type="error" variant="tonal"
                   rounded="lg" density="compact" class="mt-3">
            {{ resetPw.error }}
          </v-alert>
        </template>

        <div class="d-flex justify-end ga-2 mt-4">
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="resetPw.show = false">
            {{ resetPw.generated ? 'Close' : 'Cancel' }}
          </v-btn>
          <v-btn v-if="!resetPw.generated"
                 color="purple-darken-2" rounded="lg" class="text-none"
                 :loading="resetPw.saving" :disabled="!resetPwValid"
                 prepend-icon="mdi-lock-reset" @click="submitResetPw">
            Reset password
          </v-btn>
        </div>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

const cg = ref(null)
const loading = ref(true)
const saving = ref(false)
const deleting = ref(false)
const confirmDelete = ref(false)
const topError = ref('')
const snack = reactive({ show: false, text: '', color: 'info' })

const form = reactive({
  category: 'nurse',
  license_number: '',
  specialties: [],
  bio: '',
  hourly_rate: 0,
  hire_date: '',
  employment_status: 'active',
  is_available: true,
  is_independent: false,
})

const categoryOptions = [
  { value: 'nurse', title: 'Nurse',
    description: 'Registered nurse — clinical procedures, medication, wound care.',
    icon: 'mdi-medical-bag', color: 'indigo', solid: '#4f46e5' },
  { value: 'hca', title: 'Health Care Assistant',
    description: 'Personal care, mobility, hygiene, companionship & vitals.',
    icon: 'mdi-hand-heart', color: 'pink', solid: '#db2777' },
]

const employmentOptions = [
  { title: 'Active',     value: 'active' },
  { title: 'Suspended',  value: 'suspended' },
  { title: 'Terminated', value: 'terminated' },
  { title: 'On leave',   value: 'on_leave' },
]

const NURSE_SUGGESTIONS = [
  'Wound care', 'IV therapy', 'Injections', 'Catheterisation',
  'Medication administration', 'Post-surgical care', 'Paediatric nursing',
  'Geriatric care', 'Palliative care', 'Diabetes management',
]
const HCA_SUGGESTIONS = [
  'Personal hygiene', 'Bathing & grooming', 'Mobility assistance',
  'Vital signs monitoring', 'Companionship', 'Meal preparation',
  'Dementia care', 'Activities of daily living', 'Transfers',
]
const suggestedSpecialties = computed(() =>
  form.category === 'nurse' ? NURSE_SUGGESTIONS : HCA_SUGGESTIONS
)

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get(`/homecare/caregivers/${route.params.id}/`)
    cg.value = data
    form.category = data.category || 'nurse'
    form.license_number = data.license_number || ''
    form.specialties = Array.isArray(data.specialties) ? [...data.specialties] : []
    form.bio = data.bio || ''
    form.hourly_rate = Number(data.hourly_rate || 0)
    form.hire_date = data.hire_date || ''
    form.employment_status = data.employment_status || 'active'
    form.is_available = !!data.is_available
    form.is_independent = !!data.is_independent
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to load caregiver', color: 'error' })
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  topError.value = ''
  try {
    const { data } = await $api.patch(`/homecare/caregivers/${route.params.id}/`, {
      category: form.category,
      license_number: form.license_number,
      specialties: form.specialties,
      bio: form.bio,
      hourly_rate: form.hourly_rate,
      hire_date: form.hire_date || null,
      employment_status: form.employment_status,
      is_available: form.is_available,
      is_independent: form.is_independent,
    })
    cg.value = data
    Object.assign(snack, { show: true, text: 'Caregiver updated', color: 'success' })
    router.push(`/homecare/caregivers/${data.id}`)
  } catch (e) {
    const d = e?.response?.data
    topError.value = (typeof d === 'string' ? d : d?.detail) ||
      Object.entries(d || {}).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`).join('\n') ||
      'Could not save caregiver.'
  } finally {
    saving.value = false
  }
}

async function remove() {
  deleting.value = true
  try {
    await $api.delete(`/homecare/caregivers/${route.params.id}/`)
    Object.assign(snack, { show: true, text: 'Caregiver deleted', color: 'success' })
    router.push('/homecare/caregivers')
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to delete', color: 'error' })
    deleting.value = false
    confirmDelete.value = false
  }
}

// ── Reset password ─────────────────────────────────────────
const resetPw = reactive({
  show: false, mode: 'manual',
  password: '', confirm: '',
  show1: false, show2: false,
  saving: false, error: '',
  generated: '',
})

const resetPwValid = computed(() => {
  if (resetPw.mode === 'auto') return true
  return resetPw.password.length >= 8 && resetPw.password === resetPw.confirm
})

function openResetPw() {
  Object.assign(resetPw, {
    show: true, mode: 'manual',
    password: '', confirm: '',
    show1: false, show2: false,
    saving: false, error: '', generated: '',
  })
}

async function submitResetPw() {
  resetPw.saving = true
  resetPw.error = ''
  try {
    const body = resetPw.mode === 'auto'
      ? { auto: true }
      : { password: resetPw.password }
    const { data } = await $api.post(
      `/homecare/caregivers/${route.params.id}/reset-password/`, body
    )
    if (data?.password) {
      resetPw.generated = data.password
    } else {
      resetPw.show = false
      Object.assign(snack, { show: true, text: 'Password updated', color: 'success' })
    }
  } catch (e) {
    const d = e?.response?.data
    resetPw.error = (typeof d === 'string' ? d : d?.detail) ||
      (Array.isArray(d?.password) ? d.password.join(', ') : '') ||
      'Could not reset password.'
  } finally {
    resetPw.saving = false
  }
}

async function copyGenerated() {
  try {
    await navigator.clipboard.writeText(resetPw.generated)
    Object.assign(snack, { show: true, text: 'Password copied', color: 'success' })
  } catch {
    Object.assign(snack, { show: true, text: 'Copy failed', color: 'error' })
  }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }
.hc-pw-code {
  display: block;
  background: rgba(124, 58, 237, 0.08);
  color: #5b21b6;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 15px;
  font-weight: 700;
  letter-spacing: 1px;
  padding: 8px 12px;
  border-radius: 8px;
  border: 1px dashed rgba(124, 58, 237, 0.35);
  word-break: break-all;
}
.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.hc-cat-pick {
  background: white;
  border: 2px solid rgba(15,23,42,0.08);
  transition: all 0.18s ease;
}
.hc-cat-pick:hover { border-color: rgba(15,23,42,0.18); }
.hc-cat-pick--active { background: rgba(99,102,241,0.04); }
:global(.v-theme--dark) .hc-cat-pick {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.1);
}
.cursor-pointer { cursor: pointer; }
.h-100 { height: 100%; }
</style>
