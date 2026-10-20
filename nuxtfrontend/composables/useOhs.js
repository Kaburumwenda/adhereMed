// ─────────────────────────────────────────────────────────────────────────
// useOhs — shared helpers for the Occupational Health & Safety (OHSMS)
// frontend at /ohs/*. Backs everything with the `/api/ohs/` app.
// ─────────────────────────────────────────────────────────────────────────
const OHS_BASE = '/ohs'

/** Risk band metadata — colour tokens + human labels for a 1-25 score. */
export const RISK_BANDS = {
  critical:   { label: 'Critical',   step: 5, tone: 'err',   text: '#b91c1c' },
  high:       { label: 'High',       step: 4, tone: 'warn',  text: '#9a3412' },
  medium:     { label: 'Medium',     step: 3, tone: 'warn',  text: '#b45309' },
  low:        { label: 'Low',        step: 2, tone: 'info',  text: '#3f6212' },
  negligible: { label: 'Negligible', step: 1, tone: 'ok',    text: '#15803d' },
  unrated:    { label: 'Unrated',    step: 0, tone: 'muted', text: '#64748b' },
}

/** Map a numeric score onto its band name. */
export function riskBand(score) {
  if (score === null || score === undefined) return 'unrated'
  if (score >= 20) return 'critical'
  if (score >= 15) return 'high'
  if (score >= 8) return 'medium'
  if (score >= 4) return 'low'
  return 'negligible'
}

export function riskMeta(score) {
  const band = typeof score === 'string' ? score : riskBand(score)
  return { band, ...(RISK_BANDS[band] || RISK_BANDS.unrated) }
}

/** Step 0-5 used for the heat-map cell classes. */
export function riskStep(score) {
  return riskMeta(score).step
}

/** Generic status → badge modifier. */
export function toneFor(value) {
  const v = String(value || '').toLowerCase()
  if (['closed', 'completed', 'done', 'verified', 'pass', 'compliant', 'fit',
       'implemented', 'achieved', 'on_track', 'active', 'safe', 'positive'].includes(v)) return 'ok'
  if (['in_progress', 'investigating', 'reported', 'pending', 'planned', 'draft',
       'monitoring', 'conditional', 'current', 'condition', 'partial'].includes(v)) return 'info'
  if (['overdue', 'at_risk', 'actions', 'scheduled', 'expiring', 'observation',
       'at_risk_behaviour', 'suspended'].includes(v)) return 'warn'
  if (['expired', 'failed', 'fail', 'non_compliant', 'unfit', 'off_track',
       'critical', 'rejected', 'fatality', 'major'].includes(v)) return 'err'
  if (['open', 'controlled'].includes(v)) return 'muted'
  return 'muted'
}

export function titleCase(value) {
  if (!value) return '—'
  return String(value)
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase())
}

// NOTE: `formatDate` / `formatDateTime` live in `utils/format.js`. Do not
// re-export them here — Nuxt auto-imports both folders, and duplicate names
// produce "Duplicated imports" warnings plus unpredictable resolution.
// Import them explicitly from '~/utils/format' if you need to be sure.

export function relativeDays(value) {
  if (!value) return ''
  const target = new Date(value)
  const today = new Date()
  const diff = Math.round((target.setHours(0, 0, 0, 0) - today.setHours(0, 0, 0, 0)) / 86400000)
  if (diff === 0) return 'today'
  if (diff === 1) return 'tomorrow'
  if (diff === -1) return 'yesterday'
  return diff > 0 ? `in ${diff}d` : `${Math.abs(diff)}d ago`
}

export function compactMoney(value) {
  const n = Number(value || 0)
  if (!n) return 'KES 0'
  if (n >= 1e9) return `KES ${(n / 1e9).toFixed(1)}B`
  if (n >= 1e6) return `KES ${(n / 1e6).toFixed(1)}M`
  if (n >= 1e3) return `KES ${(n / 1e3).toFixed(1)}K`
  return `KES ${n.toFixed(0)}`
}

export function initialsOf(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return (parts[0][0] + (parts[1]?.[0] || '')).toUpperCase()
}

/** Deterministic avatar hue from a name. */
export function hueOf(name) {
  let hash = 0
  for (const ch of String(name || '')) hash = (hash * 31 + ch.charCodeAt(0)) % 360
  return hash
}

/** Download an array of objects as CSV. */
export function exportCsv(filename, rows, columns) {
  if (!rows?.length) return
  const cols = columns || Object.keys(rows[0]).map((k) => ({ key: k, label: k }))
  const esc = (v) => {
    const s = v === null || v === undefined ? '' : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const csv = [
    cols.map((c) => esc(c.label)).join(','),
    ...rows.map((r) => cols.map((c) => esc(typeof c.value === 'function' ? c.value(r) : r[c.key])).join(',')),
  ].join('\n')
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export function useOhs() {
  const { $api } = useNuxtApp()

  /** Collection helper — list / create / patch / delete against /api/ohs/*. */
  function resource(path) {
    const endpoint = `${OHS_BASE}/${path}/`
    const items = ref([])
    const count = ref(0)
    const loading = ref(false)
    const saving = ref(false)
    const error = ref('')

    function normalise(data) {
      if (Array.isArray(data)) return { results: data, count: data.length }
      return { results: data?.results || [], count: data?.count ?? data?.results?.length ?? 0 }
    }

    function message(e) {
      const data = e?.response?.data
      if (data && typeof data === 'object' && !data.detail) {
        return Object.entries(data)
          .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`)
          .join(' | ')
      }
      return data?.detail || data?.message || (typeof data === 'string' ? data : null)
        || e?.message || 'Request failed.'
    }

    async function list(params = {}) {
      loading.value = true
      error.value = ''
      try {
        const { data } = await $api.get(endpoint, { params })
        const n = normalise(data)
        items.value = n.results
        count.value = n.count
        return n
      } catch (e) {
        error.value = message(e)
        items.value = []
        return { results: [], count: 0 }
      } finally {
        loading.value = false
      }
    }

    async function create(payload) {
      saving.value = true
      try {
        const { data } = await $api.post(endpoint, payload)
        items.value = [data, ...items.value]
        count.value += 1
        return data
      } finally {
        saving.value = false
      }
    }

    async function update(id, payload) {
      saving.value = true
      try {
        const { data } = await $api.patch(`${endpoint}${id}/`, payload)
        const i = items.value.findIndex((x) => x.id === id)
        if (i >= 0) items.value[i] = data
        return data
      } finally {
        saving.value = false
      }
    }

    async function remove(id) {
      saving.value = true
      try {
        await $api.delete(`${endpoint}${id}/`)
        items.value = items.value.filter((x) => x.id !== id)
        count.value = Math.max(0, count.value - 1)
        return true
      } finally {
        saving.value = false
      }
    }

    return { endpoint, items, count, loading, saving, error, list, create, update, remove, message }
  }

  /** Dashboard payload (single call). */
  async function dashboard(days = 90) {
    const { data } = await $api.get(`${OHS_BASE}/dashboard/`, { params: { days } })
    return data
  }

  /** Form option lists, cached for the session. */
  const lookups = useState('ohs-lookups', () => null)

  async function loadLookups(force = false) {
    if (lookups.value && !force) return lookups.value
    try {
      const { data } = await $api.get(`${OHS_BASE}/lookups/`)
      lookups.value = data
    } catch {
      lookups.value = lookups.value || {}
    }
    return lookups.value
  }

  return { resource, dashboard, lookups, loadLookups }
}
