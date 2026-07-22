<template>
  <div class="cgm-wrap">
    <div ref="el" class="cgm-map" :style="{ height: height + 'px' }" />
    <div v-if="loading" class="cgm-loading">
      <v-progress-circular indeterminate color="teal" size="32" width="3" />
    </div>
    <div v-if="error" class="cgm-error">
      <v-icon icon="mdi-map-marker-remove" size="20" class="mr-1" />
      <span class="text-body-2">{{ error }}</span>
    </div>
    <div v-if="legend.length" class="cgm-legend">
      <div v-for="l in legend" :key="l.label" class="cgm-legend-item">
        <span class="cgm-legend-dot" :style="{ background: l.color }" />
        <span class="text-caption">{{ l.label }}</span>
      </div>
    </div>
    <div v-if="markers.length" class="cgm-count">
      <v-icon icon="mdi-map-marker-multiple" size="14" class="mr-1" />
      <span class="text-caption font-weight-bold">{{ markers.length }} live check-ins</span>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  markers: { type: Array, default: () => [] }, // { lat, lng, title, color, label, info }
  center: { type: Object, default: () => ({ lat: -1.2921, lng: 36.8219 }) },
  zoom: { type: Number, default: 12 },
  height: { type: Number, default: 460 },
  fit: { type: Boolean, default: true },
})

const { load } = useGoogleMaps()

const el = ref(null)
const loading = ref(true)
const error = ref('')
let map = null
let infoWin = null
let gMarkers = []
let darkObs = null

const legend = computed(() => {
  const out = []
  const seen = new Set()
  for (const m of props.markers) {
    const key = m.color || '#0d9488'
    if (!seen.has(key)) { seen.add(key); out.push({ color: key, label: m.legend || m.title || 'Check-in' }) }
  }
  return out.slice(0, 6)
})

function pinSvg(color, live = false) {
  const dot = live ? '<circle cx="17" cy="15" r="5.5" fill="#ffffff"/>' : '<circle cx="17" cy="15" r="4.5" fill="#ffffff" fill-opacity="0.85"/>'
  const ring = live ? '<circle cx="17" cy="15" r="5.5" fill="none" stroke="#ffffff" stroke-width="1.5"/>' : ''
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="34" height="46" viewBox="0 0 34 46">
    <path fill="${color}" stroke="#ffffff" stroke-width="2.2" d="M17 1C8.5 1 1.6 7.9 1.6 16.4c0 11.1 15.4 28.2 15.4 28.2s15.4-17.1 15.4-28.2C32.4 7.9 25.5 1 17 1z"/>
    ${ring}${dot}
  </svg>`
  return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg)
}

const DARK_STYLE = [
  { elementType: 'geometry', stylers: [{ color: '#1e293b' }] },
  { elementType: 'labels.text.stroke', stylers: [{ color: '#1e293b' }] },
  { elementType: 'labels.text.fill', stylers: [{ color: '#94a3b8' }] },
  { featureType: 'administrative.locality', elementType: 'labels.text.fill', stylers: [{ color: '#cbd5e1' }] },
  { featureType: 'poi', elementType: 'labels', stylers: [{ visibility: 'off' }] },
  { featureType: 'road', elementType: 'geometry', stylers: [{ color: '#334155' }] },
  { featureType: 'road', elementType: 'labels.text.fill', stylers: [{ color: '#94a3b8' }] },
  { featureType: 'transit', elementType: 'geometry', stylers: [{ color: '#334155' }] },
  { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#0f172a' }] },
  { featureType: 'water', elementType: 'labels.text.fill', stylers: [{ color: '#64748b' }] },
  { featureType: 'landscape', elementType: 'geometry', stylers: [{ color: '#1e293b' }] },
]

function isDark() {
  return typeof document !== 'undefined' &&
    document.documentElement.classList.contains('v-theme--dark')
}

function applyTheme() {
  if (!map) return
  map.setOptions({ styles: isDark() ? DARK_STYLE : null })
}

async function init() {
  try {
    const google = await load()
    if (!el.value) return
    map = new google.maps.Map(el.value, {
      center: props.center,
      zoom: props.zoom,
      mapTypeControl: false,
      streetViewControl: false,
      fullscreenControl: true,
      gestureHandling: 'greedy',
      styles: isDark() ? DARK_STYLE : null,
    })
    infoWin = new google.maps.InfoWindow()
    render()
    // observe theme changes
    darkObs = new MutationObserver(applyTheme)
    darkObs.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
    setTimeout(() => { try { google.maps.event.trigger(map, 'resize') } catch {} }, 120)
  } catch (e) {
    error.value = 'Could not load the map. Check your connection.'
  } finally {
    loading.value = false
  }
}

function render() {
  if (!map || !window.google) return
  const google = window.google
  gMarkers.forEach(m => m.setMap(null))
  gMarkers = []
  const points = []
  for (const m of props.markers) {
    if (m.lat == null || m.lng == null) continue
    const marker = new google.maps.Marker({
      position: { lat: m.lat, lng: m.lng },
      map,
      title: m.title || '',
      icon: { url: pinSvg(m.color || '#0d9488', m.live), scaledSize: new google.maps.Size(34, 46), anchor: new google.maps.Point(17, 44) },
      zIndex: m.live ? 999 : 1,
      animation: m.live ? google.maps.Animation.BOUNCE : null,
    })
    if (m.info) {
      marker.addListener('click', () => {
        infoWin.setContent(m.info)
        infoWin.open(map, marker)
      })
    }
    gMarkers.push(marker)
    points.push({ lat: m.lat, lng: m.lng })
  }
  if (props.fit && points.length) {
    if (points.length === 1) {
      map.setCenter(points[0])
      map.setZoom(Math.max(props.zoom, 13))
    } else {
      const bounds = new google.maps.LatLngBounds()
      points.forEach(p => bounds.extend(p))
      map.fitBounds(bounds, 60)
    }
  } else {
    map.setCenter(props.center)
    map.setZoom(props.zoom)
  }
}

onMounted(init)
onBeforeUnmount(() => {
  if (darkObs) darkObs.disconnect()
  gMarkers.forEach(m => { try { m.setMap(null) } catch {} })
  gMarkers = []
  if (infoWin) { try { infoWin.close() } catch {} }
  map = null
})
watch(() => props.markers, render, { deep: true })
watch(() => props.center, () => { if (map) map.setCenter(props.center) })
</script>

<style scoped>
.cgm-wrap { position: relative; width: 100%; }
.cgm-map { width: 100%; border-radius: 16px; overflow: hidden; border: 1px solid rgba(15,23,42,0.08); }
:global(.v-theme--dark .cgm-map) { border-color: rgba(255,255,255,0.08); }
.cgm-loading, .cgm-error {
  position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
  flex-direction: column; gap: 8px; background: rgba(255,255,255,0.6); border-radius: 16px;
}
:global(.v-theme--dark .cgm-loading), :global(.v-theme--dark .cgm-error) {
  background: rgba(15,23,42,0.55);
}
.cgm-error { color: #b91c1c; }
.cgm-legend {
  position: absolute; left: 12px; bottom: 12px; z-index: 2;
  display: flex; flex-direction: column; gap: 4px;
  padding: 8px 10px; border-radius: 10px;
  background: rgba(255,255,255,0.92);
  border: 1px solid rgba(15,23,42,0.08);
  box-shadow: 0 2px 8px rgba(15,23,42,0.08);
}
:global(.v-theme--dark .cgm-legend) {
  background: rgba(30,41,59,0.92); border-color: rgba(255,255,255,0.1); color: #e2e8f0;
}
.cgm-legend-item { display: flex; align-items: center; gap: 6px; }
.cgm-legend-dot { width: 10px; height: 10px; border-radius: 50%; box-shadow: 0 0 0 2px rgba(255,255,255,0.6); }
.cgm-count {
  position: absolute; right: 12px; top: 12px; z-index: 2;
  display: flex; align-items: center;
  padding: 5px 10px; border-radius: 999px;
  background: rgba(13,148,136,0.92); color: #fff;
  box-shadow: 0 2px 8px rgba(13,148,136,0.3);
}
</style>
