<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="brand-gradient bg-fill" />
      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row justify="center" align="center" class="fill-height">
          <v-col cols="12" sm="9" md="6" lg="5">
            <v-card rounded="xl" elevation="12" class="pa-6 pa-md-8">
              <div class="text-center mb-6">
                <BrandLogo :size="48" class="mx-auto" />
                <h2 class="text-h5 font-weight-bold mt-4">Reset Password</h2>
                <p class="text-body-2 text-medium-emphasis">Choose a new password.</p>
              </div>

              <v-alert v-if="success" type="success" variant="tonal" class="mb-4">
                Password updated. You may now sign in.
              </v-alert>
              <v-alert v-else-if="error" type="error" variant="tonal" class="mb-4">
                {{ error }}
              </v-alert>

              <v-form v-if="!success" ref="formRef" @submit.prevent="onSubmit">
                <v-text-field
                  v-model="password"
                  label="New password"
                  type="password"
                  prepend-inner-icon="mdi-lock-outline"
                  :rules="[v => !!v || 'Required', v => v.length >= 6 || 'Min 6 chars']"
                />
                <v-text-field
                  v-model="confirm"
                  label="Confirm password"
                  type="password"
                  prepend-inner-icon="mdi-lock-check-outline"
                  :rules="[v => v === password || 'Passwords must match']"
                />
                <v-btn
                  type="submit"
                  color="primary"
                  block
                  size="large"
                  rounded="lg"
                  class="text-none"
                  :loading="loading"
                >Reset Password</v-btn>
              </v-form>

              <div class="text-center mt-6 text-body-2">
                <NuxtLink to="/login" class="text-primary font-weight-medium">
                  Back to sign in
                </NuxtLink>
              </div>
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
const route = useRoute()
const formRef = ref(null)
const password = ref('')
const confirm = ref('')
const loading = ref(false)
const success = ref(false)
const error = ref('')

async function onSubmit() {
  error.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  loading.value = true
  try {
    await auth.resetPassword({
      uid: String(route.query.uid || ''),
      token: String(route.query.token || ''),
      password: password.value
    })
    success.value = true
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Reset link is invalid or expired.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-root { position: relative; min-height: 100vh; overflow: hidden; }
.bg-fill { position: absolute; inset: 0; z-index: 0; }
</style>
