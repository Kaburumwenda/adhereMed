<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <!-- Background layers -->
      <div class="bg-base bg-fill" />
      <div class="bg-grid bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row no-gutters class="fill-height" align="center" justify="center">

          <!-- Branding panel (desktop) -->
          <v-col v-if="$vuetify.display.mdAndUp" md="6" class="pa-12">
            <v-btn
              variant="text"
              class="text-none nav-back mb-10"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back to home</v-btn>

            <!-- Brand lockup -->
            <div class="d-flex align-center mb-6">
              <div class="brand-badge d-flex align-center justify-center mr-3">
                <v-icon size="22" color="white">mdi-heart-pulse</v-icon>
              </div>
              <span class="brand-word">
                <span class="bold">Adhere</span><span class="light">Med</span>
              </span>
            </div>

            <h2 class="panel-headline mb-3">
              Connected Healthcare.<br>
              <span class="grad-text">Simplified.</span>
            </h2>
            <p class="panel-sub mb-10">Africa's healthcare operating system — one intelligent platform for every actor in the care journey.</p>

            <div v-for="b in bullets" :key="b" class="bullet-row d-flex align-center mb-4">
              <div class="bullet-dot mr-3">
                <v-icon size="15" color="white">mdi-check</v-icon>
              </div>
              <span>{{ b }}</span>
            </div>
          </v-col>

          <!-- Form card -->
          <v-col cols="12" sm="9" md="5" lg="4" class="pa-4 pa-md-8">
            <!-- Mobile back -->
            <v-btn
              v-if="!$vuetify.display.mdAndUp"
              variant="text"
              class="text-none nav-back mb-4"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back</v-btn>

            <div class="form-card pa-7 pa-md-8">
              <div class="text-center mb-7">
                <div class="brand-badge mx-auto mb-4" style="width:52px;height:52px;border-radius:16px;">
                  <v-icon size="26" color="white">mdi-heart-pulse</v-icon>
                </div>
                <h2 class="form-title">Welcome back</h2>
                <p class="form-sub">Sign in to your AdhereMed account</p>
              </div>

              <v-alert
                v-if="errorMsg"
                type="error"
                variant="tonal"
                density="compact"
                rounded="lg"
                class="mb-5"
              >{{ errorMsg }}</v-alert>

              <v-form ref="formRef" @submit.prevent="onSubmit">
                <v-text-field
                  v-model="email"
                  label="Email"
                  type="email"
                  prepend-inner-icon="mdi-email-outline"
                  :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                  autocomplete="email"
                  variant="outlined"
                  rounded="lg"
                  class="field-dark mb-1"
                  density="comfortable"
                />
                <v-text-field
                  v-model="password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  prepend-inner-icon="mdi-lock-outline"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Password required']"
                  autocomplete="current-password"
                  variant="outlined"
                  rounded="lg"
                  class="field-dark"
                  density="comfortable"
                  @click:append-inner="show = !show"
                />

                <div class="d-flex justify-end mb-5 mt-1">
                  <v-btn variant="text" size="small" class="text-none forgot-link" to="/forgot-password">
                    Forgot password?
                  </v-btn>
                </div>

                <v-btn
                  type="submit"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none btn-primary mb-5"
                  :loading="auth.loading"
                >Sign In</v-btn>

                <div class="text-center text-body-2 form-footer-text">
                  Don't have an account?
                  <NuxtLink to="/register-pharmacy" class="form-link font-weight-medium">Register Pharmacy</NuxtLink>
                </div>
              </v-form>
            </div>
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
  if (ok) {
    const home = auth.tenantType === 'pharmacy' ? '/pharmacy'
      : auth.tenantType === 'lab' ? '/lab'
      : auth.tenantType === 'radiology_center' ? '/radiology'
      : '/dashboard'
    router.push(home)
  }
  else errorMsg.value = auth.error || 'Login failed.'
}
</script>

<style scoped>
/* ---------- Root / Background ---------- */
.auth-root {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  color: #fff;
}
.bg-fill { position: absolute; inset: 0; }
.bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(37, 99, 235, 0.35), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(59, 130, 246, 0.18), transparent 55%),
    linear-gradient(160deg, #060b18 0%, #081226 45%, #0a1530 100%);
}
.bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.04) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  z-index: 0;
}
.blob-1 { top: -120px; right: -80px; width: 380px; height: 380px; background: rgba(37, 99, 235, 0.38); }
.blob-2 { bottom: -80px; left: -80px; width: 340px; height: 340px; background: rgba(29, 78, 216, 0.28); }

/* ---------- Brand ---------- */
.brand-badge {
  width: 46px; height: 46px; border-radius: 13px;
  background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
  box-shadow: 0 6px 18px rgba(37, 99, 235, 0.5);
  display: flex; align-items: center; justify-content: center;
}
.brand-word { font-size: 22px; letter-spacing: -0.4px; }
.brand-word .bold { font-weight: 800; color: #fff; }
.brand-word .light { font-weight: 300; color: #60a5fa; }

/* ---------- Left panel ---------- */
.nav-back { color: rgba(255,255,255,0.7) !important; }
.panel-headline {
  font-size: clamp(1.9rem, 3.4vw, 2.8rem);
  font-weight: 800;
  line-height: 1.12;
  letter-spacing: -1px;
}
.grad-text {
  background: linear-gradient(90deg, #60a5fa, #93c5fd, #3b82f6);
  background-size: 200% auto;
  -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent;
  animation: shimmer 5s linear infinite;
}
.panel-sub { font-size: 1rem; line-height: 1.65; color: rgba(255,255,255,0.65); }
.bullet-row { color: rgba(255,255,255,0.82); font-size: 0.95rem; }
.bullet-dot {
  width: 26px; height: 26px; border-radius: 8px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #3b82f6, #1d4ed8);
  box-shadow: 0 4px 12px rgba(37, 99, 235, 0.4);
}

/* ---------- Form card ---------- */
.form-card {
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
}
.form-title {
  font-size: 1.55rem; font-weight: 800; color: #fff; letter-spacing: -0.4px;
}
.form-sub { font-size: 0.9rem; color: rgba(255,255,255,0.6); margin-top: 4px; }
.form-footer-text { color: rgba(255,255,255,0.62); }
.form-link { color: #60a5fa !important; }
.forgot-link { color: #93c5fd !important; }

/* ---------- Fields ---------- */
:deep(.field-dark .v-field) {
  background: rgba(255,255,255,0.06) !important;
  border: 1px solid rgba(255,255,255,0.12) !important;
  border-radius: 12px !important;
  color: #fff !important;
}
:deep(.field-dark .v-field--focused) {
  border-color: rgba(96,165,250,0.7) !important;
}
:deep(.field-dark .v-label) { color: rgba(255,255,255,0.55) !important; }
:deep(.field-dark .v-icon) { color: rgba(255,255,255,0.45) !important; }
:deep(.field-dark input) { color: #fff !important; }

/* ---------- Button ---------- */
.btn-primary {
  background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(37, 99, 235, 0.4);
}

@keyframes shimmer { to { background-position: 200% center; } }
</style>
