<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="bg-base bg-fill" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row justify="center" align="center" class="fill-height">
          <v-col cols="12" sm="11" md="9" lg="7" xl="6">
            <v-btn
              variant="text"
              class="text-none mb-4 back-btn"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back</v-btn>

            <v-card rounded="xl" elevation="12" class="form-card pa-6 pa-md-8">
              <div class="text-center mb-6">
                <div class="brand-badge mx-auto mb-4 d-flex align-center justify-center">
                  <v-icon size="24" color="white">mdi-heart-pulse</v-icon>
                </div>
                <h2 class="form-title">Register your facility</h2>
                <p class="form-sub">
                  Set up a hospital, pharmacy or lab tenant on AdhereMed
                </p>
              </div>

              <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" class="mb-4">
                {{ errorMsg }}
              </v-alert>
              <v-alert v-if="success" type="success" variant="tonal" class="mb-4">
                Tenant created. Redirecting to sign in…
              </v-alert>

              <v-form v-if="!success" ref="formRef" @submit.prevent="onSubmit">
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.tenantName" label="Facility name" :rules="req" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-select
                      v-model="form.tenantType"
                      :items="tenantTypes"
                      item-title="label"
                      item-value="value"
                      label="Facility type"
                      :rules="req"
                      variant="outlined"
                      rounded="lg"
                      color="brand"
                    />
                  </v-col>
                </v-row>

                <v-divider class="my-4 divider-light" />
                <p class="text-overline text-medium-emphasis mb-2">Admin user</p>
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.firstName" label="First name" :rules="req" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.lastName" label="Last name" :rules="req" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="form.email"
                  label="Email"
                  type="email"
                  :rules="[v => !!v || 'Required', v => /.+@.+\..+/.test(v) || 'Invalid']"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                />
                <v-text-field v-model="form.phone" label="Phone" variant="outlined" rounded="lg" color="brand" />
                <v-text-field
                  v-model="form.password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Required', v => v.length >= 6 || 'Min 6 chars']"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                  @click:append-inner="show = !show"
                />

                <v-divider class="my-4 divider-light" />
                <p class="text-overline text-medium-emphasis mb-2">Referral (optional)</p>
                <v-text-field
                  v-model="form.referralCode"
                  label="Referral Code"
                  placeholder="Enter a referral code if you have one"
                  persistent-placeholder
                  :loading="validatingCode"
                  :messages="referralMsg"
                  :color="referralValid ? 'success' : undefined"
                  :error-messages="referralError"
                  prepend-inner-icon="mdi-gift"
                  variant="outlined"
                  rounded="lg"
                  @update:model-value="debouncedValidateCode"
                />

                <v-btn
                  type="submit"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none btn-primary mt-2"
                  :loading="loading"
                >Create Tenant</v-btn>

                <div class="text-center mt-6 text-body-2 form-footer-text">
                  Already registered?
                  <NuxtLink to="/login" class="form-link font-weight-medium">Sign in</NuxtLink>
                </div>
              </v-form>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
definePageMeta({ layout: false })

const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()

const formRef = ref(null)
const loading = ref(false)
const errorMsg = ref('')
const success = ref(false)
const show = ref(false)
const req = [v => !!v || 'Required']

const tenantTypes = [
  { label: 'Hospital', value: 'hospital' },
  { label: 'Pharmacy', value: 'pharmacy' },
  { label: 'Laboratory', value: 'lab' },
  { label: 'Homecare', value: 'homecare' },
  { label: 'Inventory / Warehouse', value: 'inventory' }
]

const form = reactive({
  tenantName: '',
  tenantType: 'hospital',
  firstName: '',
  lastName: '',
  email: '',
  phone: '',
  password: '',
  referralCode: ''
})

const validatingCode = ref(false)
const referralValid = ref(false)
const referralMsg = ref('')
const referralError = ref('')
let validateTimer = null

function debouncedValidateCode() {
  referralValid.value = false
  referralMsg.value = ''
  referralError.value = ''
  clearTimeout(validateTimer)
  const code = (form.referralCode || '').trim()
  if (!code) return
  if (code.length < 4) return
  validateTimer = setTimeout(() => validateReferralCode(code), 500)
}

async function validateReferralCode(code) {
  validatingCode.value = true
  try {
    const { data } = await $api.get(`/usage-billing/referral/validate/${code.toUpperCase()}/`)
    if (data.valid) {
      referralValid.value = true
      referralMsg.value = `Referred by: ${data.referrer_name}`
    } else {
      referralError.value = 'Invalid referral code'
    }
  } catch {
    referralError.value = 'Could not validate code'
  } finally {
    validatingCode.value = false
  }
}

// Pre-fill referral code from URL query param (?ref=CODE)
onMounted(() => {
  const refCode = route.query.ref
  if (refCode) {
    form.referralCode = String(refCode).toUpperCase()
    validateReferralCode(form.referralCode)
  }
})

async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  loading.value = true
  try {
    await $api.post('/tenants/register/', {
      name: form.tenantName,
      tenant_type: form.tenantType,
      referral_code: (form.referralCode || '').trim().toUpperCase(),
      admin: {
        email: form.email,
        password: form.password,
        first_name: form.firstName,
        last_name: form.lastName,
        phone: form.phone
      }
    }, {
      // Tenant creation provisions a new Postgres schema and runs all
      // migrations synchronously — can take 30–90s on a cold DB.
      timeout: 180000
    })
    success.value = true
    setTimeout(() => router.push('/login'), 1500)
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || e?.response?.data?.message || 'Registration failed.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-root { position: relative; min-height: 100vh; overflow: hidden; color: #0a0f1f; }
.bg-fill { position: absolute; inset: 0; z-index: 0; }
.bg-base {
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.back-btn { color: rgba(15, 23, 42, 0.6) !important; }
.form-card {
  border: 1px solid rgba(47, 109, 255, 0.12);
  box-shadow: 0 12px 40px rgba(10, 15, 31, 0.08);
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(12px);
}
.brand-badge {
  width: 52px; height: 52px; border-radius: 16px;
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%);
  box-shadow: 0 6px 18px rgba(47, 109, 255, 0.35);
}
.form-title { color: #0a0f1f; font-weight: 800; }
.form-sub { color: #64748b; }
.form-footer-text { color: #64748b; }
.form-link { color: #2f6dff !important; }
.divider-light { border-color: rgba(15, 23, 42, 0.08) !important; }
.btn-primary {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(47, 109, 255, 0.35);
}
</style>
