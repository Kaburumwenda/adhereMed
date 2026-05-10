<template>
  <v-menu v-model="open" :close-on-content-click="false" location="bottom start"
          offset="4" max-height="320" :open-on-click="false" :open-on-focus="false">
    <template #activator="{ props: menuProps }">
      <v-text-field
        v-bind="menuProps"
        v-model="text"
        :label="label"
        :placeholder="placeholder"
        :variant="variant"
        :density="density"
        :rounded="rounded"
        :prepend-inner-icon="prependInnerIcon"
        :error-messages="errorMessages"
        :hint="hint"
        :persistent-hint="!!hint"
        :loading="loading"
        autocomplete="off"
        @update:model-value="onInput"
        @focus="onFocus"
        @keydown.down.prevent="moveSel(1)"
        @keydown.up.prevent="moveSel(-1)"
        @keydown.enter.prevent="pickSelected"
        @keydown.esc="open = false"
      >
        <template #append-inner>
          <v-btn v-if="text" icon="mdi-close" size="x-small" variant="text"
                 @click.stop="clear" />
          <v-btn icon="mdi-crosshairs-gps" size="x-small" variant="text"
                 :loading="locating" :title="'Use my current location'"
                 @click.stop="useGps" />
        </template>
      </v-text-field>
    </template>

    <v-list density="compact" class="hc-addr-list">
      <v-list-item v-if="loading && !suggestions.length">
        <template #prepend>
          <v-progress-circular size="16" width="2" indeterminate color="teal" />
        </template>
        <v-list-item-title class="text-body-2 text-medium-emphasis">
          Searching…
        </v-list-item-title>
      </v-list-item>

      <v-list-item v-else-if="!suggestions.length && text.length >= minChars">
        <v-list-item-title class="text-body-2 text-medium-emphasis">
          No matches. Keep typing or enter manually.
        </v-list-item-title>
      </v-list-item>

      <v-list-item v-for="(s, i) in suggestions" :key="s.place_id"
                   :active="i === selected"
                   @click="pick(s)">
        <template #prepend>
          <v-icon icon="mdi-map-marker" size="18" color="teal" />
        </template>
        <v-list-item-title class="text-body-2">{{ shortLabel(s) }}</v-list-item-title>
        <v-list-item-subtitle class="text-caption">
          {{ longLabel(s) }}
        </v-list-item-subtitle>
      </v-list-item>

      <v-list-item v-if="suggestions.length" class="hc-addr-attribution">
        <v-list-item-subtitle class="text-caption text-medium-emphasis">
          Powered by OpenStreetMap
        </v-list-item-subtitle>
      </v-list-item>
    </v-list>
  </v-menu>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, default: 'Address' },
  placeholder: { type: String, default: 'Start typing an address…' },
  variant: { type: String, default: 'outlined' },
  density: { type: String, default: 'comfortable' },
  rounded: { type: String, default: 'lg' },
  prependInnerIcon: { type: String, default: 'mdi-map-marker' },
  errorMessages: { type: [String, Array], default: () => [] },
  hint: { type: String, default: '' },
  countryCodes: { type: String, default: 'ke,ug,tz,rw' }, // bias to East Africa
  minChars: { type: Number, default: 3 }
})
const emit = defineEmits(['update:modelValue', 'select'])

const text = ref(props.modelValue || '')
const open = ref(false)
const loading = ref(false)
const locating = ref(false)
const suggestions = ref([])
const selected = ref(-1)
let abort = null
let debounceId = null

watch(() => props.modelValue, (v) => {
  if (v !== text.value) text.value = v || ''
})

function emitText(v) {
  emit('update:modelValue', v)
}

function onInput(v) {
  text.value = v || ''
  emitText(text.value)
  selected.value = -1
  if (debounceId) clearTimeout(debounceId)
  if (!text.value || text.value.length < props.minChars) {
    suggestions.value = []
    open.value = false
    return
  }
  debounceId = setTimeout(() => fetchSuggestions(text.value), 280)
}

function onFocus() {
  if (suggestions.value.length) open.value = true
}

async function fetchSuggestions(q) {
  if (abort) abort.abort()
  abort = new AbortController()
  loading.value = true
  open.value = true
  try {
    const url = new URL('https://nominatim.openstreetmap.org/search')
    url.searchParams.set('q', q)
    url.searchParams.set('format', 'jsonv2')
    url.searchParams.set('addressdetails', '1')
    url.searchParams.set('limit', '6')
    if (props.countryCodes) url.searchParams.set('countrycodes', props.countryCodes)
    const res = await fetch(url.toString(), {
      signal: abort.signal,
      headers: { 'Accept-Language': 'en' }
    })
    if (!res.ok) throw new Error('lookup failed')
    suggestions.value = await res.json()
  } catch (e) {
    if (e.name !== 'AbortError') suggestions.value = []
  } finally {
    loading.value = false
  }
}

function shortLabel(s) {
  const a = s.address || {}
  const street = [a.house_number, a.road].filter(Boolean).join(' ')
  return street || a.suburb || a.neighbourhood || a.village
       || a.town || a.city || s.name || s.display_name.split(',')[0]
}
function longLabel(s) {
  return s.display_name
}

function pick(s) {
  text.value = s.display_name
  emitText(text.value)
  emit('select', {
    display_name: s.display_name,
    lat: parseFloat(s.lat),
    lon: parseFloat(s.lon),
    address: s.address || {}
  })
  open.value = false
}
function pickSelected() {
  if (selected.value >= 0 && suggestions.value[selected.value]) {
    pick(suggestions.value[selected.value])
  }
}
function moveSel(d) {
  if (!suggestions.value.length) return
  open.value = true
  selected.value = (selected.value + d + suggestions.value.length) % suggestions.value.length
}
function clear() {
  text.value = ''
  emitText('')
  suggestions.value = []
  open.value = false
}

async function useGps() {
  if (!navigator.geolocation) return
  locating.value = true
  navigator.geolocation.getCurrentPosition(async (pos) => {
    try {
      const { latitude, longitude } = pos.coords
      const url = new URL('https://nominatim.openstreetmap.org/reverse')
      url.searchParams.set('lat', latitude)
      url.searchParams.set('lon', longitude)
      url.searchParams.set('format', 'jsonv2')
      url.searchParams.set('addressdetails', '1')
      const r = await fetch(url.toString(), { headers: { 'Accept-Language': 'en' } })
      const data = await r.json()
      if (data?.display_name) {
        text.value = data.display_name
        emitText(text.value)
        emit('select', {
          display_name: data.display_name,
          lat: parseFloat(data.lat),
          lon: parseFloat(data.lon),
          address: data.address || {}
        })
      }
    } finally {
      locating.value = false
    }
  }, () => { locating.value = false }, { enableHighAccuracy: true, timeout: 10000 })
}
</script>

<style scoped>
.hc-addr-list {
  background: white;
  border-radius: 12px;
  border: 1px solid rgba(15,23,42,0.08);
  box-shadow: 0 12px 28px -14px rgba(15,23,42,0.25);
  min-width: 320px;
}
:global(.v-theme--dark) .hc-addr-list {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.1);
}
.hc-addr-attribution { pointer-events: none; opacity: 0.7; }
</style>
