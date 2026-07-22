<template>
  <NuxtLayout name="auth">
    <div class="rp-root">
      <div class="rp-bg rp-fill" />
      <div class="rp-grid rp-fill" />

      <v-container class="rp-container">
        <v-btn variant="text" color="white" class="text-none mb-4"
               prepend-icon="mdi-arrow-left" @click="goBack">
          {{ step === 'policy' ? 'Back to hub' : 'Back' }}
        </v-btn>

        <!-- STEP 1: Privacy policy -->
        <v-card v-if="step === 'policy'" rounded="xl" elevation="12" class="rp-card mx-auto">
          <div class="rp-card-head">
            <div class="d-flex align-center">
              <div class="rp-badge d-flex align-center justify-center mr-3">
                <v-icon color="white">mdi-shield-lock</v-icon>
              </div>
              <div>
                <h2 class="text-h6 font-weight-bold mb-0">Privacy Policy</h2>
                <div class="text-caption text-medium-emphasis">
                  Please read and accept before you register
                </div>
              </div>
            </div>
          </div>

          <div ref="policyScroll" class="rp-policy" @scroll="onPolicyScroll">
            <div v-for="sec in policy" :key="sec.n" class="rp-sec">
              <h3 class="rp-sec-title">{{ sec.n }}. {{ sec.title }}</h3>
              <template v-for="(blk, bi) in sec.blocks" :key="bi">
                <p v-if="blk.type === 'p'" class="rp-p" v-html="blk.text" />
                <ul v-else-if="blk.type === 'ul'" class="rp-ul">
                  <li v-for="(li, li2) in blk.items" :key="li2" v-html="li" />
                </ul>
                <div v-else-if="blk.type === 'h'" class="rp-subh">{{ blk.text }}</div>
              </template>
            </div>
            <div class="rp-policy-end">— End of Privacy Policy —</div>
          </div>

          <div class="rp-policy-foot">
            <v-fade-transition>
              <div v-if="!scrolledToEnd" class="rp-scrollhint">
                <v-icon size="16" class="mr-1">mdi-arrow-down</v-icon>
                Scroll to read the full policy
              </div>
            </v-fade-transition>

            <v-checkbox v-model="accepted" color="teal" hide-details density="comfortable"
                        class="rp-check" @update:model-value="onAccept">
              <template #label>
                <span class="rp-check-label">
                  I have read and <strong>accept</strong> the AdhereMED Privacy Policy.
                </span>
              </template>
            </v-checkbox>
            <v-checkbox v-model="declined" color="grey" hide-details density="comfortable"
                        class="rp-check" @update:model-value="onDecline">
              <template #label>
                <span class="rp-check-label text-medium-emphasis">
                  I do <strong>not</strong> accept — return to welcome screen.
                </span>
              </template>
            </v-checkbox>

            <div class="d-flex mt-2">
              <v-btn variant="text" class="text-none" rounded="lg" @click="goWelcome">
                Cancel
              </v-btn>
              <v-spacer />
              <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                     :disabled="!accepted" append-icon="mdi-arrow-right" @click="proceed">
                Continue
              </v-btn>
            </div>
          </div>
        </v-card>

        <!-- STEP 2: Registration form -->
        <v-card v-else-if="step === 'form'" rounded="xl" elevation="12" class="rp-card rp-form-card mx-auto pa-6 pa-md-8">
          <div class="text-center mb-6">
            <div class="rp-badge d-flex align-center justify-center mx-auto mb-3">
              <v-icon color="white">mdi-account-heart</v-icon>
            </div>
            <h2 class="text-h5 font-weight-bold">Create patient account</h2>
            <p class="text-body-2 text-medium-emphasis mb-0">
              Register to access the AdhereMed patient portal
            </p>
            <div class="rp-idnote mt-3">
              <v-icon size="15" class="mr-1">mdi-identifier</v-icon>
              A unique Patient ID (e.g. <strong>AD01</strong>) will be generated automatically.
            </div>
          </div>

          <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" class="mb-4">
            {{ errorMsg }}
          </v-alert>

          <v-form ref="formRef" @submit.prevent="onSubmit">
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.firstName" label="First name *" :rules="req"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.lastName" label="Last name *" :rules="req"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.email" label="Email *" type="email"
                              prepend-inner-icon="mdi-email-outline"
                              :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.phone" label="Phone"
                              prepend-inner-icon="mdi-phone-outline"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.nationalId" label="National ID *" :rules="req"
                              prepend-inner-icon="mdi-card-account-details-outline"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.dateOfBirth" label="Date of birth *" type="date"
                              :rules="req" prepend-inner-icon="mdi-cake-variant"
                              variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-select v-model="form.gender" :items="genderOptions" label="Gender *"
                          :rules="req" prepend-inner-icon="mdi-gender-male-female"
                          variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.password" label="Password *"
                              :type="show ? 'text' : 'password'"
                              prepend-inner-icon="mdi-lock-outline"
                              :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                              :rules="[v => !!v || 'Password required', v => (v && v.length >= 8) || 'Min 8 characters']"
                              variant="outlined" density="comfortable" rounded="lg"
                              @click:append-inner="show = !show" />
              </v-col>
            </v-row>

            <v-btn type="submit" color="teal" size="large" block rounded="lg"
                   class="text-none mt-2" :loading="loading">
              Create Account
            </v-btn>

            <div class="text-center mt-5 text-body-2">
              Already have an account?
              <NuxtLink to="/login" class="text-teal font-weight-medium">Sign in</NuxtLink>
            </div>
          </v-form>
        </v-card>

        <!-- STEP 3: Success -->
        <v-card v-else rounded="xl" elevation="12" class="rp-card rp-form-card mx-auto pa-8 text-center">
          <v-avatar size="72" color="teal" variant="tonal" class="mb-4">
            <v-icon size="40" color="teal">mdi-check-decagram</v-icon>
          </v-avatar>
          <h2 class="text-h5 font-weight-bold mb-1">Welcome to AdhereMed!</h2>
          <p class="text-body-2 text-medium-emphasis">Your patient account is ready.</p>
          <div class="rp-idcard my-5">
            <div class="text-caption text-medium-emphasis">Your Patient ID</div>
            <div class="rp-idvalue">{{ newPatientId || '—' }}</div>
          </div>
          <v-btn color="teal" size="large" block rounded="lg" class="text-none"
                 append-icon="mdi-arrow-right" @click="router.push('/dashboard')">
            Go to my dashboard
          </v-btn>
        </v-card>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { privacyPolicy } from '~/utils/privacyPolicy'

definePageMeta({ layout: false })

const auth = useAuthStore()
const router = useRouter()
const { $api } = useNuxtApp()

const step = ref('policy') // policy | form | done
const policy = privacyPolicy

// Policy acceptance
const accepted = ref(false)
const declined = ref(false)
const scrolledToEnd = ref(false)
const policyScroll = ref(null)

function onPolicyScroll(e) {
  const el = e.target
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) scrolledToEnd.value = true
}
function onAccept(v) { if (v) declined.value = false }
function onDecline(v) {
  if (v) { accepted.value = false; goWelcome() }
}
function proceed() {
  if (!accepted.value) return
  step.value = 'form'
}
function goWelcome() { router.push('/welcome') }
function goBack() {
  if (step.value === 'form') step.value = 'policy'
  else router.push('/get-started')
}

// Registration form
const formRef = ref(null)
const show = ref(false)
const loading = ref(false)
const errorMsg = ref('')
const newPatientId = ref('')
const genderOptions = [
  { title: 'Male', value: 'male' },
  { title: 'Female', value: 'female' },
  { title: 'Other', value: 'other' }
]
const form = reactive({
  firstName: '', lastName: '', email: '', phone: '',
  nationalId: '', dateOfBirth: '', gender: '', password: ''
})
const req = [v => !!v || 'Required']

async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  loading.value = true
  try {
    const ok = await auth.register({
      email: form.email.trim(),
      password: form.password,
      firstName: form.firstName.trim(),
      lastName: form.lastName.trim(),
      phone: form.phone.trim(),
      nationalId: form.nationalId.trim()
    })
    if (!ok) { errorMsg.value = auth.error || 'Registration failed.'; return }

    // Save extra profile details and retrieve the generated Patient ID.
    try {
      const { data } = await $api.patch('/patients/me/', {
        date_of_birth: form.dateOfBirth,
        gender: form.gender,
        national_id: form.nationalId.trim()
      })
      newPatientId.value = data?.patient_id || ''
    } catch {
      try {
        const { data } = await $api.get('/patients/me/')
        newPatientId.value = data?.patient_id || ''
      } catch { /* ignore */ }
    }
    step.value = 'done'
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Registration failed.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.rp-root { position: relative; min-height: 100vh; overflow: hidden; background: #060B18; }
.rp-fill { position: absolute; inset: 0; z-index: 0; }
.rp-bg {
  background:
    radial-gradient(1000px 600px at 85% -10%, rgba(13,148,136,0.22), transparent 60%),
    radial-gradient(900px 500px at 0% 110%, rgba(37,99,235,0.16), transparent 60%),
    #060B18;
}
.rp-grid {
  background-image:
    linear-gradient(rgba(148,163,184,0.06) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148,163,184,0.06) 1px, transparent 1px);
  background-size: 44px 44px;
  mask-image: radial-gradient(900px 700px at 50% 10%, #000 40%, transparent 80%);
}
.rp-container { position: relative; z-index: 2; max-width: 720px; padding-top: 28px; padding-bottom: 40px; }
.rp-card { width: 100%; max-width: 680px; overflow: hidden; }
.rp-form-card { max-width: 620px; }
.rp-card-head { padding: 20px 24px; border-bottom: 1px solid rgba(15,23,42,0.08); }
.rp-badge {
  width: 44px; height: 44px; border-radius: 12px;
  background: linear-gradient(135deg, #0d9488, #2563EB);
  box-shadow: 0 8px 22px rgba(13,148,136,0.4);
}
.rp-policy { max-height: 46vh; overflow-y: auto; padding: 18px 24px; background: #f8fafc; }
.rp-sec { margin-bottom: 16px; }
.rp-sec-title { font-size: 14px; font-weight: 800; color: #0f172a; margin-bottom: 6px; }
.rp-subh { font-size: 12.5px; font-weight: 700; color: #334155; margin: 8px 0 4px; }
.rp-p { font-size: 12.5px; color: #475569; line-height: 1.6; margin-bottom: 8px; }
.rp-ul { margin: 0 0 8px 0; padding-left: 18px; }
.rp-ul li { font-size: 12.5px; color: #475569; line-height: 1.55; margin-bottom: 3px; }
.rp-policy-end { text-align: center; color: #94a3b8; font-size: 12px; padding: 10px 0 4px; }
.rp-policy-foot { padding: 14px 24px 20px; border-top: 1px solid rgba(15,23,42,0.08); }
.rp-scrollhint { font-size: 12px; color: #0d9488; margin-bottom: 6px; display: flex; align-items: center; }
.rp-check :deep(.v-selection-control) { min-height: 34px; }
.rp-check-label { font-size: 13px; }
.rp-idnote {
  display: inline-flex; align-items: center;
  font-size: 12.5px; color: #0d9488;
  background: rgba(13,148,136,0.1); border: 1px solid rgba(13,148,136,0.2);
  padding: 6px 12px; border-radius: 999px;
}
.rp-idcard {
  border: 1px dashed rgba(13,148,136,0.4);
  background: rgba(13,148,136,0.06);
  border-radius: 14px; padding: 14px;
}
.rp-idvalue { font-size: 30px; font-weight: 800; letter-spacing: 2px; color: #0d9488; }
</style>
