<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="profile.legal_name || 'Company profile'"
      :subtitle="profile.about ? truncate(profile.about, 110) : 'Your homecare organisation profile.'"
      eyebrow="ORGANISATION"
      icon="mdi-domain"
      :chips="heroChips"
    >
      <template #actions>
        <v-btn variant="text" rounded="pill" color="white"
               prepend-icon="mdi-refresh" class="text-none mr-2"
               :loading="loading" @click="load">
          <span class="font-weight-medium">Reload</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-content-save" class="text-none"
               :loading="saving" @click="save">
          <span class="text-teal-darken-2 font-weight-bold">Save changes</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" md="4">
        <HomecarePanel title="Branding" icon="mdi-image" color="#0d9488">
          <div class="text-center">
            <v-avatar size="140" color="teal-lighten-5" class="mb-3" rounded="lg">
              <v-img v-if="logoPreview || profile.logo" :src="logoPreview || profile.logo" cover />
              <v-icon v-else icon="mdi-domain" size="64" color="teal" />
            </v-avatar>
            <div class="text-h6 font-weight-bold">{{ profile.legal_name || '—' }}</div>
            <div class="text-caption text-medium-emphasis mb-3">
              {{ [profile.city, profile.country].filter(Boolean).join(', ') || 'Location not set' }}
            </div>
            <v-file-input
              v-model="logoFile"
              label="Upload logo"
              accept="image/*" prepend-icon=""
              prepend-inner-icon="mdi-camera-plus"
              variant="outlined" density="comfortable" rounded="lg"
              hide-details show-size
              @update:model-value="onLogoChange"
            />
            <v-btn v-if="logoFile || profile.logo" variant="text" color="error"
                   size="small" class="text-none mt-2" @click="clearLogo">
              <v-icon icon="mdi-delete" start />Remove logo
            </v-btn>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Quick stats" icon="mdi-chart-box" color="#6366f1" class="mt-3">
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Service areas</div>
              <div class="text-h6 font-weight-bold">{{ (profile.service_areas || []).length }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Accreditations</div>
              <div class="text-h6 font-weight-bold">{{ (profile.accreditations || []).length }}</div>
            </v-col>
            <v-col v-if="profile.updated_at" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis">Last updated</div>
              <div class="text-body-2">{{ formatDate(profile.updated_at) }}</div>
            </v-col>
          </v-row>
        </HomecarePanel>
      </v-col>

      <v-col cols="12" md="8">
        <HomecarePanel title="Organisation details" icon="mdi-card-account-details"
                       subtitle="Used on patient portals, invoices and care reports."
                       color="#0ea5e9">
          <div v-if="loading && !profile.legal_name" class="text-center py-8">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <v-form v-else ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" md="8">
                <v-text-field v-model="profile.legal_name" label="Legal name *"
                              variant="outlined" rounded="lg" density="comfortable"
                              :rules="[v => !!v || 'Required']" hide-details="auto" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="profile.registration_number"
                              label="Registration number"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>

              <v-col cols="12" md="6">
                <v-text-field v-model="profile.contact_email" label="Contact email"
                              type="email" prepend-inner-icon="mdi-email-outline"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="profile.contact_phone" label="Contact phone"
                              prepend-inner-icon="mdi-phone-outline"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>

              <v-col cols="12">
                <v-textarea v-model="profile.address" label="Street address"
                            rows="2" auto-grow
                            prepend-inner-icon="mdi-map-marker-outline"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="profile.city" label="City"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="profile.country" label="Country"
                              variant="outlined" rounded="lg" density="comfortable"
                              hide-details="auto" />
              </v-col>

              <v-col cols="12">
                <v-text-field v-model="profile.license_url" label="License URL"
                              prepend-inner-icon="mdi-link"
                              hint="Public link to your operating licence (optional)"
                              persistent-hint
                              variant="outlined" rounded="lg" density="comfortable" />
              </v-col>

              <v-col cols="12">
                <v-textarea v-model="profile.about"
                            label="About the organisation"
                            rows="4" auto-grow counter="500"
                            placeholder="Briefly describe the services you provide…"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details="auto" />
              </v-col>

              <v-col cols="12"><v-divider class="my-2" /></v-col>

              <v-col cols="12">
                <div class="text-subtitle-2 font-weight-bold mb-1">
                  <v-icon icon="mdi-map-marker-radius" class="mr-1" />Service areas
                </div>
                <v-combobox v-model="profile.service_areas" multiple chips
                            closable-chips clearable
                            placeholder="Type a neighbourhood or city and press Enter"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details="auto" />
              </v-col>

              <v-col cols="12">
                <div class="text-subtitle-2 font-weight-bold mb-1">
                  <v-icon icon="mdi-certificate" class="mr-1" />Accreditations
                </div>
                <v-combobox v-model="profile.accreditations" multiple chips
                            closable-chips clearable
                            placeholder="Add accreditation name and press Enter"
                            variant="outlined" rounded="lg" density="comfortable"
                            hide-details="auto" />
              </v-col>
            </v-row>

            <div class="d-flex flex-wrap ga-2 mt-4">
              <v-btn type="submit" color="teal" variant="flat" rounded="lg"
                     class="text-none" prepend-icon="mdi-content-save"
                     :loading="saving">Save changes</v-btn>
              <v-btn variant="text" color="grey" rounded="lg" class="text-none"
                     prepend-icon="mdi-restore" :disabled="saving" @click="load">
                Discard
              </v-btn>
            </div>
          </v-form>
        </HomecarePanel>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const loading = ref(true)
const saving = ref(false)
const formRef = ref(null)
const logoFile = ref(null)
const logoPreview = ref('')
const removeLogo = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const blank = () => ({
  id: null, legal_name: '', registration_number: '',
  contact_email: '', contact_phone: '',
  address: '', city: '', country: 'Kenya',
  license_url: '', about: '',
  service_areas: [], accreditations: [],
  logo: null, updated_at: null,
})
const profile = reactive(blank())

const heroChips = computed(() => {
  const chips = []
  if (profile.contact_email) chips.push({ icon: 'mdi-email', label: profile.contact_email })
  if (profile.contact_phone) chips.push({ icon: 'mdi-phone', label: profile.contact_phone })
  if (profile.registration_number) chips.push({ icon: 'mdi-identifier', label: profile.registration_number })
  if (!chips.length) chips.push({ icon: 'mdi-information', label: 'Profile not yet completed' })
  return chips
})

function notify(text, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true
}
function truncate(s, n) { return s && s.length > n ? s.slice(0, n - 1) + '…' : s }
function formatDate(iso) {
  try { return new Date(iso).toLocaleString() } catch { return iso }
}

function onLogoChange(file) {
  removeLogo.value = false
  if (!file || (Array.isArray(file) && !file.length)) {
    logoPreview.value = ''
    return
  }
  const f = Array.isArray(file) ? file[0] : file
  const reader = new FileReader()
  reader.onload = () => { logoPreview.value = reader.result }
  reader.readAsDataURL(f)
}

function clearLogo() {
  logoFile.value = null
  logoPreview.value = ''
  profile.logo = null
  removeLogo.value = true
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/company-profile/current/')
    Object.assign(profile, blank(), data, {
      service_areas: data.service_areas || [],
      accreditations: data.accreditations || [],
    })
  } catch (e) {
    if (e.response?.status !== 404) {
      notify(e.response?.data?.detail || 'Failed to load profile', 'error')
    }
    Object.assign(profile, blank())
  } finally {
    logoFile.value = null
    logoPreview.value = ''
    removeLogo.value = false
    loading.value = false
  }
}

async function save() {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) {
    notify('Please complete required fields', 'warning')
    return
  }
  saving.value = true

  const fd = new FormData()
  const fields = ['legal_name', 'registration_number', 'contact_email',
    'contact_phone', 'address', 'city', 'country', 'license_url', 'about']
  for (const k of fields) fd.append(k, profile[k] ?? '')
  fd.append('service_areas', JSON.stringify(profile.service_areas || []))
  fd.append('accreditations', JSON.stringify(profile.accreditations || []))
  if (logoFile.value) {
    const f = Array.isArray(logoFile.value) ? logoFile.value[0] : logoFile.value
    if (f) fd.append('logo', f)
  } else if (removeLogo.value) {
    fd.append('logo', '')
  }

  try {
    const cfg = { headers: { 'Content-Type': 'multipart/form-data' } }
    let data
    if (profile.id) {
      ({ data } = await $api.patch(`/homecare/company-profile/${profile.id}/`, fd, cfg))
    } else {
      ({ data } = await $api.post('/homecare/company-profile/', fd, cfg))
    }
    Object.assign(profile, blank(), data, {
      service_areas: data.service_areas || [],
      accreditations: data.accreditations || [],
    })
    logoFile.value = null
    logoPreview.value = ''
    removeLogo.value = false
    notify('Profile saved')
  } catch (e) {
    const detail = e.response?.data
    const msg = typeof detail === 'string' ? detail
      : detail?.detail || Object.values(detail || {}).flat().join(' ') || 'Save failed'
    notify(msg, 'error')
  } finally {
    saving.value = false
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
