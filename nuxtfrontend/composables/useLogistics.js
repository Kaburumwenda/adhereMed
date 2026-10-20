// Shared helpers for the Warehouse Transport & Logistics workspace.
// All endpoints live under /api/logistics/.

export const SHIPMENT_STATUS_META = {
  draft: { label: 'Draft', color: 'grey', icon: 'mdi-file-outline', pct: 6 },
  planned: { label: 'Planned', color: 'indigo', icon: 'mdi-calendar-clock', pct: 16 },
  assigned: { label: 'Assigned', color: 'blue', icon: 'mdi-account-check-outline', pct: 30 },
  picked_up: { label: 'Picked up', color: 'cyan', icon: 'mdi-package-variant-closed-check', pct: 44 },
  in_transit: { label: 'In transit', color: 'teal', icon: 'mdi-truck-fast-outline', pct: 60 },
  out_for_delivery: { label: 'Out for delivery', color: 'amber', icon: 'mdi-map-marker-path', pct: 78 },
  delivered: { label: 'Delivered', color: 'success', icon: 'mdi-check-decagram', pct: 100 },
  failed: { label: 'Failed', color: 'error', icon: 'mdi-alert-circle-outline', pct: 100 },
  cancelled: { label: 'Cancelled', color: 'grey-darken-2', icon: 'mdi-cancel', pct: 100 },
  returned: { label: 'Returned', color: 'deep-orange', icon: 'mdi-backup-restore', pct: 100 },
}

export const MOVEMENT_TYPES = [
  { value: 'transfer', label: 'Internal transfer', icon: 'mdi-swap-horizontal-bold', color: 'indigo' },
  { value: 'customer_delivery', label: 'Customer delivery', icon: 'mdi-account-arrow-right-outline', color: 'teal' },
  { value: 'supplier_pickup', label: 'Supplier pickup', icon: 'mdi-truck-arrow-left-outline', color: 'amber' },
  { value: 'customer_return', label: 'Customer return', icon: 'mdi-keyboard-return', color: 'deep-orange' },
  { value: 'supplier_return', label: 'Return to supplier', icon: 'mdi-undo-variant', color: 'red' },
  { value: 'intercompany', label: 'Intercompany', icon: 'mdi-office-building-marker-outline', color: 'purple' },
]

export const PRIORITY_META = {
  low: { label: 'Low', color: 'grey', icon: 'mdi-arrow-down' },
  normal: { label: 'Normal', color: 'blue', icon: 'mdi-equal' },
  high: { label: 'High', color: 'amber', icon: 'mdi-arrow-up' },
  urgent: { label: 'Urgent', color: 'error', icon: 'mdi-alert-decagram' },
}

export const VEHICLE_TYPE_ICON = {
  lorry: 'mdi-truck-cargo-container',
  truck: 'mdi-truck',
  van: 'mdi-van-utility',
  pickup: 'mdi-car-pickup',
  refrigerated: 'mdi-snowflake',
  motorbike: 'mdi-motorbike',
  bicycle: 'mdi-bicycle',
  other: 'mdi-truck-outline',
}

export const VEHICLE_STATUS_META = {
  available: { label: 'Available', color: 'success' },
  in_use: { label: 'In use', color: 'blue' },
  maintenance: { label: 'Maintenance', color: 'amber' },
  retired: { label: 'Retired', color: 'grey' },
}

export const DRIVER_STATUS_META = {
  available: { label: 'Available', color: 'success' },
  on_trip: { label: 'On trip', color: 'blue' },
  off_duty: { label: 'Off duty', color: 'grey' },
  suspended: { label: 'Suspended', color: 'error' },
}

export function shipmentStatus(status) {
  return SHIPMENT_STATUS_META[status] || { label: status, color: 'grey', icon: 'mdi-help-circle', pct: 0 }
}

export function movementType(type) {
  return MOVEMENT_TYPES.find((m) => m.value === type) || {
    value: type, label: type, icon: 'mdi-truck-outline', color: 'grey',
  }
}

export function priorityMeta(p) {
  return PRIORITY_META[p] || PRIORITY_META.normal
}

export function useLogistics() {
  const { $api } = useNuxtApp()
  const base = '/logistics'

  const num = (v) => Number(v) || 0

  return {
    base,
    // ── metadata helpers (convenient when destructured) ────────────
    shipmentStatus,
    movementType,
    priorityMeta,
    formatHours,
    relativeTime,
    countdown,

    // ── reads ──────────────────────────────────────────────────────
    shipmentStats: (params = {}) => $api.get(`${base}/shipments/stats/`, { params }),
    shipmentBoard: (params = {}) => $api.get(`${base}/shipments/board/`, { params }),
    shipments: (params = {}) => $api.get(`${base}/shipments/`, { params }),
    shipment: (id) => $api.get(`${base}/shipments/${id}/`),
    expiringCompliance: () => $api.get(`${base}/shipments/expiring/`),

    vehicleStats: () => $api.get(`${base}/vehicles/stats/`),
    vehicles: (params = {}) => $api.get(`${base}/vehicles/`, { params }),

    driverStats: () => $api.get(`${base}/drivers/stats/`),
    drivers: (params = {}) => $api.get(`${base}/drivers/`, { params }),

    carrierStats: () => $api.get(`${base}/carriers/stats/`),
    carriers: (params = {}) => $api.get(`${base}/carriers/`, { params }),

    zones: (params = {}) => $api.get(`${base}/zones/`, { params }),

    routeStats: () => $api.get(`${base}/routes/stats/`),
    routes: (params = {}) => $api.get(`${base}/routes/`, { params }),

    // ── writes ─────────────────────────────────────────────────────
    assign: (id, payload) => $api.post(`${base}/shipments/${id}/assign/`, payload),
    pickup: (id, payload = {}) => $api.post(`${base}/shipments/${id}/pickup/`, payload),
    depart: (id, payload = {}) => $api.post(`${base}/shipments/${id}/depart/`, payload),
    outForDelivery: (id) => $api.post(`${base}/shipments/${id}/out_for_delivery/`),
    deliver: (id, payload = {}) => $api.post(`${base}/shipments/${id}/deliver/`, payload),
    failShipment: (id, payload = {}) => $api.post(`${base}/shipments/${id}/fail/`, payload),
    cancelShipment: (id, payload = {}) => $api.post(`${base}/shipments/${id}/cancel/`, payload),
    addEvent: (id, payload) => $api.post(`${base}/shipments/${id}/add-event/`, payload),
    fromTransfer: (transferId) => $api.post(`${base}/shipments/from-transfer/${transferId}/`),

    setVehicleStatus: (id, status) => $api.post(`${base}/vehicles/${id}/set-status/`, { status }),
    setDriverStatus: (id, status) => $api.post(`${base}/drivers/${id}/set-status/`, { status }),

    optimizeRoute: (id) => $api.post(`${base}/routes/${id}/optimize/`),
    dispatchRoute: (id) => $api.post(`${base}/routes/${id}/dispatch/`),
    completeRoute: (id) => $api.post(`${base}/routes/${id}/complete/`),

    num,
  }
}

/** Reactive clock used for "time ago" style labels. */
export function useNow(intervalMs = 60000) {
  const now = ref(Date.now())
  let timer = null
  onMounted(() => {
    timer = setInterval(() => { now.value = Date.now() }, intervalMs)
  })
  onBeforeUnmount(() => { if (timer) clearInterval(timer) })
  return now
}

export function formatHours(hours) {
  const h = Number(hours) || 0
  if (h < 1) return `${Math.round(h * 60)}m`
  if (h < 24) return `${Math.round(h)}h`
  const d = Math.floor(h / 24)
  return `${d}d ${Math.round(h % 24)}h`
}

export function relativeTime(value, nowMs = Date.now()) {
  if (!value) return '—'
  const t = new Date(value).getTime()
  if (Number.isNaN(t)) return '—'
  const diff = Math.abs(nowMs - t)
  const mins = Math.round(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  if (days < 30) return `${days}d ago`
  const months = Math.round(days / 30)
  return `${months}mo ago`
}

export function countdown(value, nowMs = Date.now()) {
  if (!value) return null
  const t = new Date(value).getTime()
  if (Number.isNaN(t)) return null
  const diff = t - nowMs
  const abs = Math.abs(diff)
  const mins = Math.round(abs / 60000)
  let text
  if (mins < 60) text = `${mins}m`
  else if (mins < 1440) text = `${Math.round(mins / 60)}h`
  else text = `${Math.round(mins / 1440)}d`
  return { overdue: diff < 0, text }
}

export function useLogisticsNav() {
  const items = [
    { icon: 'mdi-view-dashboard-variant-outline', label: 'Command Center', path: '/ims/logistics' },
    { icon: 'mdi-truck-fast-outline', label: 'Shipments', path: '/ims/logistics/shipments' },
    { icon: 'mdi-clipboard-text-outline', label: 'Dispatch Board', path: '/ims/logistics/dispatch' },
    { icon: 'mdi-map-marker-path', label: 'Route Planning', path: '/ims/logistics/routes' },
    { icon: 'mdi-crosshairs-gps', label: 'Live Tracking', path: '/ims/logistics/tracking' },
    { icon: 'mdi-truck-cargo-container', label: 'Fleet & Vehicles', path: '/ims/logistics/fleet' },
    { icon: 'mdi-account-tie-hat-outline', label: 'Drivers', path: '/ims/logistics/drivers' },
    { icon: 'mdi-handshake-outline', label: 'Carriers & 3PL', path: '/ims/logistics/carriers' },
    { icon: 'mdi-chart-box-outline', label: 'Analytics', path: '/ims/logistics/analytics' },
    { icon: 'mdi-cog-outline', label: 'Zones & Rates', path: '/ims/logistics/settings' },
  ]
  return { items }
}

