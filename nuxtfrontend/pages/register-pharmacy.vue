<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <!-- Background layers -->
      <div class="bg-base bg-fill" />
      <div class="bg-grid bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row justify="center" align="center" class="fill-height py-6">
          <v-col cols="12" sm="11" md="10" lg="8" xl="7">
            <v-btn
              variant="text"
              class="text-none nav-back mb-5"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/welcome')"
            >Back to home</v-btn>

            <div class="form-card pa-6 pa-md-8">
              <div class="text-center mb-7">
                <div class="brand-badge mx-auto mb-4" style="width:54px;height:54px;border-radius:16px;">
                  <v-icon size="26" color="white">mdi-medical-bag</v-icon>
                </div>
                <h2 class="form-title">Register your Pharmacy</h2>
                <p class="form-sub">
                  Create your pharmacy tenant on AdhereMed — POS, inventory, dispensing &amp; analytics
                </p>
              </div>

              <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" rounded="lg" class="mb-5">
                {{ errorMsg }}
              </v-alert>
              <v-alert v-if="success" type="success" variant="tonal" rounded="lg" class="mb-5">
                Pharmacy created successfully! Redirecting to sign in…
              </v-alert>

              <!-- Stepper -->
              <v-stepper v-if="!success" v-model="step" flat alt-labels class="elevation-0 stepper-dark">
                <v-stepper-header>
                  <v-stepper-item :value="1" title="Pharmacy Info" :complete="step > 1" color="#2f6dff" />
                  <v-divider />
                  <v-stepper-item :value="2" title="Location" :complete="step > 2" color="#2f6dff" />
                  <v-divider />
                  <v-stepper-item :value="3" title="Admin Account" :complete="step > 3" color="#2f6dff" />
                </v-stepper-header>

                <v-stepper-window>
                  <!-- Step 1: Pharmacy Info -->
                  <v-stepper-window-item :value="1">
                    <v-form ref="step1Ref">
                      <p class="step-overline mb-3">Pharmacy details</p>
                      <v-row dense>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.tenantName" label="Pharmacy name *" :rules="req"
                                        prepend-inner-icon="mdi-store" variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.pharmacyEmail" label="Pharmacy email"
                                        type="email" prepend-inner-icon="mdi-email-outline"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.pharmacyPhone" label="Pharmacy phone"
                                        prepend-inner-icon="mdi-phone-outline"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.website" label="Website"
                                        placeholder="https://"
                                        prepend-inner-icon="mdi-web"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.city" label="City / Town"
                                        prepend-inner-icon="mdi-city"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-autocomplete
                            v-model="form.country"
                            :items="countries"
                            item-title="name"
                            item-value="code"
                            label="Country *"
                            :rules="req"
                            prepend-inner-icon="mdi-earth"
                            variant="outlined"
                            density="comfortable"
                          />
                        </v-col>
                      </v-row>
                    </v-form>

                    <div class="d-flex justify-end mt-4">
                      <v-btn class="text-none btn-primary" variant="flat" rounded="lg"
                             append-icon="mdi-arrow-right" @click="goStep2">
                        Next: Location
                      </v-btn>
                    </div>
                  </v-stepper-window-item>

                  <!-- Step 2: Location -->
                  <v-stepper-window-item :value="2">
                    <p class="step-overline mb-3">Pharmacy address &amp; location</p>

                    <!-- Location method tabs -->
                    <v-btn-toggle v-model="locationMethod" mandatory color="#2f6dff" rounded="lg"
                                  density="comfortable" class="mb-4" variant="outlined">
                      <v-btn value="search" prepend-icon="mdi-magnify" class="text-none">Search Places</v-btn>
                      <v-btn value="map" prepend-icon="mdi-map" class="text-none">Pick on Map</v-btn>
                      <v-btn value="live" prepend-icon="mdi-crosshairs-gps" class="text-none">Use Live Location</v-btn>
                    </v-btn-toggle>

                    <!-- Search places -->
                    <div v-if="locationMethod === 'search'">
                      <v-text-field
                        v-model="placeQuery"
                        label="Search for your pharmacy address"
                        prepend-inner-icon="mdi-map-search"
                        variant="outlined"
                        density="comfortable"
                        :loading="searchingPlaces"
                        @update:model-value="debouncedPlaceSearch"
                        hide-details
                      />
                      <v-list v-if="placePredictions.length" density="compact" class="place-list mt-1 rounded-lg">
                        <v-list-item v-for="p in placePredictions" :key="p.place_id"
                                     @click="selectPlace(p)" class="cursor-pointer">
                          <template #prepend>
                            <v-icon size="small" color="#2f6dff">mdi-map-marker</v-icon>
                          </template>
                          <v-list-item-title class="text-body-2">{{ p.description }}</v-list-item-title>
                        </v-list-item>
                      </v-list>
                    </div>

                    <!-- Map picker -->
                    <div v-if="locationMethod === 'map'">
                      <div class="text-body-2 text-medium-emphasis mb-2">
                        Click on the map to set your pharmacy's location
                      </div>
                      <div ref="mapContainer" class="map-container rounded-lg border" />
                    </div>

                    <!-- Live location -->
                    <div v-if="locationMethod === 'live'">
                      <v-btn class="text-none btn-outline mb-3" variant="outlined" rounded="lg"
                             prepend-icon="mdi-crosshairs-gps" :loading="gettingLocation"
                             @click="useLiveLocation">
                        Detect my current location
                      </v-btn>
                      <v-alert v-if="locationError" type="warning" variant="tonal" density="compact" class="mb-2">
                        {{ locationError }}
                      </v-alert>
                    </div>

                    <!-- Selected location display -->
                    <v-card v-if="form.address" variant="tonal" color="#143ce1" rounded="lg" class="pa-3 mt-4 address-card">
                      <div class="d-flex align-center">
                        <v-icon color="#2f6dff" class="mr-2">mdi-check-circle</v-icon>
                        <div>
                          <div class="text-body-2 font-weight-medium">{{ form.address }}</div>
                          <div v-if="form.lat && form.lng" class="text-caption text-medium-emphasis">
                            {{ form.lat.toFixed(5) }}, {{ form.lng.toFixed(5) }}
                          </div>
                        </div>
                        <v-spacer />
                        <v-btn icon="mdi-close" size="small" variant="text" @click="clearLocation" />
                      </div>
                    </v-card>

                    <div class="d-flex justify-space-between mt-4">
                      <v-btn variant="text" rounded="lg" class="text-none step-back-btn" prepend-icon="mdi-arrow-left"
                             @click="step = 1">Back</v-btn>
                      <v-btn class="text-none btn-primary" variant="flat" rounded="lg"
                             append-icon="mdi-arrow-right" @click="step = 3">
                        Next: Admin Account
                      </v-btn>
                    </div>
                  </v-stepper-window-item>

                  <!-- Step 3: Admin Account -->
                  <v-stepper-window-item :value="3">
                    <v-form ref="step3Ref">
                      <p class="step-overline mb-3">Admin account</p>
                      <v-row dense>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.firstName" label="First name *" :rules="req"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.lastName" label="Last name *" :rules="req"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12">
                          <v-text-field v-model="form.email" label="Admin email *" type="email"
                                        prepend-inner-icon="mdi-email"
                                        :rules="[v => !!v || 'Required', v => /.+@.+\..+/.test(v) || 'Invalid email']"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.phone" label="Admin phone"
                                        prepend-inner-icon="mdi-phone"
                                        variant="outlined" density="comfortable" />
                        </v-col>
                        <v-col cols="12" md="6">
                          <v-text-field v-model="form.password" label="Password *"
                                        :type="show ? 'text' : 'password'"
                                        :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                                        prepend-inner-icon="mdi-lock"
                                        :rules="[v => !!v || 'Required', v => v.length >= 8 || 'Min 8 characters']"
                                        variant="outlined" density="comfortable"
                                        @click:append-inner="show = !show" />
                        </v-col>
                      </v-row>

                      <v-divider class="my-4 divider-dark" />
                      <p class="step-overline mb-2">Referral (optional)</p>
                      <v-text-field
                        v-model="form.referralCode"
                        label="Referral Code"
                        placeholder="Enter a referral code if you have one"
                        persistent-placeholder
                        :loading="validatingCode"
                        :messages="referralMsg"
                        :color="referralValid ? 'success' : undefined"
                        :error-messages="referralError"
                        prepend-inner-icon="mdi-gift"
                        variant="outlined"
                        density="comfortable"
                        @update:model-value="debouncedValidateCode"
                      />
                    </v-form>

                    <div class="d-flex justify-space-between mt-4">
                      <v-btn variant="text" rounded="lg" class="text-none step-back-btn" prepend-icon="mdi-arrow-left"
                             @click="step = 2">Back</v-btn>
                      <v-btn class="text-none btn-primary" variant="flat" size="large" rounded="lg"
                             prepend-icon="mdi-medical-bag" :loading="loading" @click="onSubmit">
                        Register Pharmacy
                      </v-btn>
                    </div>

                    <div class="text-center mt-6 text-body-2 form-footer-text">
                      Already registered?
                      <NuxtLink to="/login" class="form-link font-weight-medium">Sign in</NuxtLink>
                    </div>
                  </v-stepper-window-item>
                </v-stepper-window>
              </v-stepper>
            </div>
          </v-col>
        </v-row>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
definePageMeta({ layout: false })

import { useGoogleMaps } from '~/composables/useGoogleMaps'

const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()
const { load: loadMaps, getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()

const step1Ref = ref(null)
const step3Ref = ref(null)
const mapContainer = ref(null)
const loading = ref(false)
const errorMsg = ref('')
const success = ref(false)
const show = ref(false)
const step = ref(1)
const req = [v => !!v || 'Required']

const form = reactive({
  tenantName: '',
  pharmacyEmail: '',
  pharmacyPhone: '',
  website: '',
  city: '',
  country: 'KE',
  address: '',
  lat: null,
  lng: null,
  firstName: '',
  lastName: '',
  email: '',
  phone: '',
  password: '',
  referralCode: '',
})

// ── Location ────────────────────────────────────────────────────────────────────
const locationMethod = ref('search')
const placeQuery = ref('')
const placePredictions = ref([])
const searchingPlaces = ref(false)
const gettingLocation = ref(false)
const locationError = ref('')
let placeTimer = null
let map = null
let marker = null

function debouncedPlaceSearch() {
  clearTimeout(placeTimer)
  placePredictions.value = []
  if (!placeQuery.value || placeQuery.value.length < 3) return
  placeTimer = setTimeout(async () => {
    searchingPlaces.value = true
    try {
      placePredictions.value = await getPredictions(placeQuery.value, { types: ['establishment', 'geocode'] })
    } catch { /* ignore */ }
    finally { searchingPlaces.value = false }
  }, 400)
}

async function selectPlace(prediction) {
  placePredictions.value = []
  placeQuery.value = prediction.description
  try {
    const details = await getPlaceDetails(prediction.place_id)
    form.address = details.address || prediction.description
    form.lat = details.lat
    form.lng = details.lng
  } catch {
    form.address = prediction.description
  }
}

function clearLocation() {
  form.address = ''
  form.lat = null
  form.lng = null
  placeQuery.value = ''
}

async function useLiveLocation() {
  locationError.value = ''
  gettingLocation.value = true
  if (!navigator.geolocation) {
    locationError.value = 'Geolocation is not supported by your browser.'
    gettingLocation.value = false
    return
  }
  navigator.geolocation.getCurrentPosition(
    async (pos) => {
      form.lat = pos.coords.latitude
      form.lng = pos.coords.longitude
      try {
        form.address = await reverseGeocode(form.lat, form.lng)
      } catch {
        form.address = `${form.lat.toFixed(5)}, ${form.lng.toFixed(5)}`
      }
      gettingLocation.value = false
    },
    (err) => {
      locationError.value = err.message || 'Failed to get location. Please allow location access.'
      gettingLocation.value = false
    },
    { enableHighAccuracy: true, timeout: 15000 }
  )
}

// Map initialization
watch(locationMethod, async (val) => {
  if (val === 'map') {
    await nextTick()
    initMap()
  }
})

async function initMap() {
  if (!mapContainer.value) return
  try {
    const google = await loadMaps()
    const center = form.lat && form.lng
      ? { lat: form.lat, lng: form.lng }
      : { lat: -1.2921, lng: 36.8219 } // Nairobi default
    map = new google.maps.Map(mapContainer.value, {
      center,
      zoom: 13,
      disableDefaultUI: true,
      zoomControl: true,
      mapTypeControl: false,
      streetViewControl: false,
    })
    if (form.lat && form.lng) {
      marker = new google.maps.Marker({ position: center, map })
    }
    map.addListener('click', async (e) => {
      const lat = e.latLng.lat()
      const lng = e.latLng.lng()
      form.lat = lat
      form.lng = lng
      if (marker) marker.setMap(null)
      marker = new google.maps.Marker({ position: { lat, lng }, map })
      try {
        form.address = await reverseGeocode(lat, lng)
      } catch {
        form.address = `${lat.toFixed(5)}, ${lng.toFixed(5)}`
      }
    })
  } catch { /* Maps failed to load */ }
}

// ── Step navigation ─────────────────────────────────────────────────────────────
async function goStep2() {
  if (step1Ref.value) {
    const { valid } = await step1Ref.value.validate()
    if (!valid) return
  }
  step.value = 2
}

// ── Referral code ───────────────────────────────────────────────────────────────
const validatingCode = ref(false)
const referralValid = ref(false)
const referralMsg = ref('')
const referralError = ref('')
let validateTimer = null

function debouncedValidateCode() {
  referralValid.value = false
  referralMsg.value = ''
  referralError.value = ''
  clearTimeout(validateTimer)
  const code = (form.referralCode || '').trim()
  if (!code) return
  if (code.length < 4) return
  validateTimer = setTimeout(() => validateReferralCode(code), 500)
}

async function validateReferralCode(code) {
  validatingCode.value = true
  try {
    const { data } = await $api.get(`/usage-billing/referral/validate/${code.toUpperCase()}/`)
    if (data.valid) {
      referralValid.value = true
      referralMsg.value = `Referred by: ${data.referrer_name}`
    } else {
      referralError.value = 'Invalid referral code'
    }
  } catch {
    referralError.value = 'Could not validate code'
  } finally {
    validatingCode.value = false
  }
}

// Pre-fill referral code from URL query param (?ref=CODE)
onMounted(() => {
  const refCode = route.query.ref
  if (refCode) {
    form.referralCode = String(refCode).toUpperCase()
    validateReferralCode(form.referralCode)
  }
})

// ── Submit ──────────────────────────────────────────────────────────────────────
async function onSubmit() {
  errorMsg.value = ''
  if (step3Ref.value) {
    const { valid } = await step3Ref.value.validate()
    if (!valid) return
  }
  loading.value = true
  try {
    // Generate slug and domain from pharmacy name
    const slug = form.tenantName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 50)
    const domain = `${slug}.adheremed.com`

    await $api.post('/tenants/register/', {
      name: form.tenantName,
      type: 'pharmacy',
      slug,
      domain,
      email: form.pharmacyEmail,
      phone: form.pharmacyPhone,
      address: form.address,
      city: form.city,
      country: form.country,
      admin_email: form.email,
      admin_password: form.password,
      admin_first_name: form.firstName,
      admin_last_name: form.lastName,
      referral_code: (form.referralCode || '').trim().toUpperCase(),
    }, {
      timeout: 180000,
    })
    success.value = true
    setTimeout(() => router.push('/login'), 1500)
  } catch (e) {
    const d = e?.response?.data
    if (d && typeof d === 'object' && !d.detail) {
      // Format field errors
      const msgs = Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`)
      errorMsg.value = msgs.join(' · ')
    } else {
      errorMsg.value = d?.detail || d?.message || 'Registration failed.'
    }
  } finally {
    loading.value = false
  }
}

// ── Countries list ──────────────────────────────────────────────────────────────
const countries = [
  { name: 'Kenya', code: 'KE' },
  { name: 'Afghanistan', code: 'AF' },
  { name: 'Albania', code: 'AL' },
  { name: 'Algeria', code: 'DZ' },
  { name: 'Andorra', code: 'AD' },
  { name: 'Angola', code: 'AO' },
  { name: 'Antigua and Barbuda', code: 'AG' },
  { name: 'Argentina', code: 'AR' },
  { name: 'Armenia', code: 'AM' },
  { name: 'Australia', code: 'AU' },
  { name: 'Austria', code: 'AT' },
  { name: 'Azerbaijan', code: 'AZ' },
  { name: 'Bahamas', code: 'BS' },
  { name: 'Bahrain', code: 'BH' },
  { name: 'Bangladesh', code: 'BD' },
  { name: 'Barbados', code: 'BB' },
  { name: 'Belarus', code: 'BY' },
  { name: 'Belgium', code: 'BE' },
  { name: 'Belize', code: 'BZ' },
  { name: 'Benin', code: 'BJ' },
  { name: 'Bhutan', code: 'BT' },
  { name: 'Bolivia', code: 'BO' },
  { name: 'Bosnia and Herzegovina', code: 'BA' },
  { name: 'Botswana', code: 'BW' },
  { name: 'Brazil', code: 'BR' },
  { name: 'Brunei', code: 'BN' },
  { name: 'Bulgaria', code: 'BG' },
  { name: 'Burkina Faso', code: 'BF' },
  { name: 'Burundi', code: 'BI' },
  { name: 'Cabo Verde', code: 'CV' },
  { name: 'Cambodia', code: 'KH' },
  { name: 'Cameroon', code: 'CM' },
  { name: 'Canada', code: 'CA' },
  { name: 'Central African Republic', code: 'CF' },
  { name: 'Chad', code: 'TD' },
  { name: 'Chile', code: 'CL' },
  { name: 'China', code: 'CN' },
  { name: 'Colombia', code: 'CO' },
  { name: 'Comoros', code: 'KM' },
  { name: 'Congo (DRC)', code: 'CD' },
  { name: 'Congo (Republic)', code: 'CG' },
  { name: 'Costa Rica', code: 'CR' },
  { name: "Côte d'Ivoire", code: 'CI' },
  { name: 'Croatia', code: 'HR' },
  { name: 'Cuba', code: 'CU' },
  { name: 'Cyprus', code: 'CY' },
  { name: 'Czech Republic', code: 'CZ' },
  { name: 'Denmark', code: 'DK' },
  { name: 'Djibouti', code: 'DJ' },
  { name: 'Dominica', code: 'DM' },
  { name: 'Dominican Republic', code: 'DO' },
  { name: 'Ecuador', code: 'EC' },
  { name: 'Egypt', code: 'EG' },
  { name: 'El Salvador', code: 'SV' },
  { name: 'Equatorial Guinea', code: 'GQ' },
  { name: 'Eritrea', code: 'ER' },
  { name: 'Estonia', code: 'EE' },
  { name: 'Eswatini', code: 'SZ' },
  { name: 'Ethiopia', code: 'ET' },
  { name: 'Fiji', code: 'FJ' },
  { name: 'Finland', code: 'FI' },
  { name: 'France', code: 'FR' },
  { name: 'Gabon', code: 'GA' },
  { name: 'Gambia', code: 'GM' },
  { name: 'Georgia', code: 'GE' },
  { name: 'Germany', code: 'DE' },
  { name: 'Ghana', code: 'GH' },
  { name: 'Greece', code: 'GR' },
  { name: 'Grenada', code: 'GD' },
  { name: 'Guatemala', code: 'GT' },
  { name: 'Guinea', code: 'GN' },
  { name: 'Guinea-Bissau', code: 'GW' },
  { name: 'Guyana', code: 'GY' },
  { name: 'Haiti', code: 'HT' },
  { name: 'Honduras', code: 'HN' },
  { name: 'Hungary', code: 'HU' },
  { name: 'Iceland', code: 'IS' },
  { name: 'India', code: 'IN' },
  { name: 'Indonesia', code: 'ID' },
  { name: 'Iran', code: 'IR' },
  { name: 'Iraq', code: 'IQ' },
  { name: 'Ireland', code: 'IE' },
  { name: 'Israel', code: 'IL' },
  { name: 'Italy', code: 'IT' },
  { name: 'Jamaica', code: 'JM' },
  { name: 'Japan', code: 'JP' },
  { name: 'Jordan', code: 'JO' },
  { name: 'Kazakhstan', code: 'KZ' },
  { name: 'Kiribati', code: 'KI' },
  { name: 'Kuwait', code: 'KW' },
  { name: 'Kyrgyzstan', code: 'KG' },
  { name: 'Laos', code: 'LA' },
  { name: 'Latvia', code: 'LV' },
  { name: 'Lebanon', code: 'LB' },
  { name: 'Lesotho', code: 'LS' },
  { name: 'Liberia', code: 'LR' },
  { name: 'Libya', code: 'LY' },
  { name: 'Liechtenstein', code: 'LI' },
  { name: 'Lithuania', code: 'LT' },
  { name: 'Luxembourg', code: 'LU' },
  { name: 'Madagascar', code: 'MG' },
  { name: 'Malawi', code: 'MW' },
  { name: 'Malaysia', code: 'MY' },
  { name: 'Maldives', code: 'MV' },
  { name: 'Mali', code: 'ML' },
  { name: 'Malta', code: 'MT' },
  { name: 'Marshall Islands', code: 'MH' },
  { name: 'Mauritania', code: 'MR' },
  { name: 'Mauritius', code: 'MU' },
  { name: 'Mexico', code: 'MX' },
  { name: 'Micronesia', code: 'FM' },
  { name: 'Moldova', code: 'MD' },
  { name: 'Monaco', code: 'MC' },
  { name: 'Mongolia', code: 'MN' },
  { name: 'Montenegro', code: 'ME' },
  { name: 'Morocco', code: 'MA' },
  { name: 'Mozambique', code: 'MZ' },
  { name: 'Myanmar', code: 'MM' },
  { name: 'Namibia', code: 'NA' },
  { name: 'Nauru', code: 'NR' },
  { name: 'Nepal', code: 'NP' },
  { name: 'Netherlands', code: 'NL' },
  { name: 'New Zealand', code: 'NZ' },
  { name: 'Nicaragua', code: 'NI' },
  { name: 'Niger', code: 'NE' },
  { name: 'Nigeria', code: 'NG' },
  { name: 'North Korea', code: 'KP' },
  { name: 'North Macedonia', code: 'MK' },
  { name: 'Norway', code: 'NO' },
  { name: 'Oman', code: 'OM' },
  { name: 'Pakistan', code: 'PK' },
  { name: 'Palau', code: 'PW' },
  { name: 'Palestine', code: 'PS' },
  { name: 'Panama', code: 'PA' },
  { name: 'Papua New Guinea', code: 'PG' },
  { name: 'Paraguay', code: 'PY' },
  { name: 'Peru', code: 'PE' },
  { name: 'Philippines', code: 'PH' },
  { name: 'Poland', code: 'PL' },
  { name: 'Portugal', code: 'PT' },
  { name: 'Qatar', code: 'QA' },
  { name: 'Romania', code: 'RO' },
  { name: 'Russia', code: 'RU' },
  { name: 'Rwanda', code: 'RW' },
  { name: 'Saint Kitts and Nevis', code: 'KN' },
  { name: 'Saint Lucia', code: 'LC' },
  { name: 'Saint Vincent and the Grenadines', code: 'VC' },
  { name: 'Samoa', code: 'WS' },
  { name: 'San Marino', code: 'SM' },
  { name: 'São Tomé and Príncipe', code: 'ST' },
  { name: 'Saudi Arabia', code: 'SA' },
  { name: 'Senegal', code: 'SN' },
  { name: 'Serbia', code: 'SR' },
  { name: 'Seychelles', code: 'SC' },
  { name: 'Sierra Leone', code: 'SL' },
  { name: 'Singapore', code: 'SG' },
  { name: 'Slovakia', code: 'SK' },
  { name: 'Slovenia', code: 'SI' },
  { name: 'Solomon Islands', code: 'SB' },
  { name: 'Somalia', code: 'SO' },
  { name: 'South Africa', code: 'ZA' },
  { name: 'South Korea', code: 'KR' },
  { name: 'South Sudan', code: 'SS' },
  { name: 'Spain', code: 'ES' },
  { name: 'Sri Lanka', code: 'LK' },
  { name: 'Sudan', code: 'SD' },
  { name: 'Suriname', code: 'SR' },
  { name: 'Sweden', code: 'SE' },
  { name: 'Switzerland', code: 'CH' },
  { name: 'Syria', code: 'SY' },
  { name: 'Taiwan', code: 'TW' },
  { name: 'Tajikistan', code: 'TJ' },
  { name: 'Tanzania', code: 'TZ' },
  { name: 'Thailand', code: 'TH' },
  { name: 'Timor-Leste', code: 'TL' },
  { name: 'Togo', code: 'TG' },
  { name: 'Tonga', code: 'TO' },
  { name: 'Trinidad and Tobago', code: 'TT' },
  { name: 'Tunisia', code: 'TN' },
  { name: 'Turkey', code: 'TR' },
  { name: 'Turkmenistan', code: 'TM' },
  { name: 'Tuvalu', code: 'TV' },
  { name: 'Uganda', code: 'UG' },
  { name: 'Ukraine', code: 'UA' },
  { name: 'United Arab Emirates', code: 'AE' },
  { name: 'United Kingdom', code: 'GB' },
  { name: 'United States', code: 'US' },
  { name: 'Uruguay', code: 'UY' },
  { name: 'Uzbekistan', code: 'UZ' },
  { name: 'Vanuatu', code: 'VU' },
  { name: 'Vatican City', code: 'VA' },
  { name: 'Venezuela', code: 'VE' },
  { name: 'Vietnam', code: 'VN' },
  { name: 'Yemen', code: 'YE' },
  { name: 'Zambia', code: 'ZM' },
  { name: 'Zimbabwe', code: 'ZW' },
]
</script>

<style scoped>
/* ---------- Root / Background ---------- */
.auth-root { position: relative; min-height: 100vh; overflow-x: hidden; color: #0a0f1f; }
.bg-fill { position: absolute; inset: 0; }
.bg-base {
  z-index: 0;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(47, 109, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(55, 214, 255, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.bg-grid {
  z-index: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.03) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 70%);
}
.blob { position: absolute; border-radius: 50%; filter: blur(70px); z-index: 0; }
.blob-1 { top: -120px; right: -80px; width: 380px; height: 380px; background: rgba(47, 109, 255, 0.15); }
.blob-2 { bottom: -80px; left: -80px; width: 340px; height: 340px; background: rgba(55, 214, 255, 0.1); }

/* ---------- Brand ---------- */
.brand-badge {
  width: 46px; height: 46px; border-radius: 13px;
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%);
  box-shadow: 0 6px 18px rgba(47, 109, 255, 0.35);
  display: flex; align-items: center; justify-content: center;
}

/* ---------- Nav ---------- */
.nav-back { color: rgba(15, 23, 42, 0.6) !important; }

/* ---------- Form card ---------- */
.form-card {
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(47, 109, 255, 0.12);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  box-shadow: 0 12px 40px rgba(10, 15, 31, 0.08);
}
.form-title { font-size: 1.55rem; font-weight: 800; color: #0a0f1f; letter-spacing: -0.4px; }
.form-sub { font-size: 0.9rem; color: #64748b; margin-top: 4px; }
.form-footer-text { color: #64748b; }
.form-link { color: #2f6dff !important; }

/* ---------- Stepper ---------- */
:deep(.stepper-dark) {
  background: transparent !important;
}
:deep(.stepper-dark .v-stepper__header) {
  background: #f8fafc;
  border: 1px solid rgba(47, 109, 255, 0.12);
  border-radius: 14px;
  margin-bottom: 24px;
}
:deep(.stepper-dark .v-stepper-item__title) { color: #475569 !important; font-size: 0.82rem; }
:deep(.stepper-dark .v-stepper-item--selected .v-stepper-item__title) { color: #0a0f1f !important; font-weight: 700; }
:deep(.stepper-dark .v-divider) { border-color: rgba(15, 23, 42, 0.08) !important; }
:deep(.stepper-dark .v-stepper-window) { background: transparent !important; padding: 0; }

/* ---------- Step labels ---------- */
.step-overline {
  font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase;
  color: #2f6dff;
}
.step-back-btn { color: rgba(15, 23, 42, 0.6) !important; }
.divider-dark { border-color: rgba(15, 23, 42, 0.08) !important; }

/* ---------- Buttons ---------- */
.btn-primary {
  background: linear-gradient(135deg, #2f6dff 0%, #143ce1 100%) !important;
  color: #fff !important; font-weight: 600;
  box-shadow: 0 8px 22px rgba(47, 109, 255, 0.35);
}
.btn-outline { color: #2f6dff !important; border-color: rgba(47, 109, 255, 0.4) !important; }

/* ---------- Fields (inherit Vuetify outlined) ---------- */
:deep(.v-field) {
  background: #f8fafc !important;
  border-radius: 12px !important;
}
:deep(.v-field__outline) { color: rgba(15, 23, 42, 0.12) !important; }
:deep(.v-field--focused .v-field__outline) { color: rgba(47, 109, 255, 0.6) !important; }
:deep(.v-label) { color: rgba(15, 23, 42, 0.5) !important; }
:deep(.v-field input), :deep(.v-field textarea) { color: #0a0f1f !important; }
:deep(.v-icon.v-field__prepend-inner-icon) { color: rgba(47, 109, 255, 0.5) !important; }

/* ---------- Places list ---------- */
.place-list {
  background: #ffffff !important;
  border: 1px solid rgba(47, 109, 255, 0.15) !important;
  backdrop-filter: blur(12px);
  box-shadow: 0 4px 16px rgba(10, 15, 31, 0.08);
}
:deep(.place-list .v-list-item) { color: #334155 !important; }
:deep(.place-list .v-list-item:hover) { background: rgba(47, 109, 255, 0.06) !important; }

/* ---------- Address card ---------- */
.address-card { background: rgba(47, 109, 255, 0.06) !important; border: 1px solid rgba(47, 109, 255, 0.15) !important; }

/* ---------- Map ---------- */
.map-container { width: 100%; height: 300px; border-radius: 12px; border: 1px solid rgba(15, 23, 42, 0.1); overflow: hidden; }
</style>
