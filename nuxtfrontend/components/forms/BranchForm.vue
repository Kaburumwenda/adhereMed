<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit Branch' : 'New Branch'" icon="mdi-source-branch" back-path="/branches" :load-id="loadId" :initial="initial" @saved="() => router.push('/branches')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Phone" /></v-col>
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
            variant="outlined" density="comfortable"
            prepend-inner-icon="mdi-map-marker"
            return-object hide-no-data hide-details="auto"
            no-filter clearable
            @update:search="onAddressSearch"
            @update:model-value="(p) => onAddressPicked(p, form)"
          >
            <template #append-inner>
              <v-tooltip text="Pick on map" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-map-search" variant="text" size="small" color="primary"
                         @click.stop="() => openMapPicker(form)" />
                </template>
              </v-tooltip>
              <v-tooltip text="Use my current location" location="top">
                <template #activator="{ props }">
                  <v-btn
                    v-bind="props" icon="mdi-crosshairs-gps"
                    variant="text" size="small" color="indigo"
                    :loading="locating" @click.stop="() => useMyLocation(form)"
                  />
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
            v-model="form.address" label="Address (editable)" rows="2" auto-grow
            variant="outlined" density="comfortable" class="mt-2"
            prepend-inner-icon="mdi-pencil" hide-details="auto"
            hint="Pick from suggestions, the map, or type manually" persistent-hint
          />
          <div v-if="form.latitude != null && form.longitude != null" class="d-flex flex-wrap ga-2 mt-2">
            <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-map-marker">
              {{ Number(form.latitude).toFixed(6) }}, {{ Number(form.longitude).toFixed(6) }}
            </v-chip>
            <v-chip v-if="form.place_name" size="small" variant="tonal" color="success" prepend-icon="mdi-tag">
              {{ form.place_name }}
            </v-chip>
            <v-btn size="x-small" variant="text" color="error" prepend-icon="mdi-close"
                   @click="() => { form.latitude = null; form.longitude = null; form.place_name = '' }">Clear</v-btn>
          </div>
        </v-col>
      </v-row>

      <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="(p) => onMapPicked(p, form)" />
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { ref } from 'vue'
import { useResource } from '~/composables/useResource'
import { useGoogleMaps } from '~/composables/useGoogleMaps'

const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/pharmacy_profile/branches/')
const req = [v => !!v || 'Required']
const initial = { name: '', phone: '', address: '', place_name: '', latitude: null, longitude: null }

const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
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
async function onAddressPicked(pred, form) {
  if (!pred?.place_id || !form) return
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
function useMyLocation(form) {
  if (!navigator.geolocation || !form) return
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

// Map picker
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})
function openMapPicker(form) {
  mapPickerInitial.value = {
    lat: form.latitude, lng: form.longitude,
    address: form.address, place_name: form.place_name,
  }
  mapPickerOpen.value = true
}
function onMapPicked(p, form) {
  form.latitude = round6(p.lat)
  form.longitude = round6(p.lng)
  if (p.address) { form.address = p.address; addressQuery.value = p.address }
  if (p.place_name) form.place_name = p.place_name
}
</script>
