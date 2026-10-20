// Shared helpers for the Customer CRM workspace. All endpoints under /api/crm/.
import { formatMoney } from '~/utils/format'

export const LIFECYCLE_META = {
  lead: { label: 'Lead', color: 'grey', icon: 'mdi-account-plus-outline', pct: 15 },
  prospect: { label: 'Prospect', color: 'info', icon: 'mdi-account-search-outline', pct: 35 },
  active: { label: 'Active', color: 'success', icon: 'mdi-account-check-outline', pct: 75 },
  at_risk: { label: 'At risk', color: 'warning', icon: 'mdi-account-alert-outline', pct: 45 },
  dormant: { label: 'Dormant', color: 'grey-darken-1', icon: 'mdi-account-clock-outline', pct: 20 },
  churned: { label: 'Churned', color: 'error', icon: 'mdi-account-off-outline', pct: 5 },
}

export const TIER_META = {
  bronze: { label: 'Bronze', color: '#b45309', icon: 'mdi-medal-outline' },
  silver: { label: 'Silver', color: '#64748b', icon: 'mdi-medal' },
  gold: { label: 'Gold', color: '#d97706', icon: 'mdi-trophy-outline' },
  platinum: { label: 'Platinum', color: '#7c3aed', icon: 'mdi-crown-outline' },
}

export const TICKET_STATUS_META = {
  open: { label: 'Open', color: 'error', icon: 'mdi-alert-circle-outline' },
  in_progress: { label: 'In progress', color: 'info', icon: 'mdi-progress-clock' },
  waiting: { label: 'Waiting', color: 'amber', icon: 'mdi-pause-circle-outline' },
  resolved: { label: 'Resolved', color: 'success', icon: 'mdi-check-circle-outline' },
  closed: { label: 'Closed', color: 'grey', icon: 'mdi-archive-outline' },
}

// NOTE: prefixed with CRM_ because `useLogistics.js` already exports
// PRIORITY_META / priorityMeta and Nuxt auto-imports would collide.
export const CRM_PRIORITY_META = {
  low: { label: 'Low', color: 'grey', icon: 'mdi-arrow-down' },
  normal: { label: 'Normal', color: 'blue', icon: 'mdi-equal' },
  high: { label: 'High', color: 'amber', icon: 'mdi-arrow-up' },
  urgent: { label: 'Urgent', color: 'error', icon: 'mdi-alert-decagram' },
}

export const STAGE_META = {
  new: { label: 'New', color: 'grey', icon: 'mdi-star-outline', pct: 10 },
  qualified: { label: 'Qualified', color: 'info', icon: 'mdi-check-decagram-outline', pct: 30 },
  proposal: { label: 'Proposal', color: 'primary', icon: 'mdi-file-document-outline', pct: 50 },
  negotiation: { label: 'Negotiation', color: 'amber', icon: 'mdi-handshake-outline', pct: 70 },
  won: { label: 'Won', color: 'success', icon: 'mdi-trophy', pct: 100 },
  lost: { label: 'Lost', color: 'error', icon: 'mdi-close-octagon-outline', pct: 100 },
}

export const INTERACTION_META = {
  call: { label: 'Call', icon: 'mdi-phone-outline', color: 'blue' },
  email: { label: 'Email', icon: 'mdi-email-outline', color: 'indigo' },
  sms: { label: 'SMS', icon: 'mdi-message-text-outline', color: 'cyan' },
  whatsapp: { label: 'WhatsApp', icon: 'mdi-whatsapp', color: 'success' },
  meeting: { label: 'Meeting', icon: 'mdi-account-group-outline', color: 'purple' },
  visit: { label: 'Visit', icon: 'mdi-map-marker-outline', color: 'teal' },
  note: { label: 'Note', icon: 'mdi-note-text-outline', color: 'grey' },
  complaint: { label: 'Complaint', icon: 'mdi-alert-outline', color: 'error' },
}

export const CAMPAIGN_STATUS_META = {
  draft: { label: 'Draft', color: 'grey', icon: 'mdi-file-outline' },
  scheduled: { label: 'Scheduled', color: 'info', icon: 'mdi-calendar-clock' },
  running: { label: 'Running', color: 'success', icon: 'mdi-play-circle-outline' },
  completed: { label: 'Completed', color: 'primary', icon: 'mdi-check-decagram' },
  paused: { label: 'Paused', color: 'amber', icon: 'mdi-pause-circle-outline' },
  cancelled: { label: 'Cancelled', color: 'error', icon: 'mdi-cancel' },
}

export const CHANNEL_META = {
  email: { label: 'Email', icon: 'mdi-email-outline' },
  sms: { label: 'SMS', icon: 'mdi-message-text-outline' },
  whatsapp: { label: 'WhatsApp', icon: 'mdi-whatsapp' },
  call: { label: 'Call round', icon: 'mdi-phone-outline' },
  in_store: { label: 'In-store', icon: 'mdi-storefront-outline' },
  social: { label: 'Social', icon: 'mdi-share-variant-outline' },
}

export function lifecycleMeta(v) {
  return LIFECYCLE_META[v] || { label: v || '—', color: 'grey', icon: 'mdi-help-circle', pct: 0 }
}

export function tierMeta(v) {
  return TIER_META[v] || { label: v || '—', color: '#64748b', icon: 'mdi-medal-outline' }
}

export function ticketStatus(v) {
  return TICKET_STATUS_META[v] || { label: v || '—', color: 'grey', icon: 'mdi-help-circle' }
}

export function crmPriority(v) {
  return CRM_PRIORITY_META[v] || CRM_PRIORITY_META.normal
}

export function stageMeta(v) {
  return STAGE_META[v] || { label: v || '—', color: 'grey', icon: 'mdi-help-circle', pct: 0 }
}

export function interactionMeta(v) {
  return INTERACTION_META[v] || { label: v || '—', icon: 'mdi-note-outline', color: 'grey' }
}

export function campaignStatus(v) {
  return CAMPAIGN_STATUS_META[v] || { label: v || '—', color: 'grey', icon: 'mdi-help-circle' }
}

export function channelMeta(v) {
  return CHANNEL_META[v] || { label: v || '—', icon: 'mdi-send-outline' }
}

/** Health score → colour token. */
export function healthColor(score) {
  const n = Number(score) || 0
  if (n >= 75) return 'success'
  if (n >= 50) return 'warning'
  return 'error'
}

/** Churn risk → colour token. */
export function riskColor(risk) {
  const n = Number(risk) || 0
  if (n >= 60) return 'error'
  if (n >= 35) return 'warning'
  return 'success'
}

export function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('')
}

/** Deterministic avatar colour from a name. */
const AVATAR_COLORS = ['#0d9488', '#7c3aed', '#2563eb', '#d97706', '#dc2626', '#0891b2', '#db2777', '#65a30d']
export function avatarColor(name) {
  const s = String(name || '')
  let h = 0
  for (let i = 0; i < s.length; i += 1) h = (h * 31 + s.charCodeAt(i)) % 9973
  return AVATAR_COLORS[h % AVATAR_COLORS.length]
}

export function useCrm() {
  const { $api } = useNuxtApp()
  const base = '/crm'
  const unpack = (r) => r.data?.results || r.data || []

  return {
    base,
    unpack,
    // customers
    customers: (params = {}) => $api.get(`${base}/customers/`, { params }),
    customerStats: (params = {}) => $api.get(`${base}/customers/stats/`, { params }),
    customer360: (id) => $api.get(`${base}/customers/${id}/detail_360/`),
    ensureProfile: (id) => $api.post(`${base}/customers/${id}/ensure-profile/`),
    leaderboard: (limit = 10) => $api.get(`${base}/customers/leaderboard/`, { params: { limit } }),
    birthdays: (days = 30) => $api.get(`${base}/customers/birthdays/`, { params: { days } }),
    bulkAssignSegment: (payload) => $api.post(`${base}/customers/bulk-assign-segment/`, payload),

    // profiles
    profiles: (params = {}) => $api.get(`${base}/profiles/`, { params }),
    recomputeHealth: (id) => $api.post(`${base}/profiles/${id}/recompute-health/`),

    // segments & tags
    segments: (params = {}) => $api.get(`${base}/segments/`, { params }),
    segmentMembers: (id) => $api.get(`${base}/segments/${id}/members/`),
    tags: (params = {}) => $api.get(`${base}/tags/`, { params }),

    // interactions
    interactions: (params = {}) => $api.get(`${base}/interactions/`, { params }),
    interactionStats: (params = {}) => $api.get(`${base}/interactions/stats/`, { params }),

    // tickets
    tickets: (params = {}) => $api.get(`${base}/tickets/`, { params }),
    ticketStats: (params = {}) => $api.get(`${base}/tickets/stats/`, { params }),
    resolveTicket: (id, payload = {}) => $api.post(`${base}/tickets/${id}/resolve/`, payload),
    assignTicket: (id, payload) => $api.post(`${base}/tickets/${id}/assign/`, payload),
    setTicketStatus: (id, status) => $api.post(`${base}/tickets/${id}/set-status/`, { status }),

    // opportunities
    opportunities: (params = {}) => $api.get(`${base}/opportunities/`, { params }),
    opportunityStats: (params = {}) => $api.get(`${base}/opportunities/stats/`, { params }),
    moveStage: (id, stage, lostReason) =>
      $api.post(`${base}/opportunities/${id}/move-stage/`, { stage, lost_reason: lostReason }),

    // campaigns
    campaigns: (params = {}) => $api.get(`${base}/campaigns/`, { params }),
    campaignStats: (params = {}) => $api.get(`${base}/campaigns/stats/`, { params }),

    // tasks
    tasks: (params = {}) => $api.get(`${base}/tasks/`, { params }),
    taskStats: (params = {}) => $api.get(`${base}/tasks/stats/`, { params }),
    completeTask: (id) => $api.post(`${base}/tasks/${id}/complete/`),

    // feedback
    feedback: (params = {}) => $api.get(`${base}/feedback/`, { params }),
    feedbackStats: (params = {}) => $api.get(`${base}/feedback/stats/`, { params }),

    // loyalty
    points: (params = {}) => $api.get(`${base}/points/`, { params }),
    pointsStats: (params = {}) => $api.get(`${base}/points/stats/`, { params }),

    formatMoney,
  }
}
