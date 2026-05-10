<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Mail settings"
      subtitle="Configure the mailbox the homecare team uses to send and receive email."
      eyebrow="SETTINGS"
      icon="mdi-email-edit"
      :chips="[
        { icon: usingOverride ? 'mdi-check-decagram' : 'mdi-cog',
          label: usingOverride ? 'Custom mailbox active' : 'Using system default' },
        { icon: 'mdi-account', label: effectiveFromName || '—' }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" class="text-none"
               prepend-icon="mdi-arrow-left" to="/homecare/mail">
          <span class="text-teal-darken-2 font-weight-bold">Back to mailbox</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" lg="8">
        <HomecarePanel title="Mailbox credentials"
                       subtitle="Provide IMAP + SMTP details to override the system default."
                       icon="mdi-server-network" color="#0d9488">
          <div v-if="loading" class="text-center py-8">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <v-form v-else ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.display_name" label="From display name"
                              :placeholder="`Defaults to your tenant name`"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.email" label="Mailbox email *"
                              variant="outlined" rounded="lg" density="comfortable"
                              :rules="[v => !!v || 'Required']"
                              hide-details="auto" />
              </v-col>

              <v-col cols="12"><v-divider class="my-2" /></v-col>
              <v-col cols="12">
                <div class="text-subtitle-2 font-weight-bold">
                  <v-icon icon="mdi-tray-arrow-down" class="mr-1" />Incoming (IMAP)
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.imap_host" label="IMAP host *"
                              placeholder="adheremed.tiktek-ex.com"
                              variant="outlined" rounded="lg" density="comfortable"
                              :rules="[v => !!v || 'Required']"
                              hide-details="auto" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.imap_port" label="IMAP port"
                              type="number" variant="outlined" rounded="lg"
                              density="comfortable" hide-details="auto" />
              </v-col>
              <v-col cols="6" md="3" class="d-flex align-center">
                <v-switch v-model="form.imap_use_ssl" label="Use SSL/TLS"
                          color="teal" hide-details density="comfortable" />
              </v-col>

              <v-col cols="12"><v-divider class="my-2" /></v-col>
              <v-col cols="12">
                <div class="text-subtitle-2 font-weight-bold">
                  <v-icon icon="mdi-tray-arrow-up" class="mr-1" />Outgoing (SMTP)
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.smtp_host" label="SMTP host *"
                              placeholder="adheremed.tiktek-ex.com"
                              variant="outlined" rounded="lg" density="comfortable"
                              :rules="[v => !!v || 'Required']"
                              hide-details="auto" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.smtp_port" label="SMTP port"
                              type="number" variant="outlined" rounded="lg"
                              density="comfortable" hide-details="auto" />
              </v-col>
              <v-col cols="6" md="3" class="d-flex align-center">
                <v-switch v-model="form.smtp_use_ssl" label="Use SSL/TLS"
                          color="teal" hide-details density="comfortable" />
              </v-col>

              <v-col cols="12"><v-divider class="my-2" /></v-col>
              <v-col cols="12">
                <div class="text-subtitle-2 font-weight-bold">
                  <v-icon icon="mdi-key" class="mr-1" />Authentication
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.username" label="Username *"
                              placeholder="homecare@adheremed.tiktek-ex.com"
                              variant="outlined" rounded="lg" density="comfortable"
                              :rules="[v => !!v || 'Required']"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.password" label="Password"
                              :type="showPwd ? 'text' : 'password'"
                              :append-inner-icon="showPwd ? 'mdi-eye-off' : 'mdi-eye'"
                              @click:append-inner="showPwd = !showPwd"
                              :placeholder="form.has_password ? '•••••••• (leave blank to keep)' : ''"
                              variant="outlined" rounded="lg" density="comfortable"
                              autocomplete="new-password" hide-details="auto" />
              </v-col>

              <v-col cols="12">
                <v-switch v-model="form.is_active"
                          label="Use these credentials (otherwise the system default mailbox is used)"
                          color="teal" hide-details inset />
              </v-col>
            </v-row>

            <div class="d-flex flex-wrap ga-2 mt-4">
              <v-btn type="submit" color="teal" variant="flat" rounded="lg"
                     class="text-none" prepend-icon="mdi-content-save"
                     :loading="saving">Save</v-btn>
              <v-btn color="indigo" variant="tonal" rounded="lg"
                     class="text-none" prepend-icon="mdi-lan-connect"
                     :loading="testing" @click="test">Test connection</v-btn>
              <v-spacer />
              <v-btn v-if="form.id" color="error" variant="text" rounded="lg"
                     class="text-none" prepend-icon="mdi-delete"
                     :loading="removing" @click="remove">
                Remove override
              </v-btn>
            </div>

            <v-alert v-if="testResult" :type="testResult.ok ? 'success' : 'error'"
                     variant="tonal" rounded="lg" class="mt-4" density="comfortable">
              <div class="font-weight-bold">
                {{ testResult.ok ? 'Credentials verified' : 'Verification failed' }}
              </div>
              <div class="text-body-2">
                IMAP: {{ testResult.imap_ok ? '✔ login successful' : '✘ failed' }} ·
                SMTP: {{ testResult.smtp_ok ? '✔ login successful' : '✘ failed' }}
              </div>
              <div v-if="testResult.error" class="text-caption mt-1">
                {{ testResult.error }}
              </div>
            </v-alert>
          </v-form>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="Effective configuration" icon="mdi-information"
                       color="#6366f1">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item>
              <v-list-item-title class="text-caption text-medium-emphasis">From name</v-list-item-title>
              <v-list-item-subtitle class="text-body-2 font-weight-bold">
                {{ effectiveFromName || '—' }}
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption text-medium-emphasis">From address</v-list-item-title>
              <v-list-item-subtitle class="text-body-2">
                {{ effectiveFromEmail || '—' }}
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item>
              <v-list-item-title class="text-caption text-medium-emphasis">Source</v-list-item-title>
              <v-list-item-subtitle>
                <v-chip size="small" :color="usingOverride ? 'success' : 'grey'"
                        variant="tonal">
                  {{ usingOverride ? 'Tenant override' : 'System default' }}
                </v-chip>
              </v-list-item-subtitle>
            </v-list-item>
            <v-list-item v-if="form.last_verified_at">
              <v-list-item-title class="text-caption text-medium-emphasis">
                Last verification
              </v-list-item-title>
              <v-list-item-subtitle>
                <v-icon :icon="form.last_verified_ok ? 'mdi-check-circle' : 'mdi-alert-circle'"
                        :color="form.last_verified_ok ? 'success' : 'error'"
                        size="16" class="mr-1" />
                {{ formatDate(form.last_verified_at) }}
              </v-list-item-subtitle>
            </v-list-item>
          </v-list>
          <v-divider class="my-3" />
          <p class="text-caption text-medium-emphasis mb-0">
            The "From name" displayed to recipients defaults to your tenant name
            unless you provide a custom display name above. Passwords are stored
            in the tenant database and never sent back to the browser.
          </p>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const loading = ref(true)
const saving = ref(false)
const testing = ref(false)
const removing = ref(false)
const showPwd = ref(false)
const formRef = ref(null)
const testResult = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

const form = reactive({
  id: null, display_name: '', email: '',
  imap_host: '', imap_port: 993, imap_use_ssl: true,
  smtp_host: '', smtp_port: 465, smtp_use_ssl: true,
  username: '', password: '', has_password: false, is_active: true,
  last_verified_at: null, last_verified_ok: false,
})

const usingOverride = ref(false)
const effectiveFromName = ref('')
const effectiveFromEmail = ref('')

function notify(text, color = 'info') {
  snack.text = text; snack.color = color; snack.show = true
}
function formatDate(iso) {
  if (!iso) return ''
  try { return new Date(iso).toLocaleString() } catch { return iso }
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/mail/account/')
    Object.assign(form, {
      ...data,
      password: '',
      imap_port: data.imap_port || 993,
      smtp_port: data.smtp_port || 465,
    })
    usingOverride.value = !!data.using_override
    effectiveFromName.value = data.effective_from_name || ''
    effectiveFromEmail.value = data.effective_from_email || ''
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed to load settings', 'error')
  } finally {
    loading.value = false
  }
}

async function save() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    const payload = { ...form }
    if (!payload.password) delete payload.password // keep existing
    delete payload.has_password
    delete payload.last_verified_at
    delete payload.last_verified_ok
    delete payload.last_error
    const method = form.id ? 'put' : 'post'
    const { data } = await $api[method]('/homecare/mail/account/', payload)
    Object.assign(form, { ...data, password: '' })
    notify('Settings saved', 'success')
    await load()
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed to save', 'error')
  } finally {
    saving.value = false
  }
}

async function test() {
  testing.value = true
  testResult.value = null
  try {
    const payload = form.password
      ? {
          imap_host: form.imap_host, imap_port: form.imap_port, imap_use_ssl: form.imap_use_ssl,
          smtp_host: form.smtp_host, smtp_port: form.smtp_port, smtp_use_ssl: form.smtp_use_ssl,
          username: form.username, password: form.password,
        }
      : {} // server tests saved/default config
    const { data } = await $api.post('/homecare/mail/account/test/', payload)
    testResult.value = data
    notify(data.ok ? 'Connection OK' : (data.error || 'Connection failed'),
           data.ok ? 'success' : 'error')
  } catch (e) {
    testResult.value = { ok: false, error: e.response?.data?.detail || String(e) }
    notify(testResult.value.error, 'error')
  } finally {
    testing.value = false
  }
}

async function remove() {
  if (!confirm('Remove the custom mail configuration? The system default will be used.')) return
  removing.value = true
  try {
    await $api.delete('/homecare/mail/account/')
    notify('Override removed', 'success')
    await load()
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed to remove', 'error')
  } finally {
    removing.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
</style>
