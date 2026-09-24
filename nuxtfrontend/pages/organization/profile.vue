<template>
  <v-container fluid class="pa-3 pa-md-5" style="max-width: 1100px;">
    <PageHeader
      title="Organization Profile"
      subtitle="View and update your organization's details"
      icon="mdi-office-building"
      color="teal"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">
          Reload
        </v-btn>
        <v-btn
          v-if="canEdit"
          color="primary" rounded="lg" class="text-none"
          prepend-icon="mdi-content-save" :loading="saving" :disabled="!dirty" @click="save"
        >
          Save Changes
        </v-btn>
      </template>
    </PageHeader>

    <v-alert
      v-if="!canEdit"
      type="info" variant="tonal" density="compact" rounded="lg" class="mb-4"
    >
      You have view-only access. Contact an organization admin to make changes.
    </v-alert>

    <v-alert
      v-if="errorMsg"
      type="error" variant="tonal" density="compact" rounded="lg" class="mb-4"
    >{{ errorMsg }}</v-alert>

    <v-row dense>
      <!-- ── Brand / identity card ── -->
      <v-col cols="12" md="4">
        <v-card rounded="xl" variant="outlined" class="h-100 overflow-hidden">
          <div class="brand-hero d-flex flex-column align-center justify-center pa-6 pt-8">
            <div class="logo-wrap mb-4">
              <v-img v-if="logoUrl" :src="logoUrl" cover class="rounded-xl" />
              <div v-else class="logo-placeholder d-flex align-center justify-center rounded-xl">
                <v-icon size="42" color="white">{{ typeMeta.icon }}</v-icon>
              </div>
              <v-btn
                v-if="canEdit"
                fab size="small" color="primary" class="logo-edit"
                @click="logoInput?.click()"
              >
                <v-icon size="16">mdi-camera</v-icon>
              </v-btn>
            </div>
            <input ref="logoInput" type="file" accept="image/*" class="d-none" @change="onLogoSelected" />
            <div class="text-h6 font-weight-bold text-white text-center">{{ org.name }}</div>
            <v-chip size="small" class="mt-2 text-white" style="background: rgba(255,255,255,0.18);" prepend-icon="mdi-account-group">
              {{ typeMeta.title }}
            </v-chip>
          </div>
          <v-divider />
          <v-list density="compact" class="py-0">
            <v-list-item prepend-icon="mdi-link-variant" title="Slug" :subtitle="org.slug || '—'" />
            <v-list-item prepend-icon="mdi-database" title="Data schema" :subtitle="org.schema_name || '—'" />
            <v-list-item prepend-icon="mdi-calendar-month" title="Member since" :subtitle="formatDate(org.created_at)" />
            <v-list-item prepend-icon="mdi-web" :subtitle="primaryDomain || '—'" title="Primary domain" />
          </v-list>
          <v-divider />
          <v-card-text v-if="canEdit" class="text-center">
            <v-btn
              size="small" variant="text" color="primary" class="text-none"
              prepend-icon="mdi-image-edit" :loading="uploading" :disabled="!logoFile" @click="uploadLogo"
            >
              Upload Logo
            </v-btn>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- ── Details form ── -->
      <v-col cols="12" md="8">
        <v-card rounded="xl" variant="outlined" class="mb-4 overflow-hidden">
          <div class="section-header">
            <v-icon icon="mdi-card-account-details-outline" size="20" class="mr-2" />
            <span class="text-subtitle-2 font-weight-bold">Basic Information</span>
          </div>
          <div class="pa-5">
            <v-row dense>
              <v-col cols="12" sm="8">
                <v-text-field
                  v-model="org.name" label="Organization Name *"
                  :rules="req" :disabled="!canEdit"
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-office-building" hide-details="auto" class="mb-3"
                />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field
                  v-model="org.city" label="City" :disabled="!canEdit"
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-city" hide-details="auto" class="mb-3"
                />
              </v-col>
              <v-col cols="12" sm="4">
                <v-autocomplete
                  v-model="org.country" :items="countryList" label="Country"
                  :disabled="!canEdit" auto-select-first
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-earth" hide-details="auto" class="mb-3"
                />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field
                  v-model="org.phone" label="Phone" type="tel" :disabled="!canEdit"
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-phone" hide-details="auto" class="mb-3"
                />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field
                  v-model="org.email" label="Email" type="email" :disabled="!canEdit"
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-email" hide-details="auto" class="mb-3"
                />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model="org.website" label="Website" placeholder="https://" :disabled="!canEdit"
                  variant="outlined" density="comfortable" rounded="lg"
                  prepend-inner-icon="mdi-link" hide-details="auto" class="mb-3"
                />
              </v-col>
            </v-row>
          </div>
        </v-card>

        <v-card rounded="xl" variant="outlined" class="overflow-hidden">
          <div class="section-header">
            <v-icon icon="mdi-map-marker-radius-outline" size="20" class="mr-2" />
            <span class="text-subtitle-2 font-weight-bold">Location</span>
            <v-spacer />
            <v-tooltip v-if="canEdit" text="Pick on map" location="top">
              <template #activator="{ props: tp }">
                <v-btn v-bind="tp" icon="mdi-map-search" variant="text" size="small" color="primary" @click="openMapPicker" />
              </template>
            </v-tooltip>
            <v-tooltip v-if="canEdit" text="Use my current location" location="top">
              <template #activator="{ props: tp }">
                <v-btn v-bind="tp" icon="mdi-crosshairs-gps" variant="text" size="small" color="indigo" :loading="locating" @click="useMyLocation" />
              </template>
            </v-tooltip>
          </div>
          <div class="pa-5">
            <v-textarea
              v-model="org.address" label="Address" rows="2" auto-grow
              :disabled="!canEdit" hide-details="auto"
              variant="outlined" density="comfortable" rounded="lg"
              prepend-inner-icon="mdi-map-marker" class="mb-3"
            />
            <v-text-field
              v-model="org.place_name" label="Place / Landmark name" :disabled="!canEdit"
              variant="outlined" density="comfortable" rounded="lg"
              prepend-inner-icon="mdi-tag-outline" hide-details="auto" class="mb-2"
            />
            <div v-if="org.latitude != null && org.longitude != null" class="d-flex flex-wrap ga-2">
              <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-map-marker">
                {{ Number(org.latitude).toFixed(6) }}, {{ Number(org.longitude).toFixed(6) }}
              </v-chip>
              <v-btn v-if="canEdit" size="x-small" variant="text" color="error" prepend-icon="mdi-close"
                     @click="org.latitude = null; org.longitude = null; org.place_name = ''">
                Clear
              </v-btn>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="onMapPicked" />

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useGoogleMaps } from '~/composables/useGoogleMaps'
import { formatDate } from '~/utils/format'

const auth = useAuthStore()
const { $api } = useNuxtApp()

const ADMIN_EDIT_ROLES = new Set([
  'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
  'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin',
  'inventory_admin', 'admin',
])

const canEdit = computed(() => ADMIN_EDIT_ROLES.has(auth.role))

const TYPES = {
  hospital: { title: 'Hospital', icon: 'mdi-hospital-building', color: '#0EA5E9' },
  pharmacy: { title: 'Pharmacy', icon: 'mdi-medical-bag', color: '#10B981' },
  lab: { title: 'Laboratory', icon: 'mdi-flask', color: '#F59E0B' },
  homecare: { title: 'Homecare', icon: 'mdi-home-heart', color: '#EC4899' },
  radiology_center: { title: 'Radiology Center', icon: 'mdi-radiology', color: '#8B5CF6' },
  clinic: { title: 'Clinic', icon: 'mdi-doctor', color: '#2563EB' },
  inventory: { title: 'Inventory / Warehouse', icon: 'mdi-warehouse', color: '#14B8A6' },
}

const org = reactive({
  name: '', address: '', city: '', country: 'Kenya',
  latitude: null, longitude: null, place_name: '',
  phone: '', email: '', website: '',
  slug: '', schema_name: '', type: '', created_at: null,
  logo: null, domains: [],
})
let snapshot = ''

const loading = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const logoInput = ref(null)
const logoFile = ref(null)
const uploading = ref(false)

const typeMeta = computed(() => TYPES[org.type] || { title: org.type || 'Organization', icon: 'mdi-office-building', color: '#14B8A6' })
const logoUrl = computed(() => org.logo || null)
const primaryDomain = computed(() => (org.domains || []).find(d => d.is_primary)?.domain || (org.domains || [])[0]?.domain || '')

const dirty = computed(() => JSON.stringify({
  name: org.name, address: org.address, city: org.city, country: org.country,
  latitude: org.latitude, longitude: org.longitude, place_name: org.place_name,
  phone: org.phone, email: org.email, website: org.website,
}) !== snapshot)

const req = [(v) => (!!v && String(v).trim().length > 0) || 'Required']

const countryList = [
  'Kenya', 'Uganda', 'Tanzania', 'Rwanda', 'Burundi', 'Ethiopia', 'Somalia',
  'South Sudan', 'DRC', 'Zambia', 'Zimbabwe', 'Nigeria', 'Ghana', 'South Africa',
  'United Arab Emirates', 'United Kingdom', 'United States',
]

// ── Location helpers (Places + map picker) ──────────────────────────────
const { reverseGeocode } = useGoogleMaps()
const locating = ref(false)
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})

function round6(n) { if (n == null || n === '' || isNaN(Number(n))) return null; return Math.round(Number(n) * 1e6) / 1e6 }

function useMyLocation() {
  if (!navigator.geolocation) return
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        org.address = addr
      } finally {
        org.latitude = round6(coords.latitude)
        org.longitude = round6(coords.longitude)
        locating.value = false
      }
    },
    () => { locating.value = false },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

function onMapPicked(p) {
  org.latitude = round6(p.lat)
  org.longitude = round6(p.lng)
  if (p.address) org.address = p.address
  if (p.place_name) org.place_name = p.place_name
}

function openMapPicker() {
  mapPickerInitial.value = {
    lat: org.latitude, lng: org.longitude,
    address: org.address, place_name: org.place_name,
  }
  mapPickerOpen.value = true
}

// ── Data ────────────────────────────────────────────────────────────────
function takeSnapshot() {
  snapshot = JSON.stringify({
    name: org.name, address: org.address, city: org.city, country: org.country,
    latitude: org.latitude, longitude: org.longitude, place_name: org.place_name,
    phone: org.phone, email: org.email, website: org.website,
  })
}

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const { data } = await $api.get('/tenants/me/')
    Object.keys(org).forEach(k => {
      if (data[k] !== undefined && data[k] !== null) org[k] = data[k]
    })
    takeSnapshot()
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to load organization profile.'
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  errorMsg.value = ''
  try {
    const { data } = await $api.patch('/tenants/me/', {
      name: (org.name || '').trim(),
      address: (org.address || '').trim(),
      city: (org.city || '').trim(),
      country: (org.country || '').trim(),
      latitude: org.latitude,
      longitude: org.longitude,
      place_name: (org.place_name || '').trim(),
      phone: (org.phone || '').trim(),
      email: (org.email || '').trim(),
      website: (org.website || '').trim(),
    })
    Object.assign(org, data)
    takeSnapshot()
    snack.color = 'success'
    snack.text = 'Organization profile updated.'
    snack.show = true
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to update organization profile.'
  } finally {
    saving.value = false
  }
}

function onLogoSelected(e) {
  const file = e?.target?.files?.[0]
  if (!file) return
  logoFile.value = file
  uploadLogo()
}

async function uploadLogo() {
  if (!logoFile.value) return
  uploading.value = true
  try {
    const fd = new FormData()
    fd.append('logo', logoFile.value)
    const { data } = await $api.post('/tenants/me/upload-logo/', fd)
    org.logo = data.logo
    logoFile.value = null
    snack.color = 'success'
    snack.text = 'Logo updated.'
    snack.show = true
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to upload logo.'
  } finally {
    uploading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.brand-hero {
  background: linear-gradient(135deg, #0f766e 0%, #115e59 55%, #134e4a 100%);
  min-height: 220px;
}
.logo-wrap {
  position: relative;
  width: 108px;
  height: 108px;
}
.logo-placeholder {
  width: 100%;
  height: 100%;
  background: rgba(255, 255, 255, 0.16);
}
.logo-edit {
  position: absolute;
  bottom: -8px;
  right: -8px;
}
.section-header {
  padding: 14px 20px;
  display: flex;
  align-items: center;
  background: linear-gradient(135deg, rgba(var(--v-theme-primary), 0.10), rgba(var(--v-theme-primary), 0.03));
  color: rgb(var(--v-theme-primary));
}
</style>
