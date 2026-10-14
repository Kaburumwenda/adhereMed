<template>
  <div class="cc-settings-page">
    <!-- Background layers -->
    <div class="cc-settings-bg-base cc-bg-fill" />
    <div class="cc-settings-bg-grid cc-bg-fill" />
    <div class="cc-settings-blob cc-settings-blob-1" />
    <div class="cc-settings-blob cc-settings-blob-2" />

    <div class="cc-settings-inner">
      <!-- Header -->
      <header class="cc-settings-header">
        <div class="d-flex align-center">
          <v-btn variant="text" color="surface-variant" prepend-icon="mdi-arrow-left" @click="navigateTo('/command-center')">
            <span class="d-none d-sm-inline">Back</span>
          </v-btn>
          <v-divider vertical class="mx-3 bg-divider" />
          <v-avatar size="40" color="primary" variant="flat" class="mr-2">
            <img v-if="logoPreview" :src="logoPreview" alt="Logo" class="cc-logo-img" />
            <v-icon v-else color="white" size="22">mdi-view-dashboard-outline</v-icon>
          </v-avatar>
          <div>
            <div class="cc-settings-label text-body-2">Command Center</div>
            <div class="text-h6 font-weight-bold text-surface-variant">Organization Settings</div>
          </div>
        </div>
        <v-avatar size="42" color="primary" variant="flat" class="cc-avatar">
          <span class="text-white font-weight-bold">{{ initial }}</span>
        </v-avatar>
      </header>

      <main class="cc-settings-main">
        <!-- Loading -->
        <div v-if="loading" class="text-center py-16">
          <v-progress-circular indeterminate size="56" width="4" color="primary" />
        </div>

        <template v-else>
          <!-- ── Organization Profile Card ── -->
          <section class="settings-section">
            <div class="section-title">
              <v-icon class="mr-2" color="primary">mdi-domain</v-icon>
              <span>Organization Profile</span>
            </div>
            <v-card rounded="xl" class="settings-card mt-3">
              <v-card-text class="pa-5">
                <!-- Logo upload -->
                <div class="logo-row mb-5">
                  <div class="logo-preview">
                    <img
                      v-if="logoPreview"
                      :src="logoPreview"
                      alt="Logo"
                      class="logo-img"
                    />
                    <v-icon v-else size="48" color="grey-lighten-1">mdi-image</v-icon>
                  </div>
                  <div class="logo-actions">
                    <v-btn variant="outlined" color="primary" prepend-icon="mdi-upload" @click="$refs.logoInput.click()">
                      Upload Logo
                    </v-btn>
                    <v-btn v-if="logoPreview" variant="text" color="error" prepend-icon="mdi-delete" @click="removeLogo">
                      Remove
                    </v-btn>
                    <input
                      ref="logoInput"
                      type="file"
                      accept="image/*"
                      class="d-none"
                      @change="onLogoChange"
                    />
                    <div class="text-caption text-medium-emphasis mt-1">PNG, JPG up to 2MB. Recommended 256×256.</div>
                  </div>
                </div>

                <v-text-field
                  v-model="orgForm.name"
                  label="Organization Name"
                  prepend-inner-icon="mdi-domain"
                  variant="outlined"
                  density="comfortable"
                  class="mb-3"
                  hide-details="auto"
                />
                <v-text-field
                  v-model="orgForm.motto"
                  label="Motto"
                  prepend-inner-icon="mdi-format-quote-close"
                  variant="outlined"
                  density="comfortable"
                  class="mb-3"
                  hide-details="auto"
                  placeholder="e.g. Quality care for every patient, every time."
                />
                <v-row dense>
                  <v-col cols="12" sm="6">
                    <v-text-field
                      v-model="orgForm.email"
                      label="Email"
                      prepend-inner-icon="mdi-email-outline"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                      class="mb-3"
                    />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-text-field
                      v-model="orgForm.phone"
                      label="Phone"
                      prepend-inner-icon="mdi-phone-outline"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                      class="mb-3"
                    />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="orgForm.address"
                  label="Address"
                  prepend-inner-icon="mdi-map-marker-outline"
                  variant="outlined"
                  density="comfortable"
                  class="mb-3"
                  hide-details="auto"
                />
                <v-row dense>
                  <v-col cols="12" sm="6">
                    <v-text-field
                      v-model="orgForm.city"
                      label="City"
                      prepend-inner-icon="mdi-city"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                      class="mb-3"
                    />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-text-field
                      v-model="orgForm.country"
                      label="Country"
                      prepend-inner-icon="mdi-flag-outline"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                      class="mb-3"
                    />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="orgForm.website"
                  label="Website"
                  prepend-inner-icon="mdi-web"
                  variant="outlined"
                  density="comfortable"
                  hide-details="auto"
                />
              </v-card-text>
              <v-divider />
              <v-card-actions class="pa-4">
                <v-spacer />
                <v-btn color="primary" variant="flat" prepend-icon="mdi-content-save" :loading="savingProfile" @click="saveProfile">
                  Save Changes
                </v-btn>
              </v-card-actions>
            </v-card>
          </section>

          <!-- ── Organization Admins Card ── -->
          <section class="settings-section mt-6">
            <div class="section-title">
              <v-icon class="mr-2" color="primary">mdi-account-key</v-icon>
              <span>Organization Admins</span>
              <v-chip size="small" variant="flat" color="primary" class="ml-3">{{ adminList.length }} admin{{ adminList.length !== 1 ? 's' : '' }}</v-chip>
            </div>
            <v-card rounded="xl" class="settings-card mt-3">
              <!-- Add admin -->
              <v-card-text class="pa-5">
                <div class="text-subtitle-2 font-weight-bold mb-2">Add Admin</div>
                <div class="text-body-2 text-medium-emphasis mb-3">Enter the email of an existing user to grant them organization admin access.</div>
                <div class="d-flex align-center gap-2 flex-wrap">
                  <v-text-field
                    v-model="newAdminEmail"
                    label="User Email"
                    prepend-inner-icon="mdi-email-plus-outline"
                    variant="outlined"
                    density="comfortable"
                    hide-details="auto"
                    class="flex-grow-1"
                    style="min-width: 260px;"
                  />
                  <v-btn color="primary" variant="flat" prepend-icon="mdi-account-plus" :loading="addingAdmin" @click="addAdmin">
                    Add Admin
                  </v-btn>
                </div>
              </v-card-text>
              <v-divider />
              <!-- Admin list -->
              <v-list class="py-0">
                <template v-if="adminList.length">
                  <v-list-item
                    v-for="adm in adminList"
                    :key="adm.id"
                    class="admin-row"
                  >
                    <template #prepend>
                      <v-avatar size="40" color="primary" variant="tonal">
                        <v-icon>mdi-shield-account</v-icon>
                      </v-avatar>
                    </template>
                    <v-list-item-title class="font-weight-medium">
                      {{ adm.first_name }} {{ adm.last_name }}
                      <span class="text-medium-emphasis ml-1">— {{ adm.email }}</span>
                    </v-list-item-title>
                    <v-list-item-subtitle>Organization Administrator</v-list-item-subtitle>
                    <template #append>
                      <v-btn
                        icon
                        variant="text"
                        color="error"
                        size="small"
                        :loading="removingId === adm.id"
                        @click="removeAdmin(adm)"
                      >
                        <v-icon>mdi-account-remove</v-icon>
                        <v-tooltip activator="parent" location="top">Remove admin</v-tooltip>
                      </v-btn>
                    </template>
                  </v-list-item>
                </template>
                <v-list-item v-else>
                  <v-list-item-title class="text-medium-emphasis">No admins assigned.</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-card>
          </section>
        </template>

        <!-- Error / success snackbar -->
        <v-snackbar v-model="snack" :color="snackColor" timeout="4000" location="top">
          {{ snackMsg }}
          <template #actions>
            <v-btn variant="text" @click="snack = false">Close</v-btn>
          </template>
        </v-snackbar>
      </main>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

definePageMeta({ layout: false })

const auth = useAuthStore()
const $api = useNuxtApp().$api

const loading = ref(false)
const savingProfile = ref(false)
const addingAdmin = ref(false)
const removingId = ref(null)

const snack = ref(false)
const snackMsg = ref('')
const snackColor = ref('success')

function notify(msg, color = 'success') {
  snackMsg.value = msg
  snackColor.value = color
  snack.value = true
}

const initial = computed(() => {
  const n = auth.user?.first_name || 'U'
  return (n[0] || 'U').toUpperCase()
})

// ── Org profile form ──
const orgForm = reactive({
  name: '', motto: '', email: '', phone: '', address: '', city: '', country: '', website: ''
})
const logoFile = ref(null)
const logoPreview = ref(null)
const removeLogoFlag = ref(false)

function onLogoChange(e) {
  const f = e.target.files?.[0]
  if (!f) return
  if (f.size > 2 * 1024 * 1024) {
    notify('Logo must be under 2MB', 'error')
    return
  }
  logoFile.value = f
  logoPreview.value = URL.createObjectURL(f)
  removeLogoFlag.value = false
}

function removeLogo() {
  logoFile.value = null
  logoPreview.value = null
  removeLogoFlag.value = true
}

// ── Admin management ──
const adminList = ref([])
const newAdminEmail = ref('')

async function loadAdmins() {
  try {
    const orgId = auth.organizationId
    if (!orgId) return
    const { data } = await $api.get(`/organizations/admin/${orgId}/`)
    adminList.value = data.admin_users || []
  } catch {
    // Non-critical
  }
}

async function addAdmin() {
  if (!newAdminEmail.value) {
    notify('Enter a user email first', 'warning')
    return
  }
  addingAdmin.value = true
  try {
    const orgId = auth.organizationId
    await $api.post(`/organizations/admin/${orgId}/set-admin/`, {
      user_email: newAdminEmail.value.trim()
    })
    newAdminEmail.value = ''
    await loadAdmins()
    notify('Admin added successfully')
  } catch (err) {
    notify(err?.response?.data?.detail || 'Failed to add admin', 'error')
  } finally {
    addingAdmin.value = false
  }
}

async function removeAdmin(adm) {
  removingId.value = adm.id
  try {
    const orgId = auth.organizationId
    await $api.post(`/organizations/admin/${orgId}/remove-admin/`, {
      user_id: adm.id
    })
    await loadAdmins()
    notify('Admin removed')
  } catch (err) {
    notify(err?.response?.data?.detail || 'Failed to remove admin', 'error')
  } finally {
    removingId.value = null
  }
}

// ── Save profile ──
async function saveProfile() {
  savingProfile.value = true
  try {
    const fd = new FormData()
    for (const k of ['name', 'motto', 'email', 'phone', 'address', 'city', 'country', 'website']) {
      fd.append(k, orgForm[k] ?? '')
    }
    if (logoFile.value) {
      const f = Array.isArray(logoFile.value) ? logoFile.value[0] : logoFile.value
      if (f) fd.append('logo', f)
    } else if (removeLogoFlag.value) {
      fd.append('logo', '')
    }
    await $api.patch('/organizations/me/', fd)
    notify('Organization profile updated')
    // Update auth store org name
    if (auth.organizationName !== orgForm.name) {
      auth._persistUser({ ...auth.user, organization_name: orgForm.name })
    }
    // Clear logo flags after save
    logoFile.value = null
    removeLogoFlag.value = false
    await loadProfile()
  } catch (err) {
    notify(err?.response?.data?.detail || 'Failed to update profile', 'error')
  } finally {
    savingProfile.value = false
  }
}

async function loadProfile() {
  loading.value = true
  try {
    const { data } = await $api.get('/organizations/me/')
    orgForm.name    = data.name    || ''
    orgForm.motto   = data.motto   || ''
    orgForm.email   = data.email   || ''
    orgForm.phone   = data.phone   || ''
    orgForm.address = data.address || ''
    orgForm.city    = data.city    || ''
    orgForm.country = data.country || ''
    orgForm.website = data.website || ''
    logoPreview.value = data.logo || null
  } catch (err) {
    notify('Failed to load organization data', 'error')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  if (!auth.isOrgAdmin) {
    navigateTo('/command-center', { replace: true })
    return
  }
  loadProfile()
  loadAdmins()
})
</script>

<style scoped>
.cc-settings-page {
  min-height: 100vh;
  position: relative;
  overflow: hidden;
  color: #0a0f1f;
}
.cc-bg-fill { position: absolute; inset: 0; }
.cc-settings-bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.cc-settings-bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.03) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.cc-settings-blob {
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  z-index: 0;
}
.cc-settings-blob-1 { top: -120px; right: -80px; width: 380px; height: 380px; background: rgba(47, 109, 255, 0.15); animation: float-orb 16s ease-in-out infinite; }
.cc-settings-blob-2 { bottom: -80px; left: -80px; width: 340px; height: 340px; background: rgba(55, 214, 255, 0.10); animation-delay: 5s; }
@keyframes float-orb {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(30px, -40px) scale(1.05); }
  66% { transform: translate(-20px, 20px) scale(0.95); }
}

.cc-settings-inner {
  position: relative;
  z-index: 1;
  max-width: 860px;
  margin: 0 auto;
  padding: 24px 20px;
}
.cc-settings-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 28px;
  animation: fade-down 0.5s ease;
}
@keyframes fade-down {
  from { opacity: 0; transform: translateY(-12px); }
  to   { opacity: 1; transform: translateY(0); }
}
.cc-avatar {
  box-shadow: 0 4px 16px rgba(0,0,0,0.25);
}

.cc-settings-main {
  animation: settings-in 0.5s ease;
}
@keyframes settings-in {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}

.section-title {
  display: flex;
  align-items: center;
  font-size: 1.1rem;
  font-weight: 700;
  color: #0a0f1f;
  margin-bottom: 4px;
}
.settings-section { margin-bottom: 8px; }
.settings-card {
  background: rgba(255, 255, 255, 0.96);
  backdrop-filter: blur(12px);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.18);
}

.logo-row {
  display: flex;
  align-items: center;
  gap: 20px;
}
.logo-preview {
  width: 96px;
  height: 96px;
  border-radius: 16px;
  border: 2px dashed #cbd5e1;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex-shrink: 0;
  background: #f8fafc;
}
.logo-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 14px;
}
.cc-logo-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: inherit;
}
.logo-actions {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.gap-2 { gap: 8px; }
.flex-grow-1 { flex: 1 1 0; }

.admin-row {
  transition: background 0.2s;
}
.admin-row:hover {
  background: rgba(47, 109, 255, 0.04);
}

.bg-divider {
  background: rgba(15, 23, 42, 0.12) !important;
}
.cc-settings-label {
  color: rgba(15, 23, 42, 0.5);
  text-transform: uppercase;
  letter-spacing: 1px;
}
</style>
