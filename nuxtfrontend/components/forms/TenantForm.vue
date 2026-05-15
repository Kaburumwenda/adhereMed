<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader :title="isEdit ? 'Edit Tenant' : 'New Tenant'" icon="mdi-domain">
      <template #actions>
        <v-btn
          variant="text"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-arrow-left"
          to="/superadmin/tenants"
        >Back</v-btn>
      </template>
    </PageHeader>

    <!-- Stepper indicators (create only) -->
    <div v-if="!isEdit" class="d-flex align-center justify-center mb-6 ga-2">
      <div
        v-for="(s, i) in steps"
        :key="i"
        class="d-flex align-center ga-2"
      >
        <v-avatar
          :color="step > i ? 'success' : step === i ? 'primary' : 'grey-lighten-2'"
          size="32"
        >
          <v-icon v-if="step > i" icon="mdi-check" size="16" color="white" />
          <span v-else class="text-caption font-weight-bold" :class="step === i ? 'text-white' : 'text-grey'">{{ i + 1 }}</span>
        </v-avatar>
        <span class="text-body-2" :class="step === i ? 'font-weight-bold' : 'text-medium-emphasis'">{{ s }}</span>
        <v-icon v-if="i < steps.length - 1" icon="mdi-chevron-right" size="18" class="text-grey-lighten-1 mx-1" />
      </div>
    </div>

    <v-form ref="formRef" @submit.prevent="onSubmit">

      <!-- ── STEP 0: Tenant Type (create only) ── -->
      <v-card v-if="!isEdit && step === 0" rounded="xl" variant="flat" class="mb-4 pa-6" color="transparent">
        <div class="text-center mb-5">
          <div class="text-h6 font-weight-bold mb-1">What type of facility?</div>
          <div class="text-body-2 text-medium-emphasis">Select the tenant type to get started</div>
        </div>
        <v-row justify="center">
          <v-col
            v-for="opt in typeOptions"
            :key="opt.value"
            cols="6"
            sm="4"
            md="4"
          >
            <v-card
              rounded="xl"
              :variant="form.type === opt.value ? 'flat' : 'outlined'"
              :color="form.type === opt.value ? opt.color : undefined"
              class="text-center pa-5 cursor-pointer type-card"
              :class="{ 'type-card--active': form.type === opt.value }"
              :disabled="isEdit"
              @click="form.type = opt.value"
            >
              <v-avatar :color="form.type === opt.value ? 'white' : opt.color" size="56" class="mb-3">
                <v-icon :icon="opt.icon" size="28" :color="form.type === opt.value ? opt.color : 'white'" />
              </v-avatar>
              <div class="text-subtitle-2 font-weight-bold">{{ opt.title }}</div>
              <div class="text-caption" :class="form.type === opt.value ? 'text-white' : 'text-medium-emphasis'">{{ opt.desc }}</div>
            </v-card>
          </v-col>
        </v-row>
        <div class="d-flex justify-center mt-6">
          <v-btn
            color="primary"
            rounded="lg"
            size="large"
            class="text-none px-10"
            append-icon="mdi-arrow-right"
            @click="step = 1"
          >Continue</v-btn>
        </div>
      </v-card>

      <!-- ── STEP 1 / Edit: Tenant Information ── -->
      <v-card v-if="isEdit || step === 1" rounded="xl" variant="outlined" class="mb-4 overflow-hidden">
        <div class="section-header primary-header">
          <v-icon icon="mdi-office-building" size="20" class="mr-2" />
          <span class="text-subtitle-2 font-weight-bold">Tenant Information</span>
          <v-spacer />
          <v-chip v-if="!isEdit" size="small" variant="tonal" :color="selectedType?.color" class="text-none">
            <v-icon :icon="selectedType?.icon" size="14" start />
            {{ selectedType?.title }}
          </v-chip>
        </div>
        <div class="pa-5">
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model="form.name"
                label="Facility Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-hospital-building"
                @update:model-value="onNameChange"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.slug"
                label="Slug *"
                hint="e.g. city_hospital"
                persistent-hint
                :rules="req"
                :disabled="isEdit"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-link-variant"
                @update:model-value="onSlugInput"
              />
            </v-col>
            <v-col v-if="!isEdit" cols="12" sm="6">
              <v-text-field
                v-model="form.domain"
                label="Domain *"
                hint="e.g. city_hospital.adheremed.com"
                persistent-hint
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-web"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.city"
                label="City"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-city"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-autocomplete
                v-model="form.country"
                :items="countryList"
                label="Country *"
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-earth"
                auto-select-first
              />
            </v-col>

            <!-- Address: Google Places + Map picker -->
            <v-col cols="12">
              <v-autocomplete
                v-model="addressSelection"
                v-model:search="addressQuery"
                :items="addressPredictions"
                :loading="loadingPlaces"
                item-title="description"
                item-value="place_id"
                label="Search address (Google Places)"
                placeholder="Start typing an address…"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-map-marker-plus"
                return-object
                hide-no-data
                hide-details="auto"
                no-filter
                clearable
                @update:search="onAddressSearch"
                @update:model-value="onAddressPicked"
              >
                <template #append-inner>
                  <v-tooltip text="Pick on map" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-map-search" variant="text" size="small" color="primary"
                             @click.stop="openMapPicker" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Use my current location" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-crosshairs-gps" variant="text" size="small" color="indigo"
                             :loading="locating" @click.stop="useMyLocation" />
                    </template>
                  </v-tooltip>
                </template>
                <template #item="{ props: ip, item }">
                  <v-list-item v-bind="ip" prepend-icon="mdi-map-marker-outline">
                    <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                      {{ item.raw.structured_formatting.secondary_text }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </template>
              </v-autocomplete>
              <v-textarea
                v-model="form.address"
                label="Address (editable)"
                rows="2"
                auto-grow
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-pencil"
                hide-details="auto"
                hint="Pick from suggestions, the map, or type manually"
                persistent-hint
                class="mt-2"
              />
              <div v-if="form.latitude != null && form.longitude != null" class="d-flex flex-wrap ga-2 mt-2">
                <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-map-marker">
                  {{ Number(form.latitude).toFixed(6) }}, {{ Number(form.longitude).toFixed(6) }}
                </v-chip>
                <v-chip v-if="form.place_name" size="small" variant="tonal" color="success" prepend-icon="mdi-tag">
                  {{ form.place_name }}
                </v-chip>
                <v-btn size="x-small" variant="text" color="error" prepend-icon="mdi-close"
                       @click="form.latitude = null; form.longitude = null; form.place_name = ''">Clear</v-btn>
              </div>
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field
                v-model="form.phone"
                label="Phone"
                type="tel"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-phone"
              />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field
                v-model="form.email"
                label="Email"
                type="email"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-email"
              />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field
                v-model="form.website"
                label="Website"
                placeholder="https://"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-link"
              />
            </v-col>
            <v-col v-if="isEdit" cols="12">
              <v-switch
                v-model="form.is_active"
                label="Active"
                color="primary"
                inset
                hide-details
              />
            </v-col>
          </v-row>
        </div>
      </v-card>

      <!-- ── Admin User (create only, same step) ── -->
      <v-card v-if="!isEdit && step === 1" rounded="xl" variant="outlined" class="mb-4 overflow-hidden">
        <div class="section-header secondary-header">
          <v-icon icon="mdi-shield-account" size="20" class="mr-2" />
          <span class="text-subtitle-2 font-weight-bold">Admin User</span>
        </div>
        <div class="pa-5">
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.admin_first_name"
                label="First Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-account"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.admin_last_name"
                label="Last Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-account-outline"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="form.admin_email"
                label="Admin Email *"
                type="email"
                :rules="req"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-email-outline"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="form.admin_password"
                label="Password (leave blank to auto-generate)"
                :type="showPassword ? 'text' : 'password'"
                :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                :rules="passwordRules"
                prepend-inner-icon="mdi-lock-outline"
                @click:append-inner="showPassword = !showPassword"
              />
            </v-col>
          </v-row>
        </div>
      </v-card>

      <v-alert
        v-if="topError"
        type="error"
        variant="tonal"
        density="compact"
        rounded="lg"
        class="mb-4"
      >{{ topError }}</v-alert>

      <!-- Action buttons -->
      <div v-if="isEdit || step === 1" class="d-flex justify-space-between ga-2">
        <v-btn
          v-if="!isEdit"
          variant="text"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-arrow-left"
          @click="step = 0"
        >Back</v-btn>
        <v-spacer />
        <v-btn variant="text" rounded="lg" class="text-none" to="/superadmin/tenants">Cancel</v-btn>
        <v-btn
          type="submit"
          color="primary"
          rounded="lg"
          size="large"
          class="text-none px-8"
          :loading="saving"
          prepend-icon="mdi-content-save"
        >{{ isEdit ? 'Save Changes' : 'Create Tenant' }}</v-btn>
      </div>
    </v-form>

    <!-- Created confirmation -->
    <v-dialog v-model="createdDialog.show" max-width="480" persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="text-center pa-6 pb-2" style="background: linear-gradient(135deg, rgba(var(--v-theme-success), 0.12), rgba(var(--v-theme-success), 0.04));">
          <v-avatar color="success" size="56" class="mb-3">
            <v-icon icon="mdi-check-bold" size="28" color="white" />
          </v-avatar>
          <div class="text-h6 font-weight-bold">Tenant Created</div>
        </div>
        <v-card-text class="pa-5">
          <p class="mb-4 text-center"><strong>{{ createdDialog.name }}</strong> is ready to go.</p>
          <v-card rounded="lg" variant="tonal" color="info" class="pa-4 mb-3">
            <div class="text-subtitle-2 font-weight-bold mb-2">
              <v-icon icon="mdi-shield-key" size="16" class="mr-1" /> Admin credentials
            </div>
            <div class="d-flex align-center mb-1">
              <span class="text-body-2 text-medium-emphasis" style="min-width: 80px;">Email</span>
              <code class="text-body-2">{{ createdDialog.email }}</code>
            </div>
            <div class="d-flex align-center">
              <span class="text-body-2 text-medium-emphasis" style="min-width: 80px;">Password</span>
              <code class="text-body-2">{{ createdDialog.password }}</code>
            </div>
          </v-card>
          <v-alert type="warning" variant="tonal" density="compact" rounded="lg" class="text-caption">
            <v-icon icon="mdi-alert" size="14" class="mr-1" />
            Save these credentials — the password will not be shown again.
          </v-alert>
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" size="large" class="text-none px-8" @click="onDoneCreated">
            <v-icon icon="mdi-check" start /> Done
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="onMapPicked" />

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { useGoogleMaps } from '~/composables/useGoogleMaps'

const route = useRoute()
const router = useRouter()
const loadId = computed(() => route.params.id || null)
const isEdit = computed(() => !!loadId.value)

const r = useResource('/superadmin/tenants/')
const saving = computed(() => r.saving.value)

const step = ref(0)
const steps = ['Facility Type', 'Details & Admin']

const typeOptions = [
  { title: 'Hospital', value: 'hospital', icon: 'mdi-hospital-building', color: '#0EA5E9', desc: 'Full hospital management' },
  { title: 'Pharmacy', value: 'pharmacy', icon: 'mdi-pharmacy', color: '#10B981', desc: 'POS, inventory & dispensing' },
  { title: 'Lab', value: 'lab', icon: 'mdi-flask', color: '#F59E0B', desc: 'Lab orders & results' },
  { title: 'Radiology', value: 'radiology_center', icon: 'mdi-radiology', color: '#8B5CF6', desc: 'Imaging & reports' },
  { title: 'Homecare', value: 'homecare', icon: 'mdi-home-heart', color: '#EC4899', desc: 'In-home care services' }
]

const selectedType = computed(() => typeOptions.find(t => t.value === form.type))

const countryList = [
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola',
  'Antigua and Barbuda', 'Argentina', 'Armenia', 'Australia', 'Austria',
  'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados',
  'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan',
  'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei',
  'Bulgaria', 'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia',
  'Cameroon', 'Canada', 'Central African Republic', 'Chad', 'Chile',
  'China', 'Colombia', 'Comoros', 'Congo (Brazzaville)', 'Congo (DRC)',
  'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czech Republic',
  'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic', 'East Timor',
  'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea',
  'Estonia', 'Eswatini', 'Ethiopia', 'Fiji', 'Finland',
  'France', 'Gabon', 'Gambia', 'Georgia', 'Germany',
  'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea',
  'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras', 'Hungary',
  'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq',
  'Ireland', 'Israel', 'Italy', 'Ivory Coast', 'Jamaica',
  'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati',
  'Kosovo', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia',
  'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein',
  'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia',
  'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania',
  'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco',
  'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar',
  'Namibia', 'Nauru', 'Nepal', 'Netherlands', 'New Zealand',
  'Nicaragua', 'Niger', 'Nigeria', 'North Korea', 'North Macedonia',
  'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine',
  'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines',
  'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia',
  'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent and the Grenadines',
  'Samoa', 'San Marino', 'São Tomé and Príncipe', 'Saudi Arabia', 'Senegal',
  'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia',
  'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea',
  'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname',
  'Sweden', 'Switzerland', 'Syria', 'Taiwan', 'Tajikistan',
  'Tanzania', 'Thailand', 'Togo', 'Tonga', 'Trinidad and Tobago',
  'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda',
  'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay',
  'Uzbekistan', 'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam',
  'Yemen', 'Zambia', 'Zimbabwe'
]

const req = [(v) => (!!v && String(v).trim().length > 0) || 'Required']
const passwordRules = [
  (v) => !v || String(v).length >= 8 || 'Min 8 characters'
]

const form = reactive({
  name: '',
  slug: '',
  type: 'hospital',
  domain: '',
  city: '',
  country: 'Kenya',
  address: '',
  latitude: null,
  longitude: null,
  place_name: '',
  phone: '',
  email: '',
  website: '',
  is_active: true,
  // admin user (create only)
  admin_first_name: '',
  admin_last_name: '',
  admin_email: '',
  admin_password: ''
})

const formRef = ref(null)
const showPassword = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })
const createdDialog = reactive({ show: false, name: '', email: '', password: '' })

// ── Google Places + Map picker ──
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})
let _addrTimer = null

function round6(n) { if (n == null || n === '' || isNaN(Number(n))) return null; return Math.round(Number(n) * 1e6) / 1e6 }

function onAddressSearch(q) {
  if (_addrTimer) clearTimeout(_addrTimer)
  if (!q || q.length < 3) { addressPredictions.value = []; return }
  loadingPlaces.value = true
  _addrTimer = setTimeout(async () => {
    try { addressPredictions.value = await getPredictions(q, { country: 'ke' }) }
    catch { addressPredictions.value = [] }
    finally { loadingPlaces.value = false }
  }, 280)
}

async function onAddressPicked(pred) {
  if (!pred?.place_id) return
  try {
    const details = await getPlaceDetails(pred.place_id)
    form.address = details.address || pred.description
    form.latitude = round6(details.lat)
    form.longitude = round6(details.lng)
    form.place_name = details.name || (pred.structured_formatting?.main_text || '')
    addressQuery.value = form.address
  } catch {
    form.address = pred.description
  }
}

function useMyLocation() {
  if (!navigator.geolocation) return
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.address = addr
        form.latitude = round6(coords.latitude)
        form.longitude = round6(coords.longitude)
        addressQuery.value = addr
      } finally { locating.value = false }
    },
    () => { locating.value = false },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

function openMapPicker() {
  mapPickerInitial.value = {
    lat: form.latitude, lng: form.longitude,
    address: form.address, place_name: form.place_name,
  }
  mapPickerOpen.value = true
}

function onMapPicked(p) {
  form.latitude = round6(p.lat)
  form.longitude = round6(p.lng)
  if (p.address) { form.address = p.address; addressQuery.value = p.address }
  if (p.place_name) form.place_name = p.place_name
}

let slugTouched = false

function slugify(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
}

function onNameChange(v) {
  if (isEdit.value) return
  if (!slugTouched) {
    const slug = slugify(v)
    form.slug = slug
    form.domain = slug ? `${slug}.adheremed.com` : ''
  }
}

function onSlugInput() {
  if (!isEdit.value) slugTouched = true
}

onMounted(async () => {
  if (isEdit.value) {
    step.value = 1
    const data = await r.get(loadId.value)
    if (data) {
      Object.keys(form).forEach((k) => {
        if (data[k] !== undefined && data[k] !== null) form[k] = data[k]
      })
    }
  }
})

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return

  try {
    if (isEdit.value) {
      const payload = {
        name: form.name.trim(),
        address: (form.address || '').trim(),
        city: (form.city || '').trim(),
        country: (form.country || '').trim(),
        latitude: form.latitude,
        longitude: form.longitude,
        place_name: (form.place_name || '').trim(),
        phone: (form.phone || '').trim(),
        email: (form.email || '').trim(),
        website: (form.website || '').trim(),
        is_active: form.is_active
      }
      await r.update(loadId.value, payload)
      snack.text = 'Tenant updated'
      snack.color = 'success'
      snack.show = true
      router.push('/superadmin/tenants')
    } else {
      const payload = {
        name: form.name.trim(),
        slug: form.slug.trim(),
        type: form.type,
        domain: form.domain.trim(),
        address: (form.address || '').trim(),
        city: (form.city || '').trim(),
        country: (form.country || '').trim(),
        latitude: form.latitude,
        longitude: form.longitude,
        place_name: (form.place_name || '').trim(),
        phone: (form.phone || '').trim(),
        email: (form.email || '').trim(),
        website: (form.website || '').trim(),
        admin_email: form.admin_email.trim(),
        admin_first_name: form.admin_first_name.trim(),
        admin_last_name: form.admin_last_name.trim()
      }
      if (form.admin_password) payload.admin_password = form.admin_password
      const result = await r.create(payload)
      const tenantName = result?.tenant?.name || form.name.trim()
      const adminEmail = result?.admin_user?.email || form.admin_email.trim()
      const generated = result?.admin_user?.generated_password
      createdDialog.name = tenantName
      createdDialog.email = adminEmail
      createdDialog.password = form.admin_password || generated || '(auto-generated)'
      createdDialog.show = true
    }
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      const firstKey = Object.keys(data)[0]
      const firstVal = firstKey ? data[firstKey] : null
      const msg = Array.isArray(firstVal) ? firstVal[0] : firstVal
      topError.value = data.detail || (firstKey ? `${firstKey}: ${msg}` : 'Save failed.')
    } else {
      topError.value = r.error.value || 'Save failed.'
    }
  }
}

function onDoneCreated() {
  createdDialog.show = false
  router.push('/superadmin/tenants')
}
</script>

<style scoped>
.section-header {
  padding: 14px 20px;
  display: flex;
  align-items: center;
}
.primary-header {
  background: linear-gradient(135deg, rgba(var(--v-theme-primary), 0.10), rgba(var(--v-theme-primary), 0.03));
  color: rgb(var(--v-theme-primary));
}
.secondary-header {
  background: linear-gradient(135deg, rgba(var(--v-theme-secondary), 0.10), rgba(var(--v-theme-secondary), 0.03));
  color: rgb(var(--v-theme-secondary));
}
.type-card {
  transition: all 0.2s ease;
  border-width: 2px !important;
}
.type-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
}
.type-card--active {
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
}
</style>
