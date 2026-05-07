<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="brand-gradient bg-fill" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row no-gutters class="fill-height" align="center" justify="center">
          <v-col cols="12" sm="10" md="8" lg="6" xl="5">
            <v-btn
              variant="text"
              color="white"
              class="text-none mb-4"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back</v-btn>

            <v-card rounded="xl" elevation="12" class="pa-6 pa-md-8">
              <div class="text-center mb-6">
                <BrandLogo :size="48" class="mx-auto" />
                <h2 class="text-h5 font-weight-bold mt-4">Create patient account</h2>
                <p class="text-body-2 text-medium-emphasis">
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
                    <v-text-field v-model="firstName" label="First name" :rules="req" />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-text-field v-model="lastName" label="Last name" :rules="req" />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="email"
                  label="Email"
                  type="email"
                  prepend-inner-icon="mdi-email-outline"
                  :rules="[v => !!v || 'Email required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                />
                <v-text-field
                  v-model="phone"
                  label="Phone"
                  prepend-inner-icon="mdi-phone-outline"
                />
                <v-text-field
                  v-model="nationalId"
                  label="National ID"
                  prepend-inner-icon="mdi-card-account-details-outline"
                  :rules="req"
                />
                <v-text-field
                  v-model="password"
                  label="Password"
                  :type="show ? 'text' : 'password'"
                  prepend-inner-icon="mdi-lock-outline"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  :rules="[v => !!v || 'Password required', v => v.length >= 6 || 'Min 6 characters']"
                  @click:append-inner="show = !show"
                />

                <v-btn
                  type="submit"
                  color="primary"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none mt-2"
                  :loading="auth.loading"
                >Create Account</v-btn>

                <div class="text-center mt-6 text-body-2">
                  Already have an account?
                  <NuxtLink to="/login" class="text-primary font-weight-medium">Sign in</NuxtLink>
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
.auth-root { position: relative; min-height: 100vh; overflow: hidden; }
.bg-fill { position: absolute; inset: 0; z-index: 0; }
</style>
