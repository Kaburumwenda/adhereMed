<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="indigo-darken-2" size="32">mdi-cog</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Pharmacy Settings</div>
              <div class="text-body-2" style="opacity:0.9">
                Configure your pharmacy profile, hours, delivery &amp; insurance.
              </div>
            </div>
          </div>
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-md-end mt-3 mt-md-0">
          <v-btn variant="flat" color="white" prepend-icon="mdi-refresh" class="text-indigo-darken-3"
                 :loading="loading" @click="loadProfile">Reload</v-btn>
        </v-col>
      </v-row>
    </v-card>

    <v-card flat rounded="xl" border>
      <v-tabs v-model="tab" color="primary" align-tabs="start" show-arrows>
        <v-tab value="profile" prepend-icon="mdi-store">Profile</v-tab>
        <v-tab value="hours" prepend-icon="mdi-clock">Operating hours</v-tab>
        <v-tab value="delivery" prepend-icon="mdi-truck-fast">Delivery &amp; services</v-tab>
        <v-tab value="insurance" prepend-icon="mdi-shield-check">Insurance</v-tab>
      </v-tabs>
      <v-divider />

      <v-window v-model="tab">
        <!-- Profile tab -->
        <v-window-item value="profile">
          <div class="pa-4 pa-md-6">
            <v-row dense>
              <v-col cols="12" md="4" class="text-center">
                <v-card variant="outlined" rounded="lg" class="pa-4">
                  <v-avatar size="120" color="grey-lighten-3" class="mb-3">
                    <v-img v-if="logoPreview" :src="logoPreview" cover />
                    <v-icon v-else size="64" color="grey">mdi-store</v-icon>
                  </v-avatar>
                  <div>
                    <v-file-input v-model="logoFile" accept="image/*" label="Upload logo"
                                  prepend-icon="mdi-image-plus" variant="outlined" density="compact"
                                  show-size hide-details @update:model-value="onLogoSelected" />
                    <v-btn class="mt-2" color="primary" variant="flat" size="small"
                           :disabled="!logoFile || !profile.id" :loading="uploading"
                           prepend-icon="mdi-upload" @click="uploadLogo">
                      Upload
                    </v-btn>
                  </div>
                </v-card>
              </v-col>
              <v-col cols="12" md="8">
                <v-row dense>
                  <v-col cols="12">
                    <v-text-field v-model="profile.name" label="Pharmacy name *"
                                  variant="outlined" density="comfortable"
                                  :error-messages="errors.name" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="profile.license_number" label="License number"
                                  prepend-inner-icon="mdi-card-account-details"
                                  variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12">
                    <v-textarea v-model="profile.description" label="Description" rows="4" auto-grow
                                variant="outlined" density="comfortable" />
                  </v-col>
                </v-row>
              </v-col>
            </v-row>
            <div class="text-right mt-4">
              <v-btn color="primary" variant="flat" :loading="saving" @click="save">
                Save profile
              </v-btn>
            </div>
          </div>
        </v-window-item>

        <!-- Hours tab -->
        <v-window-item value="hours">
          <div class="pa-4 pa-md-6">
            <div class="text-body-2 text-medium-emphasis mb-3">
              Set the open and close time for each day. Leave both blank or toggle off to mark as closed.
            </div>
            <v-row dense>
              <v-col v-for="day in days" :key="day.key" cols="12" md="6">
                <v-card variant="outlined" rounded="lg" class="pa-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon class="mr-2" color="primary">mdi-calendar-week</v-icon>
                    <div class="font-weight-medium">{{ day.label }}</div>
                    <v-spacer />
                    <v-switch v-model="hours[day.key].open" color="success" density="compact"
                              hide-details inset />
                  </div>
                  <v-row dense v-if="hours[day.key].open">
                    <v-col cols="6">
                      <v-text-field v-model="hours[day.key].from" type="time" label="Opens"
                                    density="compact" variant="outlined" hide-details />
                    </v-col>
                    <v-col cols="6">
                      <v-text-field v-model="hours[day.key].to" type="time" label="Closes"
                                    density="compact" variant="outlined" hide-details />
                    </v-col>
                  </v-row>
                  <div v-else class="text-caption text-medium-emphasis">Closed</div>
                </v-card>
              </v-col>
            </v-row>
            <div class="text-right mt-4">
              <v-btn color="primary" variant="flat" :loading="saving" @click="save">
                Save hours
              </v-btn>
            </div>
          </div>
        </v-window-item>

        <!-- Delivery tab -->
        <v-window-item value="delivery">
          <div class="pa-4 pa-md-6">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model.number="profile.delivery_radius_km" type="number" min="0" step="0.5"
                              label="Delivery radius (km)" prepend-inner-icon="mdi-map-marker-radius"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model.number="profile.delivery_fee" type="number" min="0" step="50"
                              label="Delivery fee" prepend-inner-icon="mdi-cash"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-combobox v-model="profile.services" label="Services offered" multiple chips closable-chips
                            variant="outlined" density="comfortable"
                            placeholder="e.g. delivery, compounding, vaccinations"
                            hint="Press enter after each" persistent-hint />
              </v-col>
            </v-row>
            <div class="text-right mt-4">
              <v-btn color="primary" variant="flat" :loading="saving" @click="save">
                Save delivery
              </v-btn>
            </div>
          </div>
        </v-window-item>

        <!-- Insurance tab -->
        <v-window-item value="insurance">
          <div class="pa-4 pa-md-6">
            <v-switch v-model="profile.accepts_insurance" label="Accepts insurance"
                      color="success" density="comfortable" inset hide-details class="mb-3" />
            <v-combobox v-model="profile.insurance_providers" label="Accepted insurance providers"
                        multiple chips closable-chips variant="outlined" density="comfortable"
                        :disabled="!profile.accepts_insurance"
                        placeholder="e.g. NHIF, Britam, Jubilee"
                        hint="Press enter after each" persistent-hint />
            <div class="text-right mt-4">
              <v-btn color="primary" variant="flat" :loading="saving" @click="save">
                Save insurance
              </v-btn>
            </div>
          </div>
        </v-window-item>
      </v-window>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'

const { $api } = useNuxtApp()

const tab = ref('profile')
const loading = ref(false)
const saving = ref(false)
const uploading = ref(false)

const days = [
  { key: 'mon', label: 'Monday' }, { key: 'tue', label: 'Tuesday' },
  { key: 'wed', label: 'Wednesday' }, { key: 'thu', label: 'Thursday' },
  { key: 'fri', label: 'Friday' }, { key: 'sat', label: 'Saturday' },
  { key: 'sun', label: 'Sunday' },
]
function defaultHours() {
  const h = {}
  days.forEach(d => { h[d.key] = { open: d.key !== 'sun', from: '08:00', to: '18:00' } })
  return h
}

const profile = reactive(blankProfile())
const hours = reactive(defaultHours())
const errors = reactive({})
const logoFile = ref(null)
const logoPreview = ref(null)

function blankProfile() {
  return {
    id: null, name: '', license_number: '', description: '',
    delivery_radius_km: 0, delivery_fee: 0,
    accepts_insurance: false, insurance_providers: [], services: [],
    operating_hours: {}, logo: null,
  }
}

async function loadProfile() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/profile/')
    const list = data?.results || data || []
    const p = Array.isArray(list) && list.length ? list[0] : null
    if (p) {
      Object.assign(profile, blankProfile(), p)
      // hydrate hours
      const h = p.operating_hours || {}
      days.forEach(d => {
        if (h[d.key]) hours[d.key] = { open: !!h[d.key].open, from: h[d.key].from || '08:00', to: h[d.key].to || '18:00' }
      })
      logoPreview.value = p.logo || null
    } else {
      Object.assign(profile, blankProfile())
    }
  } catch { notify('Failed to load settings', 'error') }
  finally { loading.value = false }
}
onMounted(loadProfile)

function onLogoSelected(file) {
  const f = Array.isArray(file) ? file[0] : file
  if (!f) { return }
  const reader = new FileReader()
  reader.onload = e => { logoPreview.value = e.target.result }
  reader.readAsDataURL(f)
}

async function uploadLogo() {
  if (!logoFile.value || !profile.id) return
  uploading.value = true
  const f = Array.isArray(logoFile.value) ? logoFile.value[0] : logoFile.value
  const fd = new FormData()
  fd.append('logo', f)
  try {
    const { data } = await $api.post(
      `/pharmacy-profile/profile/${profile.id}/upload-logo/`, fd,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    )
    profile.logo = data.logo
    logoPreview.value = data.logo
    logoFile.value = null
    notify('Logo updated')
  } catch (e) { notify(extractError(e) || 'Upload failed', 'error') }
  finally { uploading.value = false }
}

async function save() {
  Object.keys(errors).forEach(k => delete errors[k])
  if (!profile.name) { errors.name = 'Required'; tab.value = 'profile'; return }
  // pack hours
  const op = {}
  days.forEach(d => { op[d.key] = hours[d.key].open
    ? { open: true, from: hours[d.key].from, to: hours[d.key].to }
    : { open: false } })
  saving.value = true
  try {
    const payload = {
      name: profile.name,
      license_number: profile.license_number || '',
      description: profile.description || '',
      delivery_radius_km: profile.delivery_radius_km || 0,
      delivery_fee: profile.delivery_fee || 0,
      accepts_insurance: !!profile.accepts_insurance,
      insurance_providers: profile.insurance_providers || [],
      services: profile.services || [],
      operating_hours: op,
    }
    if (profile.id) {
      const { data } = await $api.patch(`/pharmacy-profile/profile/${profile.id}/`, payload)
      Object.assign(profile, data)
    } else {
      const { data } = await $api.post('/pharmacy-profile/profile/', payload)
      Object.assign(profile, data)
    }
    notify('Settings saved')
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #312e81 0%, #4f46e5 50%, #6366f1 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(79, 70, 229, 0.25);
}
</style>
