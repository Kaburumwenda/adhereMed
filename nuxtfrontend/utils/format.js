// Common formatters used across detail/list pages
export function formatDate(v) {
  if (!v) return '—'
  try {
    const d = new Date(v)
    if (isNaN(d)) return v
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  } catch { return v }
}

export function formatDateTime(v) {
  if (!v) return '—'
  try {
    const d = new Date(v)
    if (isNaN(d)) return v
    return d.toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  } catch { return v }
}

export function formatMoney(v, currency = 'KES') {
  if (v == null || v === '') return '—'
  const n = Number(v)
  if (isNaN(n)) return v
  return `${currency} ${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export function formatRole(r) {
  if (!r) return ''
  return r.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
}
