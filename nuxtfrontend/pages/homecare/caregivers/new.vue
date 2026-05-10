<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Add caregiver"
      subtitle="Onboard a new nurse or health-care assistant to your homecare team."
      eyebrow="HOMECARE · ENROLMENT"
      icon="mdi-account-plus"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-arrow-left" class="text-none" to="/homecare/caregivers">
          <span class="text-teal-darken-2 font-weight-bold">Back</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mt-4" justify="center">
      <v-col cols="12" md="10" lg="8">
        <!-- Category selector -->
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

        <!-- Personal info -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 mb-3">
          <div class="d-flex align-center ga-2 mb-3">
            <v-icon icon="mdi-account" color="teal" />
            <div class="text-subtitle-1 font-weight-bold">Personal information</div>
          </div>
          <v-form ref="formRef">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.email" label="Email" type="email"
                              prepend-inner-icon="mdi-email" variant="outlined"
                              rounded="lg" density="comfortable" required
                              :rules="[v => !!v || 'Email required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.phone" label="Phone"
                              prepend-inner-icon="mdi-phone" variant="outlined"
                              rounded="lg" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.first_name" label="First name"
                              variant="outlined" rounded="lg" density="comfortable" required
                              :rules="[v => !!v || 'First name required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.last_name" label="Last name"
                              variant="outlined" rounded="lg" density="comfortable" required
                              :rules="[v => !!v || 'Last name required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.password" label="Initial password"
                              prepend-inner-icon="mdi-key" variant="outlined"
                              rounded="lg" density="comfortable"
                              hint="Caregiver can change it on first login" persistent-hint />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.license_number"
                              :label="form.category === 'nurse' ? 'Nursing license #' : 'Certification #'"
                              prepend-inner-icon="mdi-card-account-details"
                              variant="outlined" rounded="lg" density="comfortable" />
              </v-col>
            </v-row>
          </v-form>
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
            <v-col cols="12" md="4" class="d-flex align-center">
              <v-switch v-model="form.is_independent" label="Independent contractor"
                        color="teal" hide-details inset />
            </v-col>
            <v-col cols="12" md="4" class="d-flex align-center">
              <v-switch v-model="form.is_available" label="Available for visits"
                        color="success" hide-details inset />
            </v-col>
          </v-row>
        </v-card>

        <v-alert v-if="topError" type="error" variant="tonal" density="compact" rounded="lg" class="mb-3">
          {{ topError }}
        </v-alert>

        <div class="d-flex justify-end ga-2">
          <v-btn variant="text" rounded="lg" class="text-none" to="/homecare/caregivers">Cancel</v-btn>
          <v-btn color="teal" rounded="lg" class="text-none" :loading="saving"
                 prepend-icon="mdi-content-save" @click="submit">
            Enrol caregiver
          </v-btn>
        </div>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
const router = useRouter()
const { $api } = useNuxtApp()

const formRef = ref(null)
const saving = ref(false)
const topError = ref('')

const form = reactive({
  category: 'nurse',
  email: '', first_name: '', last_name: '', phone: '',
  password: 'caregiver1234',
  license_number: '',
  specialties: [],
  bio: '',
  hourly_rate: 0,
  hire_date: '',
  is_available: true,
  is_independent: false,
})

const categoryOptions = [
  {
    value: 'nurse', title: 'Nurse',
    description: 'Registered nurse — clinical procedures, medication, wound care.',
    icon: 'mdi-medical-bag', color: 'indigo', solid: '#4f46e5',
  },
  {
    value: 'hca', title: 'Health Care Assistant',
    description: 'Personal care, mobility, hygiene, companionship & vitals.',
    icon: 'mdi-hand-heart', color: 'pink', solid: '#db2777',
  },
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

async function submit() {
  if (formRef.value) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  saving.value = true
  topError.value = ''
  try {
    const { data } = await $api.post('/homecare/caregivers/enroll/', {
      category: form.category,
      user_email: form.email,
      first_name: form.first_name,
      last_name: form.last_name,
      phone: form.phone,
      password: form.password,
      license_number: form.license_number,
      specialties: form.specialties,
      bio: form.bio,
      hourly_rate: form.hourly_rate,
      hire_date: form.hire_date || null,
      is_available: form.is_available,
      is_independent: form.is_independent,
    })
    router.push(`/homecare/caregivers/${data.id}`)
  } catch (e) {
    const d = e?.response?.data
    topError.value = (typeof d === 'string' ? d : d?.detail) || 'Could not create caregiver.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }
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
