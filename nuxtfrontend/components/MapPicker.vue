<template>
  <v-dialog v-model="open" :max-width="fullscreen ? undefined : 780" :fullscreen="fullscreen" scrollable>
    <v-card rounded="xl" :class="{ 'mp-fs-card': fullscreen }">
      <v-card-title class="d-flex align-center pb-2">
        <v-icon color="primary" class="mr-2">mdi-map-search</v-icon>
        Pick location on map
        <v-spacer />
        <v-tooltip :text="fullscreen ? 'Exit fullscreen' : 'Fullscreen'" location="bottom">
          <template #activator="{ props }">
            <v-btn v-bind="props"
                   :icon="fullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen'"
                   variant="text" size="small" @click="toggleFullscreen" />
          </template>
        </v-tooltip>
        <v-btn icon="mdi-close" variant="text" size="small" @click="open = false" />
      </v-card-title>
      <v-divider />
      <v-card-text class="pa-3 pa-md-4" :style="fullscreen ? 'max-height: none' : 'max-height: 80vh'">
        <v-autocomplete
          v-model="searchSelection"
          v-model:search="searchQuery"
          :items="predictions"
          :loading="loadingSearch"
          item-title="description"
          item-value="place_id"
          label="Search a place"
          placeholder="Type to search & jump…"
          variant="outlined" density="comfortable"
          prepend-inner-icon="mdi-magnify"
          return-object hide-no-data hide-details
          no-filter clearable class="mb-3"
          @update:search="onSearchInput"
          @update:model-value="onSearchPicked"
        >
          <template #append-inner>
            <v-tooltip text="Use my current location" location="top">
              <template #activator="{ props }">
                <v-btn
                  v-bind="props" icon="mdi-crosshairs-gps"
                  variant="text" size="small" color="indigo"
                  :loading="locating" @click.stop="useMyLocation"
                />
              </template>
            </v-tooltip>
          </template>
        </v-autocomplete>

        <div ref="mapEl" class="mp-map" :class="{ 'mp-map-fs': fullscreen }" />

        <v-alert v-if="error" type="error" variant="tonal" density="compact" class="mt-3">
          {{ error }}
        </v-alert>

        <div v-if="picked.lat != null" class="mp-meta mt-3">
          <div class="d-flex align-center flex-wrap ga-2">
            <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-map-marker">
              {{ picked.lat.toFixed(6) }}, {{ picked.lng.toFixed(6) }}
            </v-chip>
            <v-chip v-if="picked.place_name" size="small" variant="tonal" color="success" prepend-icon="mdi-tag">
              {{ picked.place_name }}
            </v-chip>
          </div>
          <div v-if="picked.address" class="text-body-2 text-medium-emphasis mt-2">
            {{ picked.address }}
          </div>
          <div class="text-caption text-medium-emphasis mt-1">
            Drag the pin or click anywhere on the map to refine.
          </div>
        </div>
      </v-card-text>
      <v-divider />
      <v-card-actions class="pa-3">
        <v-spacer />
        <v-btn variant="text" @click="open = false">Cancel</v-btn>
        <v-btn color="primary" variant="flat" :disabled="picked.lat == null" @click="confirm">
          Use this location
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup>
import { ref, reactive, watch, nextTick } from 'vue'
import { useGoogleMaps } from '~/composables/useGoogleMaps'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  initial: { type: Object, default: () => ({}) }, // { lat, lng, address, place_name }
  country: { type: String, default: 'ke' },
})
const emit = defineEmits(['update:modelValue', 'picked'])

const { load, getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()

const open = ref(props.modelValue)
watch(() => props.modelValue, v => { open.value = v })
watch(open, v => emit('update:modelValue', v))

const fullscreen = ref(false)
async function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
  // Let Google Maps recompute size after the dialog resizes
  await nextTick()
  setTimeout(() => {
    if (map && window.google?.maps) {
      const center = map.getCenter()
      window.google.maps.event.trigger(map, 'resize')
      if (center) map.setCenter(center)
    }
  }, 220)
}

const mapEl = ref(null)
const error = ref('')
const loadingSearch = ref(false)
const locating = ref(false)
const searchQuery = ref('')
const searchSelection = ref(null)
const predictions = ref([])
let searchTimer = null

const picked = reactive({ lat: null, lng: null, address: '', place_name: '' })

let map = null
let marker = null
let geocoder = null

function round6(n) { return Math.round(Number(n) * 1e6) / 1e6 }

async function ensureMap() {
  await nextTick()
  if (!mapEl.value) return
  try {
    const google = await load()
    geocoder = new google.maps.Geocoder()
    const start = (props.initial?.lat != null && props.initial?.lng != null)
      ? { lat: Number(props.initial.lat), lng: Number(props.initial.lng) }
      : { lat: -1.2921, lng: 36.8219 } // Nairobi default
    map = new google.maps.Map(mapEl.value, {
      center: start, zoom: props.initial?.lat != null ? 16 : 12,
      mapTypeControl: false, streetViewControl: false, fullscreenControl: false,
    })
    marker = new google.maps.Marker({
      map, position: start, draggable: true, animation: google.maps.Animation.DROP,
    })
    if (props.initial?.lat != null) {
      Object.assign(picked, {
        lat: round6(start.lat), lng: round6(start.lng),
        address: props.initial.address || '',
        place_name: props.initial.place_name || '',
      })
    }
    map.addListener('click', (e) => updatePosition(e.latLng))
    marker.addListener('dragend', () => updatePosition(marker.getPosition()))
  } catch (e) {
    error.value = e?.message || 'Failed to load map'
  }
}

async function updatePosition(latLng) {
  if (!latLng) return
  const lat = round6(latLng.lat())
  const lng = round6(latLng.lng())
  marker.setPosition(latLng)
  picked.lat = lat
  picked.lng = lng
  // Reverse-geocode to get address + nearest place name
  if (geocoder) {
    try {
      const res = await new Promise((resolve, reject) => {
        geocoder.geocode({ location: { lat, lng } }, (r, status) => {
          if (status === 'OK' && r?.length) resolve(r); else reject(new Error(status))
        })
      })
      picked.address = res[0]?.formatted_address || ''
      // Place name: pick the most specific component (POI / establishment / locality)
      const first = res[0]
      const compTypes = ['point_of_interest', 'establishment', 'premise', 'neighborhood', 'sublocality', 'locality']
      let name = ''
      for (const t of compTypes) {
        const c = first?.address_components?.find(c => c.types?.includes(t))
        if (c) { name = c.long_name; break }
      }
      picked.place_name = name || (picked.address.split(',')[0] || '')
    } catch {
      // Ignore reverse-geocode failures; coords still saved.
    }
  }
}

function onSearchInput(q) {
  if (searchTimer) clearTimeout(searchTimer)
  if (!q || q.length < 3) { predictions.value = []; return }
  loadingSearch.value = true
  searchTimer = setTimeout(async () => {
    try { predictions.value = await getPredictions(q, { country: props.country }) }
    catch { predictions.value = [] }
    finally { loadingSearch.value = false }
  }, 280)
}

async function onSearchPicked(pred) {
  if (!pred?.place_id || !map) return
  try {
    const d = await getPlaceDetails(pred.place_id)
    const pos = { lat: Number(d.lat), lng: Number(d.lng) }
    map.panTo(pos); map.setZoom(17)
    marker.setPosition(pos)
    picked.lat = round6(pos.lat)
    picked.lng = round6(pos.lng)
    picked.address = d.address || pred.description
    picked.place_name = d.name || (pred.structured_formatting?.main_text || '')
  } catch (e) {
    error.value = e?.message || 'Place lookup failed'
  }
}

function useMyLocation() {
  if (!navigator.geolocation) { error.value = 'Geolocation not supported'; return }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        if (map && marker) {
          const pos = { lat: coords.latitude, lng: coords.longitude }
          map.panTo(pos); map.setZoom(17)
          marker.setPosition(pos)
          await updatePosition(marker.getPosition())
        }
      } finally { locating.value = false }
    },
    (err) => { locating.value = false; error.value = err.message || 'Could not get location' },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

function confirm() {
  if (picked.lat == null) return
  emit('picked', { ...picked })
  open.value = false
}

watch(open, async (v) => {
  if (v) {
    error.value = ''
    fullscreen.value = false
    Object.assign(picked, { lat: null, lng: null, address: '', place_name: '' })
    searchQuery.value = ''; searchSelection.value = null; predictions.value = []
    map = null; marker = null
    await ensureMap()
  }
})
</script>

<style scoped>
.mp-map {
  width: 100%;
  height: 360px;
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  background: rgba(var(--v-theme-surface-variant), 0.4);
}
.mp-map-fs { height: calc(100vh - 260px); min-height: 420px; border-radius: 8px; }
.mp-fs-card { border-radius: 0 !important; height: 100vh; display: flex; flex-direction: column; }
.mp-fs-card :deep(.v-card-text) { flex: 1 1 auto; }
.mp-meta {
  padding: 10px 12px;
  border-radius: 12px;
  background: rgba(var(--v-theme-primary), 0.06);
  border: 1px dashed rgba(var(--v-theme-primary), 0.35);
}
</style>
