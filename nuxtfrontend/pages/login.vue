<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="brand-gradient bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row no-gutters class="fill-height" align="center" justify="center">
          <!-- Branding panel (desktop) -->
          <v-col v-if="$vuetify.display.mdAndUp" md="6" class="pa-12">
            <v-btn
              variant="text"
              color="white"
              class="text-none mb-12"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back</v-btn>
            <BrandLogo :size="64" />
            <div class="mt-8 mb-3">
              <span class="text-h3 font-weight-bold text-white">Adhere</span>
              <span class="text-h3 font-weight-light" style="color:#5EEAD4;">Med</span>
            </div>
            <p class="text-h6 font-weight-light mb-12" style="color:rgba(255,255,255,0.75);">
              Connected Healthcare.<br>Simplified.
            </p>
            <div v-for="b in bullets" :key="b" class="d-flex align-center mb-3" style="color:rgba(255,255,255,0.85);">
              <v-icon color="#5EEAD4" class="mr-3">mdi-check-circle</v-icon>
              {{ b }}
            </div>
          </v-col>

          <!-- Form card -->
          <v-col cols="12" md="5" lg="4" class="pa-4 pa-md-8">
            <v-card rounded="xl" elevation="12" class="pa-6 pa-md-8">
              <div class="text-center mb-6">
                <BrandLogo :size="48" class="mx-auto" />
                <h2 class="text-h5 font-weight-bold mt-4">Welcome back</h2>
                <p class="text-body-2 text-medium-emphasis">Sign in to your AdhereMed account</p>
              </div>

              <v-alert
                v-if="errorMsg"
                type="error"
                variant="tonal"
                density="compact"
                class="mb-4"
              >{{ errorMsg }}</v-alert>

              <v-form ref="formRef" @submit.prevent="onSubmit">
                <v-text-field
                  v-model="email"
                  label="Email"
                  type="email"
                  prepend-inner-icon="mdi-email-outline"
                  :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                  autocomplete="email"
                />
                <v-text-field
                  v-model="password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  prepend-inner-icon="mdi-lock-outline"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Password required']"
                  autocomplete="current-password"
                  @click:append-inner="show = !show"
                />

                <div class="d-flex justify-end mb-4">
                  <v-btn variant="text" size="small" class="text-none" to="/forgot-password">
                    Forgot password?
                  </v-btn>
                </div>

                <v-btn
                  type="submit"
                  color="primary"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none"
                  :loading="auth.loading"
                >Sign In</v-btn>

                <div class="text-center mt-6 text-body-2">
                  Don't have an account?
                  <NuxtLink to="/register" class="text-primary font-weight-medium">Sign up</NuxtLink>
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
const email = ref('')
const password = ref('')
const show = ref(false)
const errorMsg = ref('')

const bullets = [
  'Multi-tenant hospital, pharmacy & lab',
  'Real-time prescriptions & dispensing',
  'Patient online orders & exchange',
  'Role-based dashboards & analytics'
]

async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  const ok = await auth.login(email.value.trim(), password.value)
  if (ok) router.push('/dashboard')
  else errorMsg.value = auth.error || 'Login failed.'
}
</script>

<style scoped>
.auth-root {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
}
.bg-fill {
  position: absolute;
  inset: 0;
  z-index: 0;
}
.blob {
  position: absolute;
  border-radius: 50%;
  background: rgba(255,255,255,0.05);
  z-index: 1;
}
.blob-1 { top: -80px; left: -80px; width: 240px; height: 240px; }
.blob-2 { bottom: -60px; right: -60px; width: 300px; height: 300px; }
</style>
