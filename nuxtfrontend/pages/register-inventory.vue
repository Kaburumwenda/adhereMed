<template>
  <NuxtLayout name="auth">
    <div class="auth-root">
      <div class="bg-base bg-fill" />

      <v-container fluid class="fill-height" style="position:relative;z-index:2;">
        <v-row justify="center" align="center" class="fill-height py-6">
          <v-col cols="12" sm="11" md="9" lg="7" xl="6">
            <v-btn
              variant="text"
              class="text-none mb-4 back-btn"
              prepend-icon="mdi-arrow-left"
              @click="$router.push('/get-started')"
            >Back</v-btn>

            <v-card rounded="xl" elevation="12" class="form-card pa-6 pa-md-8">
              <div class="text-center mb-6">
                <div class="brand-badge mx-auto mb-4 d-flex align-center justify-center">
                  <v-icon size="24" color="white">mdi-package-variant-closed</v-icon>
                </div>
                <h2 class="form-title">Register your Inventory / Warehouse</h2>
                <p class="form-sub">
                  Set up an independent inventory-management tenant on AdhereMed — stock control,
                  procurement, sales and warehousing
                </p>
              </div>

              <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" rounded="lg" class="mb-4">
                {{ errorMsg }}
              </v-alert>
              <v-alert v-if="success" type="success" variant="tonal" rounded="lg" class="mb-4">
                Warehouse created successfully! Redirecting to sign in…
              </v-alert>

              <v-form v-if="!success" ref="formRef" @submit.prevent="onSubmit">
                <p class="text-overline text-medium-emphasis mb-2">Warehouse details</p>
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.tenantName" label="Warehouse / business name *" :rules="req"
                                  prepend-inner-icon="mdi-store" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.warehouseEmail" label="Business email" type="email"
                                  prepend-inner-icon="mdi-email-outline" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.phone" label="Business phone"
                                  prepend-inner-icon="mdi-phone-outline" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.city" label="City / Town"
                                  prepend-inner-icon="mdi-city" variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-autocomplete
                      v-model="form.country"
                      :items="countries"
                      item-title="name"
                      item-value="code"
                      label="Country"
                      prepend-inner-icon="mdi-earth"
                      variant="outlined"
                      rounded="lg"
                      color="brand"
                      clearable
                      hide-details="auto"
                    />
                  </v-col>
                  <v-col cols="12">
                    <v-autocomplete
                      v-model="addressSelection"
                      v-model:search="addressQuery"
                      :items="addressPredictions"
                      :loading="loadingPlaces"
                      item-title="description"
                      item-value="place_id"
                      label="Address *"
                      placeholder="Start typing an address…"
                      :rules="req"
                      prepend-inner-icon="mdi-map-marker"
                      variant="outlined"
                      rounded="lg"
                      color="brand"
                      return-object
                      hide-no-data
                      hide-details="auto"
                      no-filter
                      clearable
                      @update:search="onAddressSearch"
                      @update:model-value="onAddressPicked"
                    >
                      <template #append-inner>
                        <v-tooltip text="Use my current location" location="top">
                          <template #activator="{ props }">
                            <v-btn
                              v-bind="props" icon="mdi-crosshairs-gps"
                              variant="text" size="small" color="teal"
                              :loading="locating" @click.stop="useMyLocation"
                            />
                          </template>
                        </v-tooltip>
                      </template>
                      <template #item="{ props, item }">
                        <v-list-item v-bind="props" prepend-icon="mdi-map-marker-outline">
                          <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                            {{ item.raw.structured_formatting.secondary_text }}
                          </v-list-item-subtitle>
                        </v-list-item>
                      </template>
                    </v-autocomplete>
                  </v-col>
                  <v-col v-if="form.address" cols="12">
                    <v-card variant="tonal" color="teal" rounded="lg" class="pa-3 address-card">
                      <div class="d-flex align-center">
                        <v-icon color="teal-darken-2" class="mr-2">mdi-check-circle</v-icon>
                        <div>
                          <div class="text-body-2 font-weight-medium">{{ form.address }}</div>
                          <div v-if="form.lat && form.lng" class="text-caption text-medium-emphasis">
                            {{ Number(form.lat).toFixed(5) }}, {{ Number(form.lng).toFixed(5) }}
                          </div>
                        </div>
                        <v-spacer />
                        <v-btn icon="mdi-close" size="small" variant="text" @click="clearAddress" />
                      </div>
                    </v-card>
                  </v-col>
                </v-row>

                <v-divider class="my-4 divider-light" />
                <p class="text-overline text-medium-emphasis mb-2">Admin user</p>
                <v-row dense>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.firstName" label="First name *" :rules="req"
                                  variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                  <v-col cols="12" md="6">
                    <v-text-field v-model="form.lastName" label="Last name *" :rules="req"
                                  variant="outlined" rounded="lg" color="brand" />
                  </v-col>
                </v-row>
                <v-text-field
                  v-model="form.email"
                  label="Admin email *"
                  type="email"
                  :rules="[v => !!v || 'Required', v => /.+@.+\..+/.test(v) || 'Invalid']"
                  prepend-inner-icon="mdi-email"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                />
                <v-text-field v-model="form.adminPhone" label="Admin phone"
                              prepend-inner-icon="mdi-phone" variant="outlined" rounded="lg" color="brand" />
                <v-text-field
                  v-model="form.password"
                  label="Password *"
                  :type="show ? 'text' : 'password'"
                  :append-inner-icon="show ? 'mdi-eye-off' : 'mdi-eye'"
                  prepend-inner-icon="mdi-lock"
                  :rules="[v => !!v || 'Required', v => v.length >= 8 || 'Min 8 characters']"
                  variant="outlined"
                  rounded="lg"
                  color="brand"
                  @click:append-inner="show = !show"
                />

                <v-divider class="my-4 divider-light" />
                <p class="text-overline text-medium-emphasis mb-2">Referral (optional)</p>
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
                  rounded="lg"
                  @update:model-value="debouncedValidateCode"
                />

                <v-btn
                  type="submit"
                  size="large"
                  block
                  rounded="lg"
                  class="text-none btn-primary mt-2"
                  prepend-icon="mdi-package-variant-closed"
                  :loading="loading"
                >Register Inventory / Warehouse</v-btn>

                <div class="text-center mt-6 text-body-2 form-footer-text">
                  Already registered?
                  <NuxtLink to="/login" class="form-link font-weight-medium">Sign in</NuxtLink>
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
definePageMeta({ layout: false })

import { useGoogleMaps } from '~/composables/useGoogleMaps'

const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()

const formRef = ref(null)
const loading = ref(false)
const errorMsg = ref('')
const success = ref(false)
const show = ref(false)
const req = [v => !!v || 'Required']

const form = reactive({
  tenantName: '',
  warehouseEmail: '',
  phone: '',
  city: '',
  country: '',
  address: '',
  lat: null,
  lng: null,
  placeName: '',
  firstName: '',
  lastName: '',
  email: '',
  adminPhone: '',
  password: '',
  referralCode: '',
})

// ── Google Places address autocomplete ───────────────────────────────────
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
let addressTimer = null

function round6(n) {
  if (n == null || n === '' || isNaN(Number(n))) return null
  return Math.round(Number(n) * 1e6) / 1e6
}

function onAddressSearch(q) {
  clearTimeout(addressTimer)
  if (!q || q.length < 3) { addressPredictions.value = []; return }
  loadingPlaces.value = true
  addressTimer = setTimeout(async () => {
    try {
      addressPredictions.value = await getPredictions(q)
    } catch {
      addressPredictions.value = []
    } finally {
      loadingPlaces.value = false
    }
  }, 300)
}

async function onAddressPicked(pred) {
  if (!pred?.place_id) {
    if (!pred) clearAddress()
    return
  }
  try {
    const details = await getPlaceDetails(pred.place_id)
    form.address = details.address || pred.description
    form.lat = round6(details.lat)
    form.lng = round6(details.lng)
    form.placeName = details.name || pred.structured_formatting?.main_text || ''
    addressQuery.value = form.address
    addressSelection.value = pred
  } catch {
    form.address = pred.description
    form.lat = null
    form.lng = null
  }
}

function clearAddress() {
  form.address = ''
  form.lat = null
  form.lng = null
  form.placeName = ''
  addressQuery.value = ''
  addressSelection.value = null
}

function useMyLocation() {
  if (!navigator.geolocation) return
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.address = addr
        form.lat = round6(coords.latitude)
        form.lng = round6(coords.longitude)
        form.placeName = 'My current location'
        addressQuery.value = addr
      } catch {
        form.address = `${coords.latitude.toFixed(5)}, ${coords.longitude.toFixed(5)}`
        form.lat = round6(coords.latitude)
        form.lng = round6(coords.longitude)
      } finally {
        locating.value = false
      }
    },
    () => {
      locating.value = false
    },
    { enableHighAccuracy: true, timeout: 15000 }
  )
}

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

// ── Submit ──────────────────────────────────────────────────────────────
async function onSubmit() {
  errorMsg.value = ''
  const { valid } = await formRef.value.validate()
  if (!valid) return
  loading.value = true
  try {
    // Generate slug and domain from the warehouse name
    const slug = form.tenantName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 50)
    const domain = `${slug}.adheremed.com`

    await $api.post('/tenants/register/', {
      name: form.tenantName,
      type: 'inventory',
      slug,
      domain,
      email: form.warehouseEmail,
      phone: form.phone,
      address: form.address,
      city: form.city,
      country: form.country,
      latitude: form.lat,
      longitude: form.lng,
      place_name: form.placeName,
      admin_email: form.email,
      admin_password: form.password,
      admin_first_name: form.firstName,
      admin_last_name: form.lastName,
      referral_code: (form.referralCode || '').trim().toUpperCase(),
    }, {
      // Tenant creation provisions a new Postgres schema and runs all
      // migrations synchronously — can take 30–90s on a cold DB.
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

// ── Countries (worldwide) ────────────────────────────────────────────────
const countries = [
  { name: 'Afghanistan', code: 'AF' },
  { name: 'Albania', code: 'AL' },
  { name: 'Algeria', code: 'DZ' },
  { name: 'Andorra', code: 'AD' },
  { name: 'Angola', code: 'AO' },
  { name: 'Argentina', code: 'AR' },
  { name: 'Armenia', code: 'AM' },
  { name: 'Australia', code: 'AU' },
  { name: 'Austria', code: 'AT' },
  { name: 'Azerbaijan', code: 'AZ' },
  { name: 'Bahrain', code: 'BH' },
  { name: 'Bangladesh', code: 'BD' },
  { name: 'Belarus', code: 'BY' },
  { name: 'Belgium', code: 'BE' },
  { name: 'Bolivia', code: 'BO' },
  { name: 'Bosnia and Herzegovina', code: 'BA' },
  { name: 'Botswana', code: 'BW' },
  { name: 'Brazil', code: 'BR' },
  { name: 'Bulgaria', code: 'BG' },
  { name: 'Cambodia', code: 'KH' },
  { name: 'Cameroon', code: 'CM' },
  { name: 'Canada', code: 'CA' },
  { name: 'Chile', code: 'CL' },
  { name: 'China', code: 'CN' },
  { name: 'Colombia', code: 'CO' },
  { name: 'Costa Rica', code: 'CR' },
  { name: "Côte d'Ivoire", code: 'CI' },
  { name: 'Croatia', code: 'HR' },
  { name: 'Cuba', code: 'CU' },
  { name: 'Cyprus', code: 'CY' },
  { name: 'Czech Republic', code: 'CZ' },
  { name: 'Denmark', code: 'DK' },
  { name: 'Dominican Republic', code: 'DO' },
  { name: 'Ecuador', code: 'EC' },
  { name: 'Egypt', code: 'EG' },
  { name: 'El Salvador', code: 'SV' },
  { name: 'Estonia', code: 'EE' },
  { name: 'Ethiopia', code: 'ET' },
  { name: 'Finland', code: 'FI' },
  { name: 'France', code: 'FR' },
  { name: 'Georgia', code: 'GE' },
  { name: 'Germany', code: 'DE' },
  { name: 'Ghana', code: 'GH' },
  { name: 'Greece', code: 'GR' },
  { name: 'Guatemala', code: 'GT' },
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
  { name: 'Kenya', code: 'KE' },
  { name: 'Kuwait', code: 'KW' },
  { name: 'Latvia', code: 'LV' },
  { name: 'Lebanon', code: 'LB' },
  { name: 'Libya', code: 'LY' },
  { name: 'Lithuania', code: 'LT' },
  { name: 'Luxembourg', code: 'LU' },
  { name: 'Malaysia', code: 'MY' },
  { name: 'Malta', code: 'MT' },
  { name: 'Mexico', code: 'MX' },
  { name: 'Moldova', code: 'MD' },
  { name: 'Monaco', code: 'MC' },
  { name: 'Mongolia', code: 'MN' },
  { name: 'Morocco', code: 'MA' },
  { name: 'Mozambique', code: 'MZ' },
  { name: 'Myanmar', code: 'MM' },
  { name: 'Namibia', code: 'NA' },
  { name: 'Nepal', code: 'NP' },
  { name: 'Netherlands', code: 'NL' },
  { name: 'New Zealand', code: 'NZ' },
  { name: 'Nicaragua', code: 'NI' },
  { name: 'Nigeria', code: 'NG' },
  { name: 'North Macedonia', code: 'MK' },
  { name: 'Norway', code: 'NO' },
  { name: 'Oman', code: 'OM' },
  { name: 'Pakistan', code: 'PK' },
  { name: 'Panama', code: 'PA' },
  { name: 'Paraguay', code: 'PY' },
  { name: 'Peru', code: 'PE' },
  { name: 'Philippines', code: 'PH' },
  { name: 'Poland', code: 'PL' },
  { name: 'Portugal', code: 'PT' },
  { name: 'Qatar', code: 'QA' },
  { name: 'Romania', code: 'RO' },
  { name: 'Russia', code: 'RU' },
  { name: 'Rwanda', code: 'RW' },
  { name: 'Saudi Arabia', code: 'SA' },
  { name: 'Senegal', code: 'SN' },
  { name: 'Serbia', code: 'RS' },
  { name: 'Singapore', code: 'SG' },
  { name: 'Slovakia', code: 'SK' },
  { name: 'Slovenia', code: 'SI' },
  { name: 'South Africa', code: 'ZA' },
  { name: 'South Korea', code: 'KR' },
  { name: 'Spain', code: 'ES' },
  { name: 'Sri Lanka', code: 'LK' },
  { name: 'Sudan', code: 'SD' },
  { name: 'Sweden', code: 'SE' },
  { name: 'Switzerland', code: 'CH' },
  { name: 'Taiwan', code: 'TW' },
  { name: 'Tanzania', code: 'TZ' },
  { name: 'Thailand', code: 'TH' },
  { name: 'Tunisia', code: 'TN' },
  { name: 'Turkey', code: 'TR' },
  { name: 'Uganda', code: 'UG' },
  { name: 'Ukraine', code: 'UA' },
  { name: 'United Arab Emirates', code: 'AE' },
  { name: 'United Kingdom', code: 'GB' },
  { name: 'United States', code: 'US' },
  { name: 'Uruguay', code: 'UY' },
  { name: 'Uzbekistan', code: 'UZ' },
  { name: 'Venezuela', code: 'VE' },
  { name: 'Vietnam', code: 'VN' },
  { name: 'Yemen', code: 'YE' },
  { name: 'Zambia', code: 'ZM' },
  { name: 'Zimbabwe', code: 'ZW' },
]
</script>

<style scoped>
.auth-root { position: relative; min-height: 100vh; overflow: hidden; color: #0a0f1f; }
.bg-fill { position: absolute; inset: 0; z-index: 0; }
.bg-base {
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(13, 148, 136, 0.14), transparent 60%),
    radial-gradient(900px 500px at 0% 20%, rgba(14, 165, 233, 0.08), transparent 55%),
    linear-gradient(160deg, #f8fafc 0%, #ffffff 45%, #f1f5f9 100%);
}
.back-btn { color: rgba(15, 23, 42, 0.6) !important; }
.form-card {
  border: 1px solid rgba(13, 148, 136, 0.16);
  box-shadow: 0 12px 40px rgba(10, 15, 31, 0.08);
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(12px);
}
.brand-badge {
  width: 52px; height: 52px; border-radius: 16px;
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%);
  box-shadow: 0 6px 18px rgba(13, 148, 136, 0.35);
}
.form-title { color: #0a0f1f; font-weight: 800; }
.form-sub { color: #64748b; }
.form-footer-text { color: #64748b; }
.form-link { color: #0d9488 !important; }
.divider-light { border-color: rgba(15, 23, 42, 0.08) !important; }
.btn-primary {
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%) !important;
  color: #fff !important;
  font-weight: 600;
  box-shadow: 0 10px 26px rgba(13, 148, 136, 0.35);
}
.address-card {
  background: rgba(13, 148, 136, 0.06) !important;
  border: 1px solid rgba(13, 148, 136, 0.15) !important;
}
</style>
