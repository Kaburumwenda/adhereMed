<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader
      title="Mail Settings"
      icon="mdi-email-cog"
      subtitle="Platform outgoing (SMTP) & incoming (IMAP) mail configuration"
    >
      <template #actions>
        <v-btn
          variant="text" rounded="lg" class="text-none"
          prepend-icon="mdi-refresh"
          :loading="loading"
          @click="load"
        >
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <v-row>
      <v-col cols="12" lg="8">
        <v-card rounded="xl" elevation="0" class="section-card">
          <div class="d-flex align-center pa-4">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="44" class="mr-3">
              <v-icon>mdi-email-fast</v-icon>
            </v-avatar>
            <div>
              <div class="text-subtitle-1 font-weight-bold">Mailbox configuration</div>
              <div class="text-caption text-medium-emphasis">
                Used to send transactional emails such as patient welcome messages.
              </div>
            </div>
            <v-spacer />
            <v-chip
              :color="form.is_active ? 'success' : 'grey'"
              variant="tonal" size="small" class="font-weight-medium"
            >
              {{ form.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>
          <v-divider />

          <v-progress-linear v-if="loading" color="primary" indeterminate height="3" />

          <div class="pa-4 pa-md-6">
            <v-form ref="formRef" @submit.prevent="save">
              <div class="text-overline text-medium-emphasis mb-1">Sender identity</div>
              <v-row dense class="mb-2">
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.from_name" label="From name"
                    prepend-inner-icon="mdi-account-tie"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.from_email" label="From email" :rules="emailRule"
                    prepend-inner-icon="mdi-email"
                    variant="outlined" density="comfortable" rounded="lg"
                  />
                </v-col>
              </v-row>

              <div class="text-overline text-medium-emphasis mb-1 mt-2">Credentials</div>
              <v-row dense class="mb-2">
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.username" label="Username"
                    prepend-inner-icon="mdi-account"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.password"
                    :label="hasPassword ? 'Password (leave blank to keep)' : 'Password'"
                    :type="showPassword ? 'text' : 'password'"
                    :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                    prepend-inner-icon="mdi-lock"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                    @click:append-inner="showPassword = !showPassword"
                  />
                </v-col>
              </v-row>

              <div class="text-overline text-medium-emphasis mb-1 mt-2">Outgoing server (SMTP)</div>
              <v-row dense class="mb-2">
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.smtp_host" label="SMTP host"
                    prepend-inner-icon="mdi-server-network"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="6" sm="3">
                  <v-text-field
                    v-model.number="form.smtp_port" label="SMTP port" type="number"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="6" sm="3" class="d-flex align-center">
                  <v-switch
                    v-model="form.smtp_use_ssl" label="SSL" color="primary"
                    density="compact" hide-details inset
                  />
                </v-col>
              </v-row>

              <div class="text-overline text-medium-emphasis mb-1 mt-2">Incoming server (IMAP)</div>
              <v-row dense class="mb-2">
                <v-col cols="12" sm="6">
                  <v-text-field
                    v-model="form.imap_host" label="IMAP host"
                    prepend-inner-icon="mdi-server-network"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="6" sm="3">
                  <v-text-field
                    v-model.number="form.imap_port" label="IMAP port" type="number"
                    variant="outlined" density="comfortable" rounded="lg" hide-details
                  />
                </v-col>
                <v-col cols="6" sm="3" class="d-flex align-center">
                  <v-switch
                    v-model="form.imap_use_ssl" label="SSL" color="primary"
                    density="compact" hide-details inset
                  />
                </v-col>
              </v-row>

              <v-divider class="my-4" />

              <div class="d-flex align-center flex-wrap" style="gap:12px">
                <v-switch
                  v-model="form.is_active" label="Enable this configuration"
                  color="success" density="compact" hide-details inset
                />
                <v-spacer />
                <v-btn
                  variant="tonal" color="primary" rounded="lg" class="text-none"
                  prepend-icon="mdi-email-check" :loading="testing"
                  @click="openTest"
                >
                  Send test email
                </v-btn>
                <v-btn
                  type="submit" color="primary" variant="flat" rounded="lg" class="text-none"
                  prepend-icon="mdi-content-save" :loading="saving"
                >
                  Save changes
                </v-btn>
              </div>
            </v-form>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" elevation="0" class="section-card mb-4">
          <div class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-2">
              <v-icon size="18" color="primary" class="mr-1">mdi-shield-check</v-icon>
              Verification status
            </div>
            <v-alert
              :type="form.last_verified_ok ? 'success' : 'info'"
              variant="tonal" density="comfortable" class="mb-2"
            >
              <div class="text-body-2">
                <template v-if="form.last_verified_at">
                  Last tested: {{ formatDateTime(form.last_verified_at) }}<br>
                  Result:
                  <strong>{{ form.last_verified_ok ? 'Delivered' : 'Failed' }}</strong>
                </template>
                <template v-else>Not tested yet.</template>
              </div>
            </v-alert>
            <div v-if="form.last_error" class="text-caption text-error">
              {{ form.last_error }}
            </div>
          </div>
        </v-card>

        <v-card rounded="xl" elevation="0" class="section-card">
          <div class="pa-4">
            <div class="text-subtitle-2 font-weight-bold mb-2">
              <v-icon size="18" color="info" class="mr-1">mdi-information</v-icon>
              How it's used
            </div>
            <p class="text-body-2 text-medium-emphasis mb-2">
              When a patient completes registration, a welcome email is sent
              automatically containing their unique Patient ID (e.g.
              <strong>AD02</strong>) and instructions to use it across all
              AdhereMed services.
            </p>
            <p class="text-body-2 text-medium-emphasis mb-0">
              If this configuration is disabled, the platform falls back to the
              default mail settings defined in the server environment.
            </p>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Test dialog -->
    <v-dialog v-model="testDialog" max-width="440">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="primary" class="mr-2">mdi-email-check</v-icon>
          Send test email
        </v-card-title>
        <v-card-text class="px-5">
          <p class="text-body-2 text-medium-emphasis mb-3">
            Save your changes first, then send a test message to verify delivery.
          </p>
          <v-text-field
            v-model="testTo" label="Recipient email" :rules="emailRule"
            prepend-inner-icon="mdi-email" variant="outlined" density="comfortable" rounded="lg"
          />
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="testDialog = false">Cancel</v-btn>
          <v-btn
            color="primary" variant="flat" rounded="lg" class="text-none"
            :loading="testing" :disabled="!testTo" @click="sendTest"
          >
            Send
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" rounded="lg" location="top">
      {{ snack.text }}
      <template #actions>
        <v-btn variant="text" @click="snack.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const showPassword = ref(false)
const hasPassword = ref(false)
const formRef = ref(null)
const testDialog = ref(false)
const testTo = ref('')

const form = reactive({
  from_name: 'AdhereMed',
  from_email: 'info@adheremed.co',
  username: 'info@adheremed.co',
  password: '',
  smtp_host: 'mail.adheremed.co',
  smtp_port: 465,
  smtp_use_ssl: true,
  imap_host: 'mail.adheremed.co',
  imap_port: 993,
  imap_use_ssl: true,
  is_active: true,
  last_verified_at: null,
  last_verified_ok: false,
  last_error: '',
})

const snack = reactive({ show: false, text: '', color: 'success' })
const emailRule = [
  v => !!v || 'Email required',
  v => /.+@.+\..+/.test(v) || 'Invalid email',
]

function notify(text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/superadmin/mail/config/')
    hasPassword.value = !!data.has_password
    Object.assign(form, {
      from_name: data.from_name,
      from_email: data.from_email,
      username: data.username,
      password: '',
      smtp_host: data.smtp_host,
      smtp_port: data.smtp_port,
      smtp_use_ssl: data.smtp_use_ssl,
      imap_host: data.imap_host,
      imap_port: data.imap_port,
      imap_use_ssl: data.imap_use_ssl,
      is_active: data.is_active,
      last_verified_at: data.last_verified_at,
      last_verified_ok: data.last_verified_ok,
      last_error: data.last_error || '',
    })
  } catch (e) {
    notify('Failed to load mail settings.', 'error')
  } finally {
    loading.value = false
  }
}

async function save() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    const payload = {
      from_name: form.from_name,
      from_email: form.from_email,
      username: form.username,
      smtp_host: form.smtp_host,
      smtp_port: form.smtp_port,
      smtp_use_ssl: form.smtp_use_ssl,
      imap_host: form.imap_host,
      imap_port: form.imap_port,
      imap_use_ssl: form.imap_use_ssl,
      is_active: form.is_active,
    }
    if (form.password) payload.password = form.password
    const { data } = await $api.patch('/superadmin/mail/config/', payload)
    hasPassword.value = !!data.has_password
    form.password = ''
    notify('Mail settings saved.')
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save mail settings.', 'error')
  } finally {
    saving.value = false
  }
}

function openTest() {
  testTo.value = form.from_email
  testDialog.value = true
}

async function sendTest() {
  testing.value = true
  try {
    const { data } = await $api.post('/superadmin/mail/test/', { to: testTo.value })
    notify(data.detail || 'Test email sent.')
    testDialog.value = false
    await load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to send test email.', 'error')
  } finally {
    testing.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.section-card {
  border: 1px solid rgba(var(--v-border-color), 0.12);
}
</style>
