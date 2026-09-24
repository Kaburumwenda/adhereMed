<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="bg-base bg-fill" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row no-gutters class="fill-height" align="center" justify="center">
          <v-col cols="12" sm="10" md="8" lg="6" xl="5">
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
                <h2 class="form-title">Create patient account</h2>
                <p class="form-sub">
                  Register to access the AdhereMed patient portal
                </p>
              </div>

              <v-alert
                v-if="errorMsg"
                type="error"
                variant="tonal"
                density="compact"
                class="mb-4"
              >{{ errorMsg }}</v-alert>

              <v-form ref="formRef" @submit.prevent="onSubmit">
                <v-row dense>
                  <v-col cols="12" sm="6">
                    <v-text-field v-model="firstName" label="First name" :rules="req" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-text-field v-model="lastName" label="Last name" :rules="req" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="email"
                  label="Email"
                  type="email"
                  prepend-inner-icon="mdi-email-outline"
                  :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                />
                <v-text-field
                  v-model="phone"
                  label="Phone"
                  prepend-inner-icon="mdi-phone-outline"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                />
                <v-text-field
                  v-model="nationalId"
                  label="National ID"
                  prepend-inner-icon="mdi-card-account-details-outline"
                  :rules="req"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                />
                <v-text-field
                  v-model="password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  prepend-inner-icon="mdi-lock-outline"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Password required', v => v.length >= 6 || 'Min 6 characters']"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                  @click:append-inner="show = !show"
                />

                <v-btn
                  type="submit"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none btn-primary mt-2"
                  :loading="auth.loading"
                >Create Account</v-btn>

                <div class="text-center mt-6 text-body-2 form-footer-text">
                  Already have an account?
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
import { useAuthStore } from '~/stores/auth'

definePageMeta({ layout: false })

const auth = useAuthStore()
const router = useRouter()

const formRef = ref(null)
const firstName = ref('')
const lastName = ref('')
const email = ref('')
const phone = ref('')
const nationalId = ref('')
const password = ref('')
const show = ref(false)
const errorMsg = ref('')

const req = [v => !!v || 'Required']

async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  const ok = await auth.register({
    email: email.value.trim(),
    password: password.value,
    firstName: firstName.value.trim(),
    lastName: lastName.value.trim(),
    phone: phone.value.trim(),
    nationalId: nationalId.value.trim()
  })
  if (ok) router.push('/dashboard')
  else errorMsg.value = auth.error || 'Registration failed.'
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
.btn-primary {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(47, 109, 255, 0.35);
}
</style>
