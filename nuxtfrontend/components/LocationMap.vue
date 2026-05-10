<template>
  <div ref="container" :style="{ height: height + 'px', width: '100%' }"
       class="rounded-lg overflow-hidden hc-map" />
</template>

<script setup>
const props = defineProps({
  center: { type: Object, default: () => ({ lat: -1.2921, lng: 36.8219 }) },
  zoom: { type: Number, default: 15 },
  height: { type: Number, default: 300 },
  markers: {
    type: Array,
    default: () => [],
    // [{ lat, lng, title, color, popup }]
  },
})

const container = ref(null)
let map = null
let L = null
let markerLayer = null

async function ensureLeaflet() {
  if (L) return L
  if (!document.getElementById('leaflet-css')) {
    const link = document.createElement('link')
    link.id = 'leaflet-css'
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    link.crossOrigin = ''
    document.head.appendChild(link)
  }
  if (!window.L) {
    await new Promise((resolve, reject) => {
      const s = document.createElement('script')
      s.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
      s.crossOrigin = ''
      s.onload = resolve
      s.onerror = reject
      document.head.appendChild(s)
    })
  }
  L = window.L
  return L
}

function divIcon(color = '#0d9488', label = '') {
  return L.divIcon({
    className: 'hc-leaflet-pin',
    html: `<div class="hc-pin" style="background:${color}">
             <span class="hc-pin-dot"></span>
             ${label ? `<span class="hc-pin-label">${label}</span>` : ''}
           </div>`,
    iconSize: [30, 30],
    iconAnchor: [15, 30],
    popupAnchor: [0, -28],
  })
}

function render() {
  if (!map || !L) return
  if (markerLayer) {
    markerLayer.clearLayers()
  } else {
    markerLayer = L.layerGroup().addTo(map)
  }
  const points = []
  for (const m of props.markers) {
    if (m.lat == null || m.lng == null) continue
    const mk = L.marker([m.lat, m.lng], {
      icon: divIcon(m.color, m.label || ''),
      title: m.title || '',
    })
    if (m.popup) mk.bindPopup(m.popup)
    mk.addTo(markerLayer)
    points.push([m.lat, m.lng])
  }
  if (points.length === 1) {
    map.setView(points[0], props.zoom)
  } else if (points.length > 1) {
    map.fitBounds(points, { padding: [40, 40], maxZoom: 16 })
  }
}

async function init() {
  await ensureLeaflet()
  if (!container.value) return
  map = L.map(container.value, { scrollWheelZoom: false }).setView(
    [props.center.lat, props.center.lng], props.zoom
  )
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors',
    maxZoom: 19,
  }).addTo(map)
  render()
  // Some containers measure 0 on mount; nudge after one tick.
  setTimeout(() => map?.invalidateSize(), 80)
}

onMounted(init)
onBeforeUnmount(() => { try { map?.remove() } catch {} })
watch(() => props.markers, render, { deep: true })
watch(() => props.center, () => {
  if (map) map.setView([props.center.lat, props.center.lng], props.zoom)
})
</script>

<style>
.hc-map { border: 1px solid rgba(0,0,0,0.06); }
:global(.v-theme--dark) .hc-map { border-color: rgba(255,255,255,0.08); }
.hc-leaflet-pin .hc-pin {
  width: 26px; height: 26px;
  border-radius: 50% 50% 50% 0;
  transform: rotate(-45deg);
  box-shadow: 0 2px 6px rgba(0,0,0,0.35);
  border: 2px solid #fff;
  display: flex; align-items: center; justify-content: center;
  margin-left: 2px;
}
.hc-leaflet-pin .hc-pin-dot {
  width: 8px; height: 8px;
  background: #fff;
  border-radius: 50%;
  transform: rotate(45deg);
}
.hc-leaflet-pin .hc-pin-label {
  position: absolute;
  top: -22px; left: 50%;
  transform: translateX(-50%) rotate(45deg);
  background: #111;
  color: #fff;
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  white-space: nowrap;
}
</style>
