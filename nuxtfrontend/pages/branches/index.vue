<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="blue-lighten-5" size="48" class="mr-3">
          <v-icon color="blue-darken-2" size="28">mdi-store</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Branches</h1>
          <div class="text-body-2 text-medium-emphasis">Manage your pharmacy locations &amp; contact details</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
                 prepend-icon="mdi-plus" @click="openCreate">New branch</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name or address…"
                        density="comfortable" variant="solo-filled" flat hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="activeFilter" :items="activeItems" label="Status"
                    density="comfortable" variant="outlined" hide-details />
        </v-col>
        <v-col cols="6" md="2" class="text-right">
          <v-chip color="primary" variant="tonal">{{ filtered.length }} shown</v-chip>
        </v-col>
        <v-col cols="12" md="3" class="d-flex justify-end">
          <v-btn-toggle v-model="viewMode" mandatory density="comfortable" rounded="lg" color="primary" variant="outlined">
            <v-btn value="table" prepend-icon="mdi-table">Table</v-btn>
            <v-btn value="map" prepend-icon="mdi-map">Map</v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- ══════ MAP VIEW ══════ -->
    <v-card v-if="viewMode === 'map'" flat rounded="xl" border class="overflow-hidden">
      <div v-if="geoBranches.length === 0" class="d-flex flex-column align-center justify-center pa-10">
        <v-icon size="64" color="grey-lighten-1" class="mb-3">mdi-map-marker-off</v-icon>
        <div class="text-h6 text-medium-emphasis">No branch locations</div>
        <div class="text-body-2 text-medium-emphasis">Add coordinates to your branches to see them on the map.</div>
      </div>
      <div v-else>
        <div ref="allBranchesMapEl" class="branches-map" />
        <!-- Legend chips under the map -->
        <div class="d-flex flex-wrap ga-2 pa-3 border-t">
          <v-chip v-for="b in geoBranches" :key="b.id" size="small" variant="tonal"
                  :color="b.is_main ? 'amber-darken-2' : b.is_active ? 'blue' : 'grey'"
                  :prepend-icon="b.is_main ? 'mdi-star' : 'mdi-store'"
                  @click="panToMarker(b)">
            {{ b.name }}
          </v-chip>
        </div>
      </div>
    </v-card>

    <!-- ══════ TABLE VIEW ══════ -->
    <v-card v-else flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading"
                    density="comfortable" hover :items-per-page="25">
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="item.is_main ? 'amber-darken-2' : 'blue'" size="32" class="mr-2">
              <v-icon color="white" size="18">{{ item.is_main ? 'mdi-star' : 'mdi-store' }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.name }}</div>
              <v-chip v-if="item.is_main" size="x-small" color="amber-darken-2" variant="tonal">Main</v-chip>
            </div>
          </div>
        </template>
        <template #item.address="{ item }">
          <span class="text-body-2">{{ item.address || '—' }}</span>
        </template>
        <template #item.phone="{ item }">{{ item.phone || '—' }}</template>
        <template #item.email="{ item }">{{ item.email || '—' }}</template>
        <template #item.is_active="{ item }">
          <v-icon :color="item.is_active ? 'success' : 'grey'" size="18">
            {{ item.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}
          </v-icon>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(item)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(item)" />
        </template>
        <template #no-data>
          <EmptyState icon="mdi-store-off" title="No branches yet"
                      message="Add your first branch to get started." />
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="formDialog" max-width="640" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-store</v-icon>
          {{ form.id ? 'Edit branch' : 'New branch' }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12">
              <v-text-field v-model="form.name" label="Branch name *"
                            variant="outlined" density="comfortable" :error-messages="errors.name" />
            </v-col>
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
                @update:model-value="onAddressPicked"
              >
                <template #append-inner>
                  <v-tooltip text="Pick on map" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-map-search" variant="text" size="small" color="primary"
                             @click.stop="openMapPicker" />
                    </template>
                  </v-tooltip>
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
                <template #item="{ props: ip, item }">
                  <v-list-item v-bind="ip" prepend-icon="mdi-map-marker-outline">
                    <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                      {{ item.raw.structured_formatting.secondary_text }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </template>
              </v-autocomplete>
              <v-textarea v-model="form.address" label="Address (editable)" rows="2" auto-grow
                          variant="outlined" density="comfortable" class="mt-2"
                          prepend-inner-icon="mdi-pencil" hide-details="auto"
                          hint="Pick from suggestions, the map, or type manually" persistent-hint />
              <div v-if="form.latitude != null && form.longitude != null" class="d-flex flex-wrap ga-2 mt-2">
                <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-map-marker">
                  {{ Number(form.latitude).toFixed(6) }}, {{ Number(form.longitude).toFixed(6) }}
                </v-chip>
                <v-chip v-if="form.place_name" size="small" variant="tonal" color="success" prepend-icon="mdi-tag">
                  {{ form.place_name }}
                </v-chip>
                <v-btn size="x-small" variant="text" color="error" prepend-icon="mdi-close" @click="clearGeo">Clear</v-btn>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone" prepend-inner-icon="mdi-phone"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" type="email"
                            prepend-inner-icon="mdi-email" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.is_main" label="Main branch" color="amber-darken-2"
                        density="comfortable" hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-switch v-model="form.is_active" label="Active" color="success"
                        density="comfortable" hide-details />
            </v-col>
          </v-row>
          <v-alert v-if="form.is_main && hasOtherMain" type="warning" variant="tonal" class="mt-3">
            Another branch is already marked as main. Only one branch should be the main location.
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="save">
            {{ form.id ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card v-if="deleteTarget" rounded="xl">
        <v-card-title>Delete branch?</v-card-title>
        <v-card-text>
          This will remove <strong>{{ deleteTarget.name }}</strong>.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>

    <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="onMapPicked" />
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch, nextTick } from 'vue'
import EmptyState from '~/components/EmptyState.vue'
import { useI18n } from 'vue-i18n'
import pinIcon from '~/assets/images/pin.png'

const { t } = useI18n()
const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const branches = ref([])

async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/branches/', { params: { page_size: 200 } })
    branches.value = data?.results || data || []
  } catch { notify('Failed to load branches', 'error') }
  finally { loading.value = false }
}
onMounted(loadAll)

const search = ref('')
const activeFilter = ref('all')
const activeItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return branches.value.filter(b => {
    if (activeFilter.value === 'active' && !b.is_active) return false
    if (activeFilter.value === 'inactive' && b.is_active) return false
    if (!q) return true
    return [b.name, b.address, b.phone, b.email].some(v => (v || '').toLowerCase().includes(q))
  })
})

const kpiTiles = computed(() => [
  { label: 'Total', value: branches.value.length, icon: 'mdi-store', color: 'blue' },
  { label: 'Active', value: branches.value.filter(b => b.is_active).length,
    icon: 'mdi-check-circle', color: 'success' },
  { label: 'Main', value: branches.value.filter(b => b.is_main).length,
    icon: 'mdi-star', color: 'amber-darken-2' },
  { label: 'Inactive', value: branches.value.filter(b => !b.is_active).length,
    icon: 'mdi-pause-circle', color: 'grey' },
])

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Address', key: 'address' },
  { title: 'Phone', key: 'phone' },
  { title: 'Email', key: 'email' },
  { title: 'Active', key: 'is_active', sortable: false, align: 'center' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 120 },
]

const formDialog = ref(false)
const form = reactive(blankForm())
const errors = reactive({})
function blankForm() { return { id: null, name: '', address: '', place_name: '', latitude: null, longitude: null, phone: '', email: '', is_main: false, is_active: true } }
function openCreate() { Object.assign(form, blankForm()); clearErrors(); resetAddressPicker(); formDialog.value = true }
function openEdit(b) { Object.assign(form, blankForm(), b); clearErrors(); resetAddressPicker(b?.address || ''); formDialog.value = true }
function clearErrors() { Object.keys(errors).forEach(k => delete errors[k]) }
function clearGeo() { form.latitude = null; form.longitude = null; form.place_name = '' }

function round6(n) { if (n == null || n === '' || isNaN(Number(n))) return null; return Math.round(Number(n) * 1e6) / 1e6 }

// ── Map picker dialog ──
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})
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

// ── Google Places autocomplete (with manual fallback) ──
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
let _addrTimer = null

function resetAddressPicker(initial = '') {
  addressQuery.value = initial
  addressSelection.value = null
  addressPredictions.value = []
}
function onAddressSearch(q) {
  if (_addrTimer) clearTimeout(_addrTimer)
  if (!q || q.length < 3) { addressPredictions.value = []; return }
  loadingPlaces.value = true
  _addrTimer = setTimeout(async () => {
    try { addressPredictions.value = await getPredictions(q, { country: 'ke' }) }
    catch (e) { addressPredictions.value = []; notify(e?.message || 'Places lookup failed', 'error') }
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
  } catch (e) {
    form.address = pred.description
    notify(e?.message || 'Could not resolve place', 'error')
  }
}
async function useMyLocation() {
  if (!navigator.geolocation) { notify('Geolocation not supported', 'error'); return }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.address = addr
        form.latitude = round6(coords.latitude)
        form.longitude = round6(coords.longitude)
        addressQuery.value = addr
        notify('Address detected from your location')
      } catch (e) { notify(e?.message || 'Reverse geocoding failed', 'error') }
      finally { locating.value = false }
    },
    (err) => { locating.value = false; notify(err.message || 'Could not get location', 'error') },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

const hasOtherMain = computed(() =>
  branches.value.some(b => b.is_main && b.id !== form.id),
)

async function save() {
  clearErrors()
  if (!form.name) { errors.name = 'Required'; return }
  saving.value = true
  try {
    const payload = { ...form }; delete payload.id
    if (form.id) await $api.put(`/pharmacy-profile/branches/${form.id}/`, payload)
    else await $api.post('/pharmacy-profile/branches/', payload)
    notify(form.id ? 'Branch updated' : 'Branch created')
    formDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Save failed', 'error') }
  finally { saving.value = false }
}

const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(b) { deleteTarget.value = b; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/pharmacy-profile/branches/${deleteTarget.value.id}/`)
    notify('Deleted')
    deleteDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

// ── View mode ──
const viewMode = ref('table')

// ── All-branches map ──
const allBranchesMapEl = ref(null)
let allMap = null
let allMarkers = []
let allInfoWindow = null
const { load: loadGoogleMaps } = useGoogleMaps()

const geoBranches = computed(() =>
  filtered.value.filter(b => b.latitude != null && b.longitude != null)
)

function buildMapContent(b) {
  return `<div style="min-width:180px;font-family:sans-serif">
    <div style="font-weight:600;font-size:14px;margin-bottom:4px">${b.is_main ? '⭐ ' : ''}${b.name}</div>
    ${b.address ? `<div style="font-size:12px;color:#555;margin-bottom:4px">${b.address}</div>` : ''}
    ${b.phone ? `<div style="font-size:12px;color:#555">📞 ${b.phone}</div>` : ''}
    ${b.email ? `<div style="font-size:12px;color:#555">✉ ${b.email}</div>` : ''}
    <div style="margin-top:6px">
      <span style="display:inline-block;padding:2px 8px;border-radius:8px;font-size:11px;font-weight:500;background:${b.is_active ? '#e8f5e9' : '#fafafa'};color:${b.is_active ? '#2e7d32' : '#9e9e9e'}">
        ${b.is_active ? '● Active' : '● Inactive'}
      </span>
    </div>
  </div>`
}

async function initAllBranchesMap() {
  try {
    await loadGoogleMaps()
  } catch { return }
  await nextTick()
  const el = allBranchesMapEl.value
  if (!el || !window.google?.maps) return

  const gbs = geoBranches.value
  if (!gbs.length) return

  // Calculate bounds
  const bounds = new google.maps.LatLngBounds()
  gbs.forEach(b => bounds.extend({ lat: Number(b.latitude), lng: Number(b.longitude) }))

  allMap = new google.maps.Map(el, {
    center: bounds.getCenter(),
    zoom: 12,
    mapTypeControl: true,
    mapTypeControlOptions: { position: google.maps.ControlPosition.TOP_RIGHT },
    streetViewControl: false,
    fullscreenControl: true,
    styles: [
      { featureType: 'poi', stylers: [{ visibility: 'off' }] },
      { featureType: 'transit', stylers: [{ visibility: 'simplified' }] },
    ],
  })

  allInfoWindow = new google.maps.InfoWindow()

  // Add markers
  allMarkers = gbs.map(b => {
    const marker = new google.maps.Marker({
      position: { lat: Number(b.latitude), lng: Number(b.longitude) },
      map: allMap,
      title: b.name,
      icon: {
        url: pinIcon,
        scaledSize: new google.maps.Size(b.is_main ? 48 : 38, b.is_main ? 48 : 38),
        anchor: new google.maps.Point(b.is_main ? 24 : 19, b.is_main ? 48 : 38),
      },
      animation: google.maps.Animation.DROP,
      branchId: b.id,
    })

    marker.addListener('click', () => {
      allInfoWindow.setContent(buildMapContent(b))
      allInfoWindow.open(allMap, marker)
    })

    return marker
  })

  // Fit bounds with padding
  if (gbs.length === 1) {
    allMap.setCenter({ lat: Number(gbs[0].latitude), lng: Number(gbs[0].longitude) })
    allMap.setZoom(15)
  } else {
    allMap.fitBounds(bounds, { top: 40, bottom: 40, left: 40, right: 40 })
  }
}

function panToMarker(branch) {
  if (!allMap) return
  const pos = { lat: Number(branch.latitude), lng: Number(branch.longitude) }
  allMap.panTo(pos)
  allMap.setZoom(16)
  const marker = allMarkers.find(m => m.branchId === branch.id)
  if (marker && allInfoWindow) {
    allInfoWindow.setContent(buildMapContent(branch))
    allInfoWindow.open(allMap, marker)
  }
}

function destroyMapMarkers() {
  allMarkers.forEach(m => m.setMap(null))
  allMarkers = []
  if (allInfoWindow) { allInfoWindow.close(); allInfoWindow = null }
  allMap = null
}

// Re-init map when switching to map view or when branches change
watch(viewMode, async (v) => {
  if (v === 'map') {
    destroyMapMarkers()
    await nextTick()
    await initAllBranchesMap()
  }
})

watch(geoBranches, async () => {
  if (viewMode.value === 'map') {
    destroyMapMarkers()
    await nextTick()
    await initAllBranchesMap()
  }
})

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.branches-map { width: 100%; height: 520px; min-height: 400px; background: #f5f5f5; }
@media (min-width: 960px) { .branches-map { height: 620px; } }
</style>
